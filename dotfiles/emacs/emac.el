;; -*- lexical-binding: t; -*-
;;EDIT  (his list; [x] done 2026-11-07, [ ] open - see the notes in braindump)
;; [x] wyjebac org evil devil god modes  (evil, evil-collection and org are gone; devil/god were never here)
;; [x] skonfigurowac cua mode 1 nativecomp
;; [x] smartparens (wciecia: python/nim/gdscript - strict mode off, it only pairs and wraps)
;; [ ] wtyczka do email/rss: elfeed (RSS) is easy, notmuch needs the notmuch binary + a mail fetcher
;; [ ] cos jak EXWM ale wayland: windows as buffers over dwl's fifo (emacs/dwl.el in ~/dev/desktop is the start)
;; [ ] terminal: vterm needs libvterm built once (cmake is here); eat is pure elisp. wdired done
;; [x] wgrep gcmh dash tempel hydra wdired     [ ] orgcliplink (needs org, which was thrown out) tramp-rpc claude-code-ide
;; [x] osobny folder langs/ (lisp/langs/<lang>.el: rust python nix lisp c lua(+teal via lua-mode) go nim java perl; gdscript = dev-godot.el)
;; [x] paredit - tylko w lispach (langs/lisp.el), smartparens wylaczony tam
;; [ ] wlasny godot mode: dev-godot.el exists (137 lines), gut not started
;; [x] vertico consult embark
;; [ ] hexl (built in) hexasm capstone vterm elfed notmuch forge eglot dap-mode
;;     NOTE: dev-nav.el says "no LSP anywhere, on purpose" but eglot is on this list - one of the two has to give.

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

;;; Speed - native compilation (Emacs 31 has it) and a GC that waits for idle time instead of pausing while typing

(setq native-comp-jit-compilation t
      native-comp-async-report-warnings-errors 'silent
      package-native-compile nil)   ; packages are compiled lazily by the JIT, not synchronously at install (that popped the warnings)
;; third-party packages reference optional things (org, evil, eglot, lsp) that are not installed here on purpose: not our warnings
(require 'warnings)
(add-to-list 'warning-suppress-types '(native-compiler))
(add-to-list 'warning-suppress-log-types '(native-compiler))
(add-to-list 'warning-suppress-types '(comp))
(use-package gcmh
  :config (gcmh-mode 1))

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

;; auto-reload a buffer when the file behind it changes on disk (e.g. an
;; external tool edits it) instead of showing stale content or prompting
(setq auto-revert-verbose nil)      ; don't spam the minibuffer every reload
(global-auto-revert-mode 1)

;; real system clipboard: kill/yank (and CUA C-c/C-x/C-v) reach wl-copy/wl-paste,
;; not just an Emacs-internal kill-ring
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

;;; CUA - C-c / C-x / C-v copy, cut, paste with a region (and keep C-c / C-x as prefixes when there is none). Rectangles: C-RET.
;;; select-enable-clipboard above makes these reach the real system clipboard.

(cua-mode 1)

;;; GDB - built in, no LSP involved. M-x gdb, give it a command like
;;; "gdb --args ./myprog arg1", gdb-many-windows gives the multi-pane
;;; locals/breakpoints/stack layout.
(setq gdb-many-windows t
      gdb-show-main t)

;;; Compile - C-c r runs/builds whatever `compile-command` is for this
;;; project (set per-project via .dir-locals.el, e.g. "godot --path .")
;;; so Godot output lands in an Emacs buffer instead of needing the editor.
(global-set-key (kbd "C-c r") #'compile)

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

;;; Search and completion in the minibuffer - vertico (the list), consult (search/switch commands), embark (act on what is selected)

(use-package vertico
  :config (vertico-mode 1))
(use-package consult
  :bind (("C-s"     . consult-line)
         ("C-x b"   . consult-buffer)
         ("M-y"     . consult-yank-pop)
         ("M-g g"   . consult-goto-line)
         ("M-s r"   . consult-ripgrep)))
(use-package embark
  :bind (("C-."   . embark-act)
         ("C-;"   . embark-dwim)))
(use-package embark-consult           ; the glue Embark asks for when both are installed
  :after (embark consult))

;;; Editing helpers

;; wgrep: edit the results buffer of grep/ripgrep (C-c C-p in a grep buffer, C-c C-c applies to the files)
(use-package wgrep
  :custom (wgrep-auto-save-buffer t))
;; wdired: rename files by editing the dired buffer as text (C-x C-q in dired, C-c C-c to apply)
(setq wdired-allow-to-change-permissions t)
;; smartparens: pairs, wrap and slurp without the strictness of paredit - indentation languages keep working
(use-package smartparens
  :config
  (require 'smartparens-config)
  (smartparens-global-mode 1)
  (electric-pair-mode 0))                  ; one pairing engine, not two
;; tempel: small snippets (C-c t is TAGS in dev-nav, so M-+ completes, M-* inserts)
(use-package tempel
  :bind (("M-+" . tempel-complete)
         ("M-*" . tempel-insert)))
(use-package dash)
;; hydra: key menus; one for window/split handling to start with
(use-package hydra
  :config
  (defhydra my/hydra-windows (global-map "C-c w")
    "windows"
    ("h" windmove-left "left") ("j" windmove-down "down") ("k" windmove-up "up") ("l" windmove-right "right")
    ("s" split-window-below "split -") ("v" split-window-right "split |") ("d" delete-window "close")
    ("o" delete-other-windows "only")))

;;; Dev modules - ~/.config/emacs/lisp/*.el, each independent: delete its name from the list to drop it.
;;; A module that fails to load is reported in *Messages* and skipped; it can't take startup down with it.

(add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))
(dolist (module '(dev-server dev-nav dev-shell dev-lang dev-debug dev-godot dev-merge dev-templates claude-api))
  (condition-case err
      (require module)
    (error (message "dev module %s failed to load: %S" module err))))
