;;; dev-merge.el --- merge conflicts: smerge + a menu, ediff that stays in one frame, and a git mergetool  -*- lexical-binding: t; -*-
;;
;; Open a file with conflict markers and smerge-mode switches itself on (it is not tied to VC state, so it also works for
;; files produced by `git stash pop', `git apply --3way', diff3, patch ...). The mode line shows the number of conflicts left.
;;
;;   C-c m m  conflict menu (also reachable as just C-c m)      n/p next / previous      RET keep the one at point
;;   u keep upper (ours)   l keep lower (theirs)   b keep base   a keep all   C combine with next
;;   e ediff this conflict   r refine (word-level diff)
;;   ]n / [n  next / previous conflict in evil normal state
;;
;; From magit: `e' on a conflicted file in the status buffer (magit-ediff-resolve-all). From git:
;;   git config --global merge.tool emacs
;;   git config --global mergetool.emacs.cmd '~/.config/emacs/bin/git-mergetool "$LOCAL" "$REMOTE" "$BASE" "$MERGED"'
;;   git config --global mergetool.emacs.trustExitCode true
;; then `git mergetool` opens a 3-way ediff in this config; it exits non-zero if conflict markers remain, so git keeps the file unmerged.

(require 'subr-x)
(require 'cl-lib)
(setq smerge-command-prefix (kbd "C-c m")      ; must be set before smerge-mode loads: C-c ^ is awkward with evil
      smerge-refine-ignore-whitespace t)

(defconst my/conflict-start-regexp "^<<<<<<< ")

(defun my/conflict-count ()
  "Number of unresolved conflicts in the buffer (cached per buffer modification)."
  (let ((tick (buffer-chars-modified-tick)))
    (unless (eq (car-safe (bound-and-true-p my/--conflict-cache)) tick)
      ;; save-match-data: this runs from after-change-functions in the middle of smerge's own edits, which still need their
      ;; match data afterwards
      (setq-local my/--conflict-cache
                  (cons tick (save-match-data
                               (save-excursion
                                 (save-restriction
                                   (widen)
                                   (goto-char (point-min))
                                   (let ((n 0))
                                     (while (re-search-forward my/conflict-start-regexp nil t) (cl-incf n))
                                     n)))))))
    (cdr my/--conflict-cache)))

(defun my/smerge-maybe ()
  "Turn smerge-mode on in a file buffer that contains conflict markers."
  (when (and buffer-file-name (not (bound-and-true-p smerge-mode)) (> (buffer-size) 0))
    (save-excursion
      (save-restriction
        (widen)
        (goto-char (point-min))
        (when (re-search-forward my/conflict-start-regexp nil t)
          (smerge-mode 1)
          (message "%d merge conflict(s) - C-c m for the menu" (my/conflict-count)))))))
(add-hook 'find-file-hook #'my/smerge-maybe)
(add-hook 'after-revert-hook #'my/smerge-maybe)

(with-eval-after-load 'smerge-mode
  ;; the lighter shows what is left to do
  (setf (alist-get 'smerge-mode minor-mode-alist)
        '((:eval (format " ⚔%d" (my/conflict-count)))))
  ;; when the last conflict is resolved, say so
  (add-hook 'smerge-mode-hook
            (lambda ()
              (add-hook 'after-change-functions
                        (lambda (&rest _)
                          (when (and (bound-and-true-p smerge-mode) (zerop (my/conflict-count)))
                            (smerge-mode -1)
                            (message "all conflicts resolved - save, then `git add`")))
                        nil t))))

(require 'transient)
(transient-define-prefix my/merge-menu ()
  "Resolve merge conflicts."
  [:description (lambda () (format "Merge conflicts: %d left" (my/conflict-count)))
   ["Go to"
    ("n" "next"     smerge-next :transient t)
    ("p" "previous" smerge-prev :transient t)]
   ["Keep"
    ("u"   "upper (ours)"   smerge-keep-upper   :transient t)
    ("l"   "lower (theirs)" smerge-keep-lower   :transient t)
    ("b"   "base"           smerge-keep-base    :transient t)
    ("a"   "all"            smerge-keep-all     :transient t)
    ("RET" "the one at point" smerge-keep-current :transient t)]
   ["Work on it"
    ("C" "combine with next" smerge-combine-with-next :transient t)
    ("r" "refine (words)"    smerge-refine)
    ("e" "ediff this one"    smerge-ediff)
    ("q" "close menu"        transient-quit-one)]])

(with-eval-after-load 'smerge-mode
  (define-key smerge-mode-map (kbd "C-c m m") #'my/merge-menu)
  (define-key smerge-mode-map (kbd "C-c m") #'my/merge-menu))

(with-eval-after-load 'evil
  (with-eval-after-load 'smerge-mode
    (evil-define-key 'normal smerge-mode-map
      (kbd "]n") #'smerge-next
      (kbd "[n") #'smerge-prev)))

;;; ediff - everything in the current frame, side by side, and put the windows back afterwards
(use-package ediff
  :ensure nil
  :init
  (setq ediff-window-setup-function #'ediff-setup-windows-plain   ; no separate control frame
        ediff-split-window-function #'split-window-horizontally
        ediff-merge-split-window-function #'split-window-horizontally
        ediff-diff-options "-w"
        ediff-keep-variants nil)
  (defvar my/--ediff-windows nil)
  (add-hook 'ediff-before-setup-hook (lambda () (setq my/--ediff-windows (current-window-configuration))))
  (dolist (hook '(ediff-quit-hook ediff-suspend-hook))
    (add-hook hook (lambda () (when my/--ediff-windows (set-window-configuration my/--ediff-windows))) 'append)))

;;; git mergetool backend (see bin/git-mergetool): 3-way ediff with this configuration
(defun my/merge-file-resolved-p (file)
  "FILE exists, is non-empty and has no conflict markers left."
  (and (file-exists-p file)
       (> (file-attribute-size (file-attributes file)) 0)
       (with-temp-buffer
         (insert-file-contents file)
         (goto-char (point-min))
         (not (re-search-forward "^\\(<<<<<<< \\|>>>>>>> \\|=======$\\)" nil t)))))

(defun my/git-mergetool ()
  "Entry point for bin/git-mergetool: reads MERGE_LOCAL/MERGE_REMOTE/MERGE_BASE/MERGE_MERGED from the environment."
  (let ((local (getenv "MERGE_LOCAL")) (remote (getenv "MERGE_REMOTE"))
        (base (getenv "MERGE_BASE"))   (merged (getenv "MERGE_MERGED")))
    (setq ediff-autostore-merges t)                       ; save the result to MERGED on quit, no prompt
    (add-hook 'ediff-quit-hook
              (lambda ()
                (kill-emacs (if (my/merge-file-resolved-p merged) 0 1)))
              100)                                        ; after ediff has stored the merge
    (if (and base (file-exists-p base))
        (ediff-merge-files-with-ancestor local remote base nil merged)
      (ediff-merge-files local remote nil merged))))

(provide 'dev-merge)
;;; dev-merge.el ends here
