;;; claude-api.el --- buffer-based file API for Claude, called into THIS (shared) Emacs  -*- lexical-binding: t; -*-
;;
;; Everything works on Emacs BUFFERS visiting the files, not on bytes read around the editor: what Claude reads is what Emacs
;; would show (unsaved changes included - possibly the user's own, since `cemacs` now talks to the same daemon he runs),
;; edits go through buffer operations and are saved with the normal save path.
;; Called through `cemacs` (bin script) which hands results back through a file, so output is raw text, not a Lisp string.
;;
;; Conventions: lines are 1-based. Every function returns a string (or signals an error that `claude/call' turns into
;; "ERROR: ..." text). Mutating functions save by default (pass SAVE nil to keep the change in the buffer only).

(require 'cl-lib)
(require 'subr-x)
(require 'imenu)

(defvar claude/read-lines 2000 "Default number of lines `claude/read' returns.")
(defvar claude/max-line-chars 2000 "Longer lines are truncated in `claude/read' output.")
(defvar claude/grep-limit 200 "Default cap on matching lines `claude/grep' returns.")

;;; plumbing

(defun claude/call (outfile form)
  "Evaluate FORM, write its result (or the error) to OUTFILE as UTF-8 text. Always returns t."
  (let ((res (condition-case err
                 (let ((v (eval form t)))
                   (if (stringp v) v (prin1-to-string v)))
               (error (format "ERROR: %s" (error-message-string err))))))
    (let ((coding-system-for-write 'utf-8-unix))
      (with-temp-file outfile (insert res))))
  t)

(defun claude--slurp (file)
  (with-temp-buffer
    (let ((coding-system-for-read 'utf-8-unix))
      (insert-file-contents file))
    (buffer-string)))

(defun claude--looks-binary-p (path)
  (with-temp-buffer
    (set-buffer-multibyte nil)
    (insert-file-contents-literally path nil 0 8192)
    (goto-char (point-min))
    (search-forward "\0" nil t)))

(defun claude--buffer (file &optional create)
  "The buffer visiting FILE, in sync with the disk. With CREATE a missing file gets a new (empty) buffer."
  (let ((path (expand-file-name file)))
    (cond
     ((file-directory-p path) (user-error "%s is a directory" path))
     ((and (file-exists-p path) (claude--looks-binary-p path)) (user-error "%s looks like a binary file" path))
     ((and (not create) (not (file-exists-p path)) (not (get-file-buffer path))) (user-error "no such file: %s" path)))
    (let ((buf (find-file-noselect path t)))
      (with-current-buffer buf
        ;; the file changed on disk behind our back: take the new content unless we hold unsaved edits of our own
        (when (and buffer-file-name (file-exists-p buffer-file-name) (not (verify-visited-file-modtime buf)))
          (if (buffer-modified-p)
              (user-error "%s changed on disk and the buffer has unsaved changes - `revert' or `save' first" path)
            (revert-buffer t t t))))
      buf)))

(defun claude--save (buf)
  (with-current-buffer buf
    (when (buffer-modified-p)
      (make-directory (file-name-directory buffer-file-name) t)
      (save-buffer))))

(defun claude--line-at (pos) (save-excursion (goto-char pos) (line-number-at-pos nil t)))

;;; reading

(defun claude/read (file &optional from to)
  "Lines FROM..TO of FILE (1-based, inclusive) with line numbers, from the buffer."
  (with-current-buffer (claude--buffer file)
    (save-restriction
      (widen)
      (let* ((total (count-lines (point-min) (point-max)))
             (from (max 1 (or from 1)))
             (to (min total (or to (+ from claude/read-lines -1))))
             out)
        (save-excursion
          (goto-char (point-min))
          (forward-line (1- from))
          (cl-loop for n from from to to
                   do (let ((l (buffer-substring-no-properties (line-beginning-position) (line-end-position))))
                        (push (format "%6d\t%s" n (if (> (length l) claude/max-line-chars)
                                                      (concat (substring l 0 claude/max-line-chars) " …[line truncated]")
                                                    l))
                              out))
                   (forward-line 1)))
        (concat (format "# %s  lines %d-%d of %d  mode=%s%s\n"
                        (abbreviate-file-name buffer-file-name) from (max from to) total major-mode
                        (if (buffer-modified-p) "  [UNSAVED CHANGES IN BUFFER]" ""))
                (mapconcat #'identity (nreverse out) "\n")
                (if out "\n" ""))))))

(defun claude/outline (file)
  "Functions/sections of FILE as `line  name' (imenu, no language server): the shape of a file without reading all of it."
  (with-current-buffer (claude--buffer file)
    (let (rows)
      (cl-labels ((walk (alist prefix)
                    (dolist (e alist)
                      (cond ((and (consp e) (listp (cdr e)) (consp (cadr e)) (not (markerp (cdr e))))
                             (walk (cdr e) (concat prefix (car e) "/")))
                            ((and (consp e) (or (markerp (cdr e)) (integerp (cdr e))))
                             (unless (string-prefix-p "*Rescan*" (car e))
                              (push (cons (claude--line-at (cdr e)) (concat prefix (car e))) rows)))))))
        (walk (condition-case nil (imenu--make-index-alist t) (error nil)) ""))
      (concat (format "# %s  %d lines  mode=%s\n" (abbreviate-file-name buffer-file-name)
                      (count-lines (point-min) (point-max)) major-mode)
              (if rows
                  (mapconcat (lambda (r) (format "%6d  %s" (car r) (cdr r)))
                             (sort rows (lambda (a b) (< (car a) (car b)))) "\n")
                "(no outline for this mode)")
              "\n"))))

;;; searching

(defun claude--grep-buffer (buf regexp ctx limit)
  (with-current-buffer buf
    (save-excursion
      (save-restriction
        (widen)
        (goto-char (point-min))
        (let (rows (n 0) (case-fold-search nil))
          (while (and (re-search-forward regexp nil t) (< n limit))
            (let ((ln (line-number-at-pos nil t)))
              (cl-incf n)
              (push (format "%s:%d:%s" (abbreviate-file-name buffer-file-name) ln
                            (buffer-substring-no-properties (line-beginning-position) (line-end-position)))
                    rows)
              (end-of-line)))
          (ignore ctx)
          (nreverse rows))))))

(defun claude/grep (regexp &optional path glob limit ctx ignore-case)
  "Search REGEXP (ripgrep/PCRE-ish syntax) under PATH (dir or file; default: here). GLOB filters files, e.g. \"*.el\".
A single file is searched in its BUFFER, so unsaved changes are included."
  (let* ((path (expand-file-name (or path default-directory)))
         (limit (or limit claude/grep-limit)))
    (if (and (file-regular-p path) (not (claude--looks-binary-p path)))
        (let ((rows (claude--grep-buffer (claude--buffer path) regexp ctx limit)))
          (if rows (concat (mapconcat #'identity rows "\n") "\n") "(no matches)\n"))
      (let ((args (append (list "--no-heading" "--line-number" "--color" "never" "--max-columns" "300"
                                "--max-columns-preview")
                          (when ignore-case '("-i"))
                          (when (and ctx (> ctx 0)) (list "-C" (number-to-string ctx)))
                          (when glob (list "-g" glob))
                          (list "-e" regexp "--" path))))
        (with-temp-buffer
          (let ((code (apply #'call-process "rg" nil t nil args)))
            (cond ((= code 1) "(no matches)\n")
                  ((> code 1) (format "ERROR: rg exited %d: %s" code (string-trim (buffer-string))))
                  (t (let* ((lines (split-string (buffer-string) "\n" t))
                            (n (length lines))
                            (shown (seq-take lines limit)))
                       (concat (mapconcat (lambda (l) (replace-regexp-in-string (concat "\\`" (regexp-quote (abbreviate-file-name path)))
                                                                                (abbreviate-file-name path) l))
                                          shown "\n")
                               "\n"
                               (when (> n limit) (format "[%d more lines not shown; narrow the search]\n" (- n limit)))))))))))))

;;; editing

(defun claude/replace (file old new &optional all save)
  "Replace OLD with NEW in FILE's buffer. Without ALL, OLD must occur exactly once. SAVE defaults to t."
  (when (or (null old) (string= old "")) (user-error "old text is empty"))
  (let ((buf (claude--buffer file)) (case-fold-search nil) positions)
    (with-current-buffer buf
      (save-excursion
        (save-restriction
          (widen)
          (goto-char (point-min))
          (while (search-forward old nil t) (push (match-beginning 0) positions))
          (setq positions (nreverse positions))
          (cond
           ((null positions) (user-error "old text not found in %s" file))
           ((and (cdr positions) (not all))
            (user-error "old text is not unique: %d occurrences (lines %s) - add surrounding context, or replace all"
                        (length positions)
                        (mapconcat (lambda (p) (number-to-string (claude--line-at p))) (seq-take positions 8) ",")))
           (t (let ((first-line (claude--line-at (car positions))))
                (dolist (p (reverse positions))
                  (goto-char p)
                  (delete-region p (+ p (length old)))
                  (insert new))
                (undo-boundary)
                (when (or save (null save)) (claude--save buf))
                (format "replaced %d occurrence(s) in %s (first at line %d)%s"
                        (length positions) (abbreviate-file-name (expand-file-name file)) first-line
                        (if (with-current-buffer buf (buffer-modified-p)) " [buffer not saved]" ""))))))))))

(defun claude/replace-files (file oldfile newfile &optional all)
  (claude/replace file (claude--trim-nl (claude--slurp oldfile)) (claude--trim-nl (claude--slurp newfile)) all t))

(defun claude--trim-nl (s)
  "Drop exactly one trailing newline (the one a heredoc adds)."
  (if (string-suffix-p "\n" s) (substring s 0 -1) s))

(defun claude/write (file contentfile)
  "Make FILE contain exactly the text in CONTENTFILE (created with its directories if new); saved."
  (let* ((path (expand-file-name file))
         (new (not (file-exists-p path)))
         (buf (claude--buffer path t))
         (text (claude--slurp contentfile)))
    (with-current-buffer buf
      (when new (set-buffer-file-coding-system 'utf-8-unix))
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert text))
      (undo-boundary)
      (claude--save buf))
    (format "wrote %s (%d lines)%s" (abbreviate-file-name path) (with-current-buffer buf (count-lines (point-min) (point-max)))
            (if new " [new file]" ""))))

(defun claude/insert (file line contentfile)
  "Insert the text of CONTENTFILE before LINE of FILE (LINE beyond the end appends). Saved."
  (let ((buf (claude--buffer file)) (text (claude--slurp contentfile)))
    (with-current-buffer buf
      (save-excursion
        (save-restriction
          (widen)
          (goto-char (point-min))
          (if (> line (count-lines (point-min) (point-max)))
              (progn (goto-char (point-max))
                     (unless (or (bobp) (bolp)) (insert "\n")))
            (forward-line (1- (max 1 line))))
          (insert (if (or (string= text "") (string-suffix-p "\n" text)) text (concat text "\n")))
          (undo-boundary)))
      (claude--save buf)
      (format "inserted at line %d of %s" line (abbreviate-file-name buffer-file-name)))))

(defun claude/delete-lines (file from to)
  "Delete lines FROM..TO (inclusive) of FILE. Returns what was removed. Saved."
  (let ((buf (claude--buffer file)))
    (with-current-buffer buf
      (save-excursion
        (save-restriction
          (widen)
          (let* ((total (count-lines (point-min) (point-max))))
            (when (or (< from 1) (> from total) (< to from)) (user-error "bad range %d-%d (file has %d lines)" from to total))
            (goto-char (point-min))
            (forward-line (1- from))
            (let* ((beg (point)) (end (progn (forward-line (1+ (- (min to total) from))) (point)))
                   (gone (buffer-substring-no-properties beg end)))
              (delete-region beg end)
              (undo-boundary)
              (claude--save buf)
              (format "deleted lines %d-%d of %s:\n%s" from (min to total) (abbreviate-file-name buffer-file-name) gone))))))))

;;; buffer / file state

(defun claude/save (file) (claude--save (claude--buffer file)) (format "saved %s" (abbreviate-file-name (expand-file-name file))))

(defun claude/save-all ()
  (let (n)
    (dolist (b (buffer-list))
      (with-current-buffer b
        (when (and buffer-file-name (buffer-modified-p)) (save-buffer) (push buffer-file-name n))))
    (format "saved %d buffer(s)%s" (length n) (if n (concat ": " (mapconcat #'abbreviate-file-name n ", ")) ""))))

(defun claude/revert (file)
  "Discard unsaved changes of FILE's buffer and re-read it from disk."
  (with-current-buffer (find-file-noselect (expand-file-name file) t)
    (revert-buffer t t t)
    (format "reverted %s" (abbreviate-file-name buffer-file-name))))

(defun claude/close (file &optional force)
  (let ((b (get-file-buffer (expand-file-name file))))
    (cond ((null b) "not open")
          ((and (buffer-modified-p b) (not force)) (user-error "buffer has unsaved changes (save, revert, or force)"))
          (t (kill-buffer b) "closed"))))

(defun claude/buffers ()
  (let (rows)
    (dolist (b (buffer-list))
      (with-current-buffer b
        (when buffer-file-name
          (push (format "%s %-10s %7d  %s" (if (buffer-modified-p) "*" " ") (symbol-name major-mode) (buffer-size)
                        (abbreviate-file-name buffer-file-name))
                rows))))
    (if rows (concat (mapconcat #'identity (nreverse rows) "\n") "\n") "(no file buffers open)\n")))

(defun claude/diff (file)
  "Unified diff of FILE's buffer against what is on disk (what a save would change)."
  (let* ((buf (claude--buffer file))
         (tmp (make-temp-file "claude-diff-")))
    (unwind-protect
        (progn
          (with-current-buffer buf
            (let ((coding-system-for-write 'utf-8-unix))
              (write-region (point-min) (point-max) tmp nil 'silent)))
          (with-temp-buffer
            (let ((code (call-process "diff" nil t nil "-u" "--label" "disk" "--label" "buffer"
                                      (expand-file-name file) tmp)))
              (if (= code 0) "(buffer equals disk)\n" (buffer-string)))))
      (when (file-exists-p tmp) (delete-file tmp)))))

(defun claude/format (file)
  "Re-indent FILE's buffer with its major mode's rules (no external formatter). Saved."
  (let ((buf (claude--buffer file)))
    (with-current-buffer buf
      (indent-region (point-min) (point-max))
      (undo-boundary)
      (claude--save buf)
      (format "re-indented %s with %s" (abbreviate-file-name buffer-file-name) major-mode))))

(defun claude/eval-file (infile)
  "Evaluate every form in INFILE; the value of the last one is the result."
  (with-temp-buffer
    (let ((coding-system-for-read 'utf-8-unix)) (insert-file-contents infile))
    (goto-char (point-min))
    (let (val)
      (condition-case nil
          (while t (setq val (eval (read (current-buffer)) t)))
        (end-of-file nil))
      val)))

(provide 'claude-api)
;;; claude-api.el ends here
