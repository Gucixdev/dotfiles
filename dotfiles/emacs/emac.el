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

;; no syntax highlighting - distracting, plain text everywhere
(global-font-lock-mode 0)

;;; Appearance - black background + tsoding's own theme/font

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
  (evil-mode 1))

(use-package evil-collection
  :after evil
  :config
  (evil-collection-init))         ; evil bindings for magit, dired, etc.

;;; Org mode

(use-package org
  :ensure nil                     ; built into Emacs, just configuring it
  :config
  (setq org-startup-indented t
        org-hide-emphasis-markers t
        org-ellipsis " ▾"))

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
