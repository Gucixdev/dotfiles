;;; dev-files.el --- files never vanish: every save keeps the previous version, deleting goes to the trash; dired  -*- lexical-binding: t; -*-
;;
;; Versions: before every save the file's previous content is copied into one store, shared with Claude's edit hook and
;; the `versions' command of claude-config (bin/versions), so `versions diff FILE', `versions restore FILE N' and
;; `versions rewind TIME' see every save made here. The store is ~/.local/share/versions (VERSIONS_STORE overrides); a
;; version is an Emacs numbered backup named after the file's true path (/home/u/x.c -> !home!u!x.c.~7~, "!" doubled
;; first), dated when that content was written. Nothing in the store is ever trimmed. Files under git are versioned too:
;; a commit is not every save.
;;
;; Trash: dired's D and the interactive delete commands move files to the freedesktop trash (~/.local/share/Trash) - the
;; same place the `trash' tool and file managers use, so they can be restored.
;;
;; Keys: C-c v l the versions of this file (dired), C-c v d diff with the newest, C-c v r restore one (the current content
;; becomes a version first, so a restore can be undone too).

(require 'dired)
(require 'dired-x)
(require 'subr-x)

;;; Versions

(defconst my/versions-dir
  (file-name-as-directory
   (let ((store (getenv "VERSIONS_STORE")) (data (getenv "XDG_DATA_HOME")))
     (if (and store (not (string-empty-p store)))
         store
       (expand-file-name "versions" (if (and data (not (string-empty-p data))) data "~/.local/share")))))
  "The versions store, shared with bin/versions and Claude's edit hook.")

(defvar my/versions-max-bytes (* 20 1024 1024)
  "Bigger files are not versioned; bin/versions has the same limit.")

(make-directory my/versions-dir t)
(set-file-modes my/versions-dir #o700)

(setq backup-directory-alist `(("." . ,my/versions-dir))
      make-backup-files t
      backup-by-copying t           ; the file keeps its inode and links; the copy keeps the file's time
      version-control t             ; numbered: .~1~, .~2~, ...
      delete-old-versions 'never    ; neither t nor nil: Emacs never trims old versions
      vc-make-backup-files t)       ; by default Emacs skips files under git

(defun my/versions-wanted-p (name)
  "Back NAME up, unless a temp file, in the store, or too big."
  (and (normal-backup-enable-predicate name)
       (not (string-prefix-p my/versions-dir (file-truename name)))
       (let ((size (file-attribute-size (file-attributes name))))
         (or (null size) (<= size my/versions-max-bytes)))))
(setq backup-enable-predicate #'my/versions-wanted-p)

;; Emacs names a backup after the path it was given, bin/versions after the true path (symlinked folders resolved, e.g.
;; ~/dev -> /data/dev); both must land on the same name
(defun my/versions--truename (args) (cons (file-truename (car args)) (cdr args)))
(advice-add 'find-backup-file-name :filter-args #'my/versions--truename)
(advice-add 'file-newest-backup :filter-args #'my/versions--truename)

;; Emacs backs a buffer up only on its first save after visiting; this makes it every save
(defun my/versions-every-save () (setq buffer-backed-up nil))
(add-hook 'before-save-hook #'my/versions-every-save)

(defun my/versions--of (file)
  "Stored versions of FILE as (N . PATH), oldest first."
  (let* ((base (file-name-nondirectory (make-backup-file-name-1 (file-truename file))))
         (re (concat "\\`" (regexp-quote base) "\\.~\\([0-9]+\\)~\\'"))
         versions)
    (dolist (name (directory-files my/versions-dir nil re t))
      (when (string-match re name)
        (push (cons (string-to-number (match-string 1 name)) (expand-file-name name my/versions-dir)) versions)))
    (sort versions (lambda (a b) (< (car a) (car b))))))

(defun my/versions--file ()
  (or buffer-file-name (user-error "This buffer is not visiting a file")))

(defun my/versions-list ()
  "Dired listing of the stored versions of this buffer's file."
  (interactive)
  (let ((versions (my/versions--of (my/versions--file))))
    (unless versions (user-error "No versions of %s yet" (abbreviate-file-name buffer-file-name)))
    (dired (cons my/versions-dir (mapcar #'cdr versions)))))

(defun my/versions-diff ()
  "Diff from the newest stored version to this buffer's file."
  (interactive)
  (let ((newest (car (last (my/versions--of (my/versions--file))))))
    (unless newest (user-error "No versions of %s yet" (abbreviate-file-name buffer-file-name)))
    (diff (cdr newest) buffer-file-name)))

(defun my/versions-restore (n)
  "Put version N of this file back and save.
The content it replaces becomes a version first."
  (interactive
   (let ((versions (or (my/versions--of (my/versions--file))
                       (user-error "No versions of %s yet" (abbreviate-file-name buffer-file-name)))))
     (list (string-to-number
            (completing-read
             "Restore version: "
             (mapcar (lambda (v)
                       (format "%d  %s" (car v)
                               (format-time-string "%F %T" (file-attribute-modification-time (file-attributes (cdr v))))))
                     (reverse versions))
             nil t)))))
  (let ((version (assq n (my/versions--of (my/versions--file)))))
    (unless version (user-error "No version %s" n))
    (when (buffer-modified-p) (save-buffer))           ; unsaved edits become a version too
    (insert-file-contents (cdr version) nil nil nil t) ; REPLACE: markers and undo survive
    (save-buffer)                                      ; the replaced content is stored on the way
    (message "Restored version %d of %s" n (abbreviate-file-name buffer-file-name))))

(defvar my/versions-map (make-sparse-keymap) "C-c v: the versions of this file.")
(global-set-key (kbd "C-c v") my/versions-map)
(define-key my/versions-map "l" #'my/versions-list)
(define-key my/versions-map "d" #'my/versions-diff)
(define-key my/versions-map "r" #'my/versions-restore)

;;; Trash

(setq delete-by-moving-to-trash t)   ; trash-directory stays nil: the freedesktop trash

;;; Dired - one buffer, details on ( , copy and move toward the other window, C-x C-q renames by editing the listing

(setq dired-listing-switches
      (if (string-match-p "GNU" (shell-command-to-string "ls --version 2>/dev/null"))
          "-alh --group-directories-first"
        "-alh")                         ; BSD ls has no --group-directories-first
      dired-dwim-target t
      dired-recursive-copies 'always
      dired-recursive-deletes 'top     ; one question per folder; it goes to the trash anyway
      dired-kill-when-opening-new-dired-buffer t)
(defvar wdired-allow-to-change-permissions)
(with-eval-after-load 'wdired (setq wdired-allow-to-change-permissions t))
(add-hook 'dired-mode-hook #'dired-hide-details-mode)

(provide 'dev-files)
;;; dev-files.el ends here
