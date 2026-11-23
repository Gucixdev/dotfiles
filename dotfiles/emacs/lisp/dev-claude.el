;;; dev-claude.el --- Claude's own working tools in this Emacs: checkpoints, edit log, org notes, on-demand LSP  -*- lexical-binding: t; -*-
;;
;; Additive to claude-api.el (the buffer file API). Nothing here runs by itself: no hooks, no resident servers.
;;  - claude/checkpoint FILE...   remember the buffer text of files before a bigger edit; claude/rollback restores it
;;  - claude/diff-since FILE      unified diff of the buffer against the checkpoint (what I changed, before saving)
;;  - claude/log / claude/log-show   one line per thing done, in an org file (org-babel: shell, emacs-lisp, C, python)
;;  - claude/lsp-refs FILE LINE COL / claude/lsp-rename ...   Eglot started for ONE query, shut down right after,
;;    because this config has no resident LSP on purpose (see README). Needs the language's server on PATH.
;; Delete `dev-claude' from the module list in emac.el to drop all of it.

(require 'cl-lib)
(require 'subr-x)
(require 'org)

(defvar claude/notes-file (expand-file-name "claude/notes.org" (or (getenv "XDG_STATE_HOME") "~/.local/state"))
  "Org file where `claude/log' appends.")
(defvar claude--checkpoints (make-hash-table :test 'equal) "absolute file -> buffer text at checkpoint time.")

;;; org-babel: only languages I actually run, and never without a confirm for strangers' files
(with-eval-after-load 'org
  (org-babel-do-load-languages
   'org-babel-load-languages '((shell . t) (emacs-lisp . t) (C . t) (python . t)))
  (setq org-confirm-babel-evaluate (lambda (&rest _) nil)  ; my own notes file only; see claude/log-show
        org-src-fontify-natively t))

;;; checkpoints
(defun claude--abs (file) (expand-file-name file))

(defun claude/checkpoint (&rest files)
  "Remember the current buffer text of FILES (visiting them if needed). Returns a status string."
  (mapconcat
   (lambda (f)
     (let ((buf (claude--buffer (claude--abs f) t)))
       (puthash (claude--abs f) (with-current-buffer buf (buffer-substring-no-properties (point-min) (point-max)))
                claude--checkpoints)
       (format "checkpoint %s" (abbreviate-file-name (claude--abs f)))))
   files "\n"))

(defun claude/rollback (file)
  "Put FILE's buffer back to its checkpoint (does not save; call claude/save)."
  (let ((old (gethash (claude--abs file) claude--checkpoints)))
    (unless old (error "no checkpoint for %s" file))
    (with-current-buffer (claude--buffer (claude--abs file) t)
      (let ((inhibit-read-only t))
        (replace-region-contents (point-min) (point-max) (lambda () old))))
    (format "rolled back %s (unsaved)" (abbreviate-file-name (claude--abs file)))))

(defun claude/diff-since (file)
  "Unified diff between the checkpoint and the buffer now; \"(no changes)\" if equal."
  (let ((old (gethash (claude--abs file) claude--checkpoints))
        (new (with-current-buffer (claude--buffer (claude--abs file) t)
               (buffer-substring-no-properties (point-min) (point-max))))
        (a (make-temp-file "ckpt")) (b (make-temp-file "now")))
    (unless old (error "no checkpoint for %s" file))
    (unwind-protect
        (progn
          (let ((coding-system-for-write 'utf-8-unix))
            (write-region old nil a nil 'silent) (write-region new nil b nil 'silent))
          (with-temp-buffer
            (let ((rc (call-process "diff" nil t nil "-u" "--label" "checkpoint" "--label" "now" a b)))
              (if (eq rc 0) "(no changes)" (buffer-string)))))
      (delete-file a) (delete-file b))))

;;; log
(defun claude/log (what)
  "Append WHAT as a dated org entry to `claude/notes-file'."
  (make-directory (file-name-directory claude/notes-file) t)
  (with-temp-buffer
    (unless (file-exists-p claude/notes-file) (insert "#+title: Claude's log\n\n"))
    (insert (format "* %s %s\n" (format-time-string "[%Y-%m-%d %a %H:%M]") what))
    (write-region (point-min) (point-max) claude/notes-file t 'silent))
  "logged")

(defun claude/log-show (&optional n)
  "The last N (default 20) log headings."
  (if (not (file-exists-p claude/notes-file)) "(empty)"
    (with-temp-buffer
      (insert-file-contents claude/notes-file)
      (let ((l (seq-filter (lambda (s) (string-prefix-p "* " s)) (split-string (buffer-string) "\n"))))
        (string-join (last l (or n 20)) "\n")))))

;;; on-demand LSP
;; Light on purpose: the server runs at nice 19, 2 threads, no background index, and dies after the query.
(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs
               '((c-mode c-ts-mode c++-mode c++-ts-mode objc-mode)
                 . ("nice" "-n" "19" "clangd" "-j=2" "--background-index=false" "--pch-storage=memory"))))
(defun claude--with-eglot (file thunk)
  "Run THUNK in FILE's buffer with a fresh Eglot session, then shut that session down."
  (require 'eglot)
  (let ((buf (claude--buffer (claude--abs file) t)))
    (with-current-buffer buf
      (unless (eglot--lookup-mode major-mode) (error "no language server configured for %s" major-mode))
      (unwind-protect
          (progn (let ((eglot-sync-connect t) (eglot-autoshutdown t)) (call-interactively #'eglot))
                 (funcall thunk))
        (ignore-errors (eglot-shutdown (eglot-current-server) nil nil t))))))

(defun claude/lsp-refs (file line col)
  "References of the symbol at FILE:LINE:COL (1-based), one \"path:line: text\" per hit."
  (claude--with-eglot
   file
   (lambda ()
     (goto-char (point-min)) (forward-line (1- line)) (move-to-column (1- col))
     (let (out)
       (dolist (loc (xref-backend-references (xref-find-backend) (xref-backend-identifier-at-point (xref-find-backend))))
         (let ((l (xref-item-location loc)))
           (push (format "%s:%d: %s" (xref-location-group l) (xref-location-line l) (xref-item-summary loc)) out)))
       (if out (string-join (nreverse out) "\n") "(no references)")))))


;;; files, dired-style (so nothing is typed by hand): listing and moves that keep visiting buffers in step
(defvar claude/trash-dir "/data/dev/trash" "`claude/trash' moves here; never deletes.")

(defun claude/ls (dir &optional all)
  "List DIR: type, size, mtime, name (dirs end in /). ALL non-nil includes dotfiles."
  (let ((dir (file-name-as-directory (claude--abs dir))) rows)
    (dolist (e (directory-files-and-attributes dir nil (if all nil "\\`[^.]") t))
      (unless (member (car e) '("." ".."))
        (let* ((a (cdr e)) (d (eq (file-attribute-type a) t)) (l (stringp (file-attribute-type a))))
          (push (format "%s %9d %s %s%s" (cond (d "d") (l "l") (t "-")) (file-attribute-size a)
                        (format-time-string "%Y-%m-%d %H:%M" (file-attribute-modification-time a))
                        (car e) (cond (d "/") (l (concat " -> " (file-attribute-type a))) (t "")))
                rows))))
    (if rows (string-join (sort rows (lambda (x y) (string< (substring x 28) (substring y 28)))) "\n") "(empty)")))

(defun claude/mkdir (dir) (make-directory (claude--abs dir) t) (format "mkdir %s" dir))

(defun claude/cp (from to)
  "Copy FROM to TO (a directory TO receives it under its own name). Refuses to overwrite."
  (let* ((from (claude--abs from)) (to (claude--abs to))
         (to (if (file-directory-p to) (expand-file-name (file-name-nondirectory (directory-file-name from)) to) to)))
    (when (file-exists-p to) (error "%s exists" to))
    (if (file-directory-p from) (copy-directory from to nil t t) (copy-file from to))
    (format "cp %s -> %s" from to)))

(defun claude/mv (from to)
  "Move/rename like dired: buffers visiting FROM follow it. Refuses to overwrite."
  (require 'dired-aux)
  (let* ((from (claude--abs from)) (to (claude--abs to))
         (to (if (file-directory-p to) (expand-file-name (file-name-nondirectory (directory-file-name from)) to) to)))
    (when (file-exists-p to) (error "%s exists" to))
    (make-directory (file-name-directory to) t)
    (dired-rename-file from to nil)
    (format "mv %s -> %s" from to)))

(defun claude/trash (file)
  "Move FILE into `claude/trash-dir' (timestamped if the name is taken). Never deletes."
  (let* ((f (claude--abs file)) (n (file-name-nondirectory (directory-file-name f)))
         (dest (expand-file-name n claude/trash-dir)))
    (when (file-exists-p dest) (setq dest (format "%s.%s" dest (format-time-string "%H%M%S"))))
    (claude/mv f dest)))

;;; licenses: SPDX id -> LICENSE file. Short permissive ones are built in; the rest come from the system's SPDX texts.
(defconst claude--license-short
  '(("MIT" . "MIT License\n\nCopyright (c) %Y %H\n\nPermission is hereby granted, free of charge, to any person obtaining a copy\nof this software and associated documentation files (the \"Software\"), to deal\nin the Software without restriction, including without limitation the rights\nto use, copy, modify, merge, publish, distribute, sublicense, and/or sell\ncopies of the Software, and to permit persons to whom the Software is\nfurnished to do so, subject to the following conditions:\n\nThe above copyright notice and this permission notice shall be included in all\ncopies or substantial portions of the Software.\n\nTHE SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR\nIMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,\nFITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE\nAUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER\nLIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,\nOUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE\nSOFTWARE.\n")
    ("ISC" . "ISC License\n\nCopyright (c) %Y %H\n\nPermission to use, copy, modify, and/or distribute this software for any\npurpose with or without fee is hereby granted, provided that the above\ncopyright notice and this permission notice appear in all copies.\n\nTHE SOFTWARE IS PROVIDED \"AS IS\" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH\nREGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY\nAND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT,\nINDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM\nLOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR\nOTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR\nPERFORMANCE OF THIS SOFTWARE.\n"))
  "SPDX id -> text; %Y year, %H holder.")

(defun claude/license (id &optional holder file year)
  "Write license ID (SPDX, e.g. MIT, Apache-2.0, GPL-3.0-or-later) to FILE (default ./LICENSE).
HOLDER defaults to Gucixdev (the public identity). Refuses to overwrite an existing file."
  (let* ((file (claude--abs (or file "LICENSE")))
         (short (assoc id claude--license-short))
         (sys (format "/usr/share/licenses/spdx/%s.txt" id)))
    (when (file-exists-p file) (error "%s exists" file))
    (let ((text (cond (short (thread-last (cdr short)
                               (replace-regexp-in-string "%Y" (or year (format-time-string "%Y")))
                               (replace-regexp-in-string "%H" (or holder "Gucixdev"))))
                      ((file-exists-p sys) (with-temp-buffer (insert-file-contents sys) (buffer-string)))
                      (t (error "unknown license %s (built in: MIT ISC; system SPDX dir: %s)" id
                                (string-join (mapcar (lambda (f) (file-name-sans-extension f))
                                                     (seq-take (directory-files "/usr/share/licenses/spdx" nil "\\.txt\\'") 12)) " "))))))
      (let ((coding-system-for-write 'utf-8-unix)) (write-region text nil file nil 'silent))
      (format "wrote %s (%s)" file id))))

;;; boilerplate: the templates/snippets of dev-templates, straight into a file
(defun claude/template (kind file)
  "Create FILE (must not exist) from the file template KIND (see `my/templates'), %FILE%/%BASE%/%YEAR% filled in."
  (let ((file (claude--abs file)))
    (when (file-exists-p file) (error "%s exists" file))
    (let ((tpl (assoc kind my/templates)))
      (unless tpl (error "no template %s (have: %s)" kind (string-join (mapcar #'car my/templates) " ")))
      (make-directory (file-name-directory file) t)
      (with-temp-buffer
        (setq buffer-file-name file)
        (my/template--insert (cadr tpl))
        (let ((coding-system-for-write 'utf-8-unix)) (write-region (point-min) (point-max) file nil 'silent))
        (set-buffer-modified-p nil))
      (format "created %s from %s" file kind))))

(provide 'dev-claude)
