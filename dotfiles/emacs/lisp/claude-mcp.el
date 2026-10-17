;;; claude-mcp.el --- MCP server face of claude-api.el: Claude Code gets this Emacs's buffers as tools  -*- lexical-binding: t; -*-
;;
;; bin/emacs-mcp is the stdio transport Claude Code starts; for each JSON-RPC line it calls `claude-mcp/handle' in this
;; daemon through emacsclient, and the answer goes back the same way. All JSON is done here, nothing outside Emacs parses it.
;; The tools are claude-api.el's functions (same daemon, same buffers, unsaved edits visible) plus `show', which opens a file
;; in the frame you are looking at.
;;
;; Register once:  claude mcp add -s user emacs -- ~/.config/emacs/bin/emacs-mcp
;; Tools then show up as mcp__emacs__read, mcp__emacs__replace, ...

(require 'claude-api)
(require 'json)
(require 'seq)
(require 'subr-x)

(defconst claude-mcp--path-doc "file path; relative to Claude's working directory")

(defconst claude-mcp--tools
  `(("read" "Numbered lines of a file, read from its Emacs buffer (unsaved edits included). 2000 lines unless FROM/TO say."
     ((file "string" t ,claude-mcp--path-doc) (from "integer" nil "first line, 1-based") (to "integer" nil "last line"))
     claude/read)
    ("outline" "Functions and sections of a file with their line numbers (imenu): its shape before reading all of it."
     ((file "string" t ,claude-mcp--path-doc))
     claude/outline)
    ("grep" "Search with ripgrep regex syntax under a directory or in one file (a file is searched in its buffer)."
     ((regexp "string" t "ripgrep regex") (path "string" nil "directory or file, default: working directory")
      (glob "string" nil "file filter, e.g. *.el") (limit "integer" nil "max matching lines, default 200")
      (context "integer" nil "lines of context") (ignore_case "boolean" nil "case-insensitive"))
     claude/grep)
    ("replace" "Replace OLD with NEW in a file's buffer and save. OLD must occur exactly once unless ALL is true."
     ((file "string" t ,claude-mcp--path-doc) (old "string" t "exact text to replace")
      (new "string" t "replacement text") (all "boolean" nil "replace every occurrence"))
     claude-mcp--replace)
    ("write" "Make a file contain exactly CONTENT (creates it and its directories); saved through Emacs."
     ((file "string" t ,claude-mcp--path-doc) (content "string" t "the whole new file"))
     claude-mcp--write)
    ("insert" "Insert CONTENT before line LINE of a file (past the end appends); saved."
     ((file "string" t ,claude-mcp--path-doc) (line "integer" t "1-based line to insert before")
      (content "string" t "text to insert"))
     claude-mcp--insert)
    ("delete_lines" "Delete lines FROM..TO (inclusive) of a file; returns what was removed; saved."
     ((file "string" t ,claude-mcp--path-doc) (from "integer" t "first line") (to "integer" t "last line"))
     claude/delete-lines)
    ("diff" "Unified diff of a file's buffer against the file on disk: what saving would change."
     ((file "string" t ,claude-mcp--path-doc))
     claude/diff)
    ("buffers" "Open file buffers: modified flag, major mode, size, path." () claude/buffers)
    ("save" "Save a file's buffer." ((file "string" t ,claude-mcp--path-doc)) claude/save)
    ("save_all" "Save every modified file buffer - including ones the user is still editing." () claude/save-all)
    ("revert" "Throw away a buffer's unsaved changes and re-read the file." ((file "string" t ,claude-mcp--path-doc))
     claude/revert)
    ("close" "Kill a file's buffer (refuses unsaved changes unless FORCE)."
     ((file "string" t ,claude-mcp--path-doc) (force "boolean" nil "kill even with unsaved changes"))
     claude/close)
    ("format" "Re-indent a file with its major mode's own rules; saved." ((file "string" t ,claude-mcp--path-doc))
     claude/format)
    ("show" "Open a file in the user's Emacs window, at LINE, and bring the window up: to point him at something."
     ((file "string" t ,claude-mcp--path-doc) (line "integer" nil "line to put the cursor on"))
     claude-mcp--show)
    ("eval" "Evaluate Emacs Lisp in the user's running Emacs; the last form's value comes back. For multi-step edits."
     ((code "string" t "one or more Lisp forms"))
     claude-mcp--eval))
  "Each tool: (NAME DESCRIPTION PARAMS FUNCTION). PARAMS: (ARG JSON-TYPE REQUIRED DOC); FUNCTION gets them in that order.")

;;; tool bodies that need more than a direct call

(defun claude-mcp--with-content-file (content fn)
  (let ((tmp (make-temp-file "claude-mcp-")))
    (unwind-protect
        (progn (let ((coding-system-for-write 'utf-8-unix)) (with-temp-file tmp (insert content)))
               (funcall fn tmp))
      (delete-file tmp))))

(defun claude-mcp--replace (file old new &optional all) (claude/replace file old new all t))
(defun claude-mcp--write (file content) (claude-mcp--with-content-file content (lambda (f) (claude/write file f))))
(defun claude-mcp--insert (file line content)
  (claude-mcp--with-content-file content (lambda (f) (claude/insert file line f))))

(defun claude-mcp--eval (code)
  (with-temp-buffer
    (insert code)
    (goto-char (point-min))
    (let (val)
      (condition-case nil
          (while t (setq val (eval (read (current-buffer)) t)))
        (end-of-file nil))
      (if (stringp val) val (prin1-to-string val)))))

(defun claude-mcp--show (file &optional line)
  (let ((path (expand-file-name file))
        (frame (and (fboundp 'my/server--gui-frame) (my/server--gui-frame))))
    (unless frame (user-error "no Emacs window is open to show it in"))
    (with-selected-frame frame
      (find-file path)
      (when line (goto-char (point-min)) (forward-line (1- line)))
      (select-frame-set-input-focus frame)
      (when (fboundp 'my/server-focus-frame) (my/server-focus-frame)))
    (format "showing %s%s" (abbreviate-file-name path) (if line (format ":%d" line) ""))))

;;; protocol

(defun claude-mcp--schema (params)
  (list :type "object"
        :properties (if params
                        (apply #'append (mapcar (lambda (p) (list (intern (format ":%s" (car p)))
                                                                  (list :type (nth 1 p) :description (nth 3 p))))
                                                params))
                      (make-hash-table))
        :required (vconcat (mapcar (lambda (p) (symbol-name (car p))) (seq-filter (lambda (p) (nth 2 p)) params)))))

(defun claude-mcp--tool-list ()
  (vconcat (mapcar (lambda (tool) (list :name (nth 0 tool) :description (nth 1 tool)
                                        :inputSchema (claude-mcp--schema (nth 2 tool))))
                   claude-mcp--tools)))

(defun claude-mcp--arg (param args)
  (let ((v (alist-get (car param) args)))
    (if (and (stringp v) (equal (nth 1 param) "integer")) (string-to-number v) v)))

(defun claude-mcp--call (name args)
  "Run tool NAME with the ARGS alist; a tool's own failure is a result with isError, as MCP wants."
  (let ((tool (or (assoc name claude-mcp--tools) (signal 'user-error (list (format "unknown tool %s" name))))))
    (condition-case err
        (let* ((v (apply (nth 3 tool) (mapcar (lambda (p) (claude-mcp--arg p args)) (nth 2 tool))))
               (text (if (stringp v) v (prin1-to-string v))))
          (list :content (vector (list :type "text" :text text)) :isError :false))
      (error (list :content (vector (list :type "text" :text (format "ERROR: %s" (error-message-string err))))
                   :isError t)))))

(defun claude-mcp--dispatch (method params)
  (pcase method
    ("initialize"
     (list :protocolVersion (or (alist-get 'protocolVersion params) "2025-06-18")
           :capabilities (list :tools (make-hash-table))
           :serverInfo (list :name "emacs" :version emacs-version)
           :instructions "Files as buffers of the user's own running Emacs: what you read includes his unsaved edits, and edits are real saves. Prefer outline + ranged read over whole files."))
    ("ping" (make-hash-table))
    ("tools/list" (list :tools (claude-mcp--tool-list)))
    ("tools/call" (claude-mcp--call (alist-get 'name params) (alist-get 'arguments params)))
    (_ (throw 'claude-mcp--no-method method))))

(defun claude-mcp/handle (infile outfile)
  "Answer the JSON-RPC message in INFILE into OUTFILE (left empty for a notification). Always returns t."
  (let* ((msg (json-parse-string (claude--slurp infile) :object-type 'alist :array-type 'list
                                 :null-object nil :false-object nil))
         (id (alist-get 'id msg))
         (reply (condition-case err
                    (let ((missing nil) result)
                      (setq missing (catch 'claude-mcp--no-method
                                      (setq result (claude-mcp--dispatch (alist-get 'method msg) (alist-get 'params msg)))
                                      nil))
                      (if missing
                          (list :error (list :code -32601 :message (format "method not found: %s" missing)))
                        (list :result result)))
                  (error (list :error (list :code -32603 :message (error-message-string err)))))))
    (when id                                      ; requests get an answer, notifications don't
      (let ((coding-system-for-write 'utf-8-unix))
        (with-temp-file outfile
          (json-insert (append (list :jsonrpc "2.0" :id id) reply))))))
  t)

(provide 'claude-mcp)
;;; claude-mcp.el ends here
