;; -*- lexical-binding: t; -*-
;;
;; Minimal config: evil, org, magit. No toolbar/menu/scrollbar - see
;; early-init.el, which strips those before this file even loads.
;;
;; Sectioned ;;; headers like tsoding's own .emacs (github.com/rexim/dotfiles)
;; - each section is independent, read top to bottom or jump around.

;;; Package management

(require 'package)
(setq package-archives
      '(("melpa" . "https://melpa.org/packages/")
        ("gnu"   . "https://elpa.gnu.org/packages/")))
(package-initialize)
(unless package-archive-contents
  (package-refresh-contents))

(unless (package-installed-p 'use-package)
  (package-install 'use-package))
(require 'use-package)
(setq use-package-always-ensure t)

;;; Sane defaults

(setq-default indent-tabs-mode nil
               tab-width 4)

(setq backup-directory-alist `(("." . ,(expand-file-name "backups" user-emacs-directory)))
      custom-file (expand-file-name "custom.el" user-emacs-directory)
      ring-bell-function 'ignore
      scroll-conservatively 101)

(when (file-exists-p custom-file)
  (load custom-file))

(global-display-line-numbers-mode 1)
(column-number-mode 1)
(show-paren-mode 1)
(electric-pair-mode 1)

;; auto-reload a buffer when the file behind it changes on disk (e.g. an
;; external tool edits it) instead of showing stale content or prompting
(setq auto-revert-verbose nil)      ; don't spam the minibuffer every reload
(global-auto-revert-mode 1)

;; real system clipboard for evil's own yank/paste (so "+y / "+p and
;; plain y/p in visual state all reach wl-copy/wl-paste, not just an
;; Emacs-internal kill-ring)
(setq select-enable-clipboard t)

;; no syntax highlighting - distracting, plain text everywhere
(global-font-lock-mode 0)

;;; Appearance - black background + tsoding's own theme/font

;; Third-party packages from MELPA (gruber-darker among them) often lack a lexical-binding cookie; Emacs 31 warns about it on
;; every load and pops *Warnings* up as a second window at startup. Silence exactly that warning type (not file warnings in
;; general): its type is (files missing-lexbind-cookie FILE), matched by prefix.
(require 'warnings)
(add-to-list 'warning-suppress-types '(files missing-lexbind-cookie))
(add-to-list 'warning-suppress-log-types '(files missing-lexbind-cookie))

(use-package gruber-darker-theme
  :config
  (load-theme 'gruber-darker t))

;; Fixed6x13 - the same bitmap font already used in foot.ini, so the
;; terminal and the editor look the same.
(add-to-list 'default-frame-alist '(font . "Fixed-13"))

;;; Completion - company (tsoding has this, we didn't)

(use-package company
  :config
  (global-company-mode 1))

;;; Multiple cursors - frost has this natively, Emacs needs the package

(use-package multiple-cursors
  :bind (("C-S-c C-S-c" . mc/edit-lines)
         ("C->"         . mc/mark-next-like-this)
         ("C-<"         . mc/mark-previous-like-this)
         ("C-c C-<"     . mc/mark-all-like-this)))

;;; Move text - M-up/M-down to move the current line/region

(use-package move-text
  :bind (("M-p" . move-text-up)
         ("M-n" . move-text-down)))

;;; Trailing whitespace - auto-trim on save in programming buffers

(add-hook 'prog-mode-hook
          (lambda ()
            (add-hook 'write-file-functions 'delete-trailing-whitespace nil t)))

;;; Evil - vim keybindings

(use-package evil
  :init
  (setq evil-want-integration t
        evil-want-keybinding nil   ; let evil-collection supply these instead
        evil-want-C-u-scroll t
        evil-undo-system 'undo-redo)
  :config
  (evil-mode 1)
  ;; classic C-c/C-v, to the real system clipboard. Bound directly in
  ;; evil's own keymaps (not cua-mode - evil's keymaps win precedence
  ;; over cua's region-conditional bindings, so cua's C-c/C-v silently
  ;; never fire while evil-mode is on; confirmed by testing, not a guess).
  (define-key evil-visual-state-map (kbd "C-c") #'evil-yank)
  (define-key evil-insert-state-map (kbd "C-v") #'evil-paste-after)
  (define-key evil-normal-state-map (kbd "C-v") #'evil-paste-after))

(use-package evil-collection
  :after evil
  :config
  (evil-collection-init))         ; evil bindings for magit, dired, etc.

;;; GDB - built in, no LSP involved. M-x gdb, give it a command like
;;; "gdb --args ./myprog arg1", gdb-many-windows gives the multi-pane
;;; locals/breakpoints/stack layout.
(setq gdb-many-windows t
      gdb-show-main t)

;;; Compile - C-c r runs/builds whatever `compile-command` is for this
;;; project (set per-project via .dir-locals.el, e.g. "godot --path .")
;;; so Godot output lands in an Emacs buffer instead of needing the editor.
(global-set-key (kbd "C-c r") #'compile)

;;; Org mode

(use-package org
  :ensure nil                     ; built into Emacs, just configuring it
  :bind ("C-c a" . org-agenda)
  :config
  (setq org-startup-indented t
        org-hide-emphasis-markers t
        org-ellipsis " ▾"
        org-todo-keywords '((sequence "TODO" "IN-PROGRESS" "|" "DONE" "CANCELLED"))
        org-log-done 'time))        ; stamps when a task flips to DONE

;;; Magit - git porcelain

(use-package magit
  :commands (magit-status magit-dispatch)
  :bind ("C-c g" . magit-status))

;;; Diff-hl - live +/-/~ markers in the margin for uncommitted git changes

(use-package diff-hl
  :config
  (global-diff-hl-mode 1))

;;; Which-key - shows available keys after a prefix, instead of a cheat sheet

(use-package which-key
  :config
  (which-key-mode 1))

;;; Dev modules - ~/.config/emacs/lisp/*.el, each independent: delete its name from the list to drop it.
;;; A module that fails to load is reported in *Messages* and skipped; it can't take startup down with it.

(add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))
(dolist (module '(dev-server dev-nav dev-shell dev-lang dev-debug dev-godot dev-merge dev-templates claude-api))
  (condition-case err
      (require module)
    (error (message "dev module %s failed to load: %S" module err))))
