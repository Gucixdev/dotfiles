;; -*- lexical-binding: t; -*-
;;
;; Minimal config: evil, org, magit, tab-line, compile-mode. No LSP. No toolbar/menu/scrollbar - early-init.el strips
;; those before this file even loads. Each ;;; section stands on its own; the dev modules in lisp/ come last.

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

;; settings of this machine that must not reach the repo (mail address, see lisp/dev-inbox.el); gitignored
(load (expand-file-name "local.el" user-emacs-directory) t)

;; data that is not config (feeds, mail) lives outside the repo this directory is linked into
(defconst my/data-dir (expand-file-name "emacs/" (or (getenv "XDG_DATA_HOME") "~/.local/share/")))

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

;;; Appearance - gruber-darker, and the bitmap font foot.ini uses, so editor and terminal look alike

;; Third-party packages from MELPA (gruber-darker among them) often lack a lexical-binding cookie; Emacs 31 warns about it on
;; every load and pops *Warnings* up as a second window at startup. Silence exactly that warning type (not file warnings in
;; general): its type is (files missing-lexbind-cookie FILE), matched by prefix.
(require 'warnings)
(add-to-list 'warning-suppress-types '(files missing-lexbind-cookie))
(add-to-list 'warning-suppress-log-types '(files missing-lexbind-cookie))

(use-package gruber-darker-theme
  :config
  (load-theme 'gruber-darker t))

(add-to-list 'default-frame-alist '(font . "Fixed-13"))

;;; Completion - company

(use-package company
  :config
  (global-company-mode 1))

;;; Multiple cursors - frost has this natively, Emacs needs the package
;;; C-> / C-< add a cursor on the next / previous match of the selection (or the next line), C-S-c C-S-c one per line of
;;; the region. While cursors are up you are in Emacs state (plain typing on every cursor); C-g or RET ends them.

(use-package multiple-cursors
  :bind (("C-S-c C-S-c" . mc/edit-lines)
         ("C->"         . mc/mark-next-like-this)
         ("C-<"         . mc/mark-previous-like-this)
         ("C-c C-<"     . mc/mark-all-like-this))
  :config
  ;; evil's normal-state keys are not repeated per cursor: drop to Emacs state for the duration instead
  (with-eval-after-load 'evil
    (add-hook 'multiple-cursors-mode-enabled-hook #'evil-emacs-state)
    (add-hook 'multiple-cursors-mode-disabled-hook #'evil-normal-state)))

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
  (evil-collection-init))         ; evil bindings for magit, dired, elfeed, gnus, etc.

;;; Tabs - tab-line: a window shows the buffers it has displayed as tabs. Files that come from nnn, Godot or a script
;;; open in the one Emacs frame (lisp/dev-server.el), so they collect here. gt / gT next / previous, :bd closes one.

(require 'tab-line)
(setq tab-line-new-button-show nil
      tab-line-close-button-show nil)
;; stock faces are a light-grey variable-pitch bar; take the theme's mode-line colours and the bitmap font instead
(set-face-attribute 'tab-line nil :inherit 'mode-line-inactive :height 1.0 :background 'unspecified :foreground 'unspecified)
(set-face-attribute 'tab-line-tab nil :box nil)
(set-face-attribute 'tab-line-tab-inactive nil :background 'unspecified)
(set-face-attribute 'tab-line-tab-current nil :inherit 'mode-line :background 'unspecified)
(set-face-attribute 'tab-line-highlight nil :inherit 'mode-line-highlight :box nil :background 'unspecified
                    :foreground 'unspecified)
(global-tab-line-mode 1)

(with-eval-after-load 'evil
  (define-key evil-motion-state-map "gt" #'tab-line-switch-to-next-tab)   ; evil's default is tab-bar, unused here
  (define-key evil-motion-state-map "gT" #'tab-line-switch-to-prev-tab))

;;; GDB - built in, no LSP involved. M-x gdb, give it a command like
;;; "gdb --args ./myprog arg1", gdb-many-windows gives the multi-pane
;;; locals/breakpoints/stack layout.
(setq gdb-many-windows t
      gdb-show-main t)

;;; Compile - C-c r builds/runs/tests with `compile-command' from the project root: a guess per project and language
;;; (lisp/dev-compile.el), or whatever the project's .dir-locals.el says (e.g. "godot --path ."), so Godot output lands in
;;; an Emacs buffer instead of needing the editor.
(global-set-key (kbd "C-c r") #'compile)

;;; Org mode - notes, and the todo list: C-c c captures a TODO into ~/org/todo.org (with a link back to where you were),
;;; C-c a shows the agenda of everything in ~/org

(use-package org
  :ensure nil                     ; built into Emacs, just configuring it
  :bind (("C-c a" . org-agenda)
         ("C-c c" . org-capture))
  :config
  (setq org-startup-indented t
        org-hide-emphasis-markers t
        org-ellipsis " ▾"
        org-todo-keywords '((sequence "TODO" "IN-PROGRESS" "|" "DONE" "CANCELLED"))
        org-log-done 'time         ; stamps when a task flips to DONE
        org-directory "~/org"
        org-default-notes-file (expand-file-name "todo.org" org-directory)
        org-agenda-files (list org-directory)
        org-capture-templates
        '(("t" "todo" entry (file+headline org-default-notes-file "Inbox") "* TODO %?\n%U\n%a\n" :empty-lines 1)))
  ;; made up front, so the first capture doesn't get the new-.org-file template wrapped around it
  (unless (file-exists-p org-default-notes-file)
    (make-directory org-directory t)
    (with-temp-file org-default-notes-file (insert "#+title: todo\n\n* Inbox\n"))))

;; vim keys that understand org: >> / << promote and demote, t cycles TODO, o / O new heading or item, agenda keys too
(use-package evil-org
  :after (evil org)
  :hook (org-mode . evil-org-mode))
(with-eval-after-load 'org-agenda          ; the agenda can come up before any org buffer has loaded evil-org
  (require 'evil-org-agenda)
  (evil-org-agenda-set-keys))

;;; Magit - git porcelain

(use-package magit
  :commands (magit-status magit-dispatch)
  :bind ("C-c g" . magit-status))

;;; Diff-hl - +/-/! in the margin for uncommitted git changes, updated while typing and after magit acts. Margin, not
;;; fringe, because terminal frames (emacsclient -t) have no fringe.

(use-package diff-hl
  :config
  (global-diff-hl-mode 1)
  (diff-hl-flydiff-mode 1)
  (diff-hl-margin-mode 1)
  (add-hook 'magit-post-refresh-hook #'diff-hl-magit-post-refresh))

;;; Which-key - shows available keys after a prefix, instead of a cheat sheet

(use-package which-key
  :config
  (which-key-mode 1))

;;; Browser - links (org, elfeed, magit, eww) open in Nyxt when it is installed, else in the system default

(when (executable-find "nyxt")
  (setq browse-url-browser-function #'browse-url-generic
        browse-url-generic-program "nyxt"))

;;; Dev modules - ~/.config/emacs/lisp/*.el, each independent: delete its name from the list to drop it.
;;; A module that fails to load is reported in *Messages* and skipped; it can't take startup down with it.

(add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))
(dolist (module '(dev-server dev-nav dev-compile dev-shell dev-lang dev-debug dev-godot dev-merge dev-templates dev-inbox
                  claude-api claude-mcp))
  (condition-case err
      (require module)
    (error (message "dev module %s failed to load: %S" module err))))
