;;; dev-lang.el --- the languages: modes and the project tooling around them  -*- lexical-binding: t; -*-
;;
;; No language servers (see dev-nav.el for how navigation, diagnostics and formatting work without one). Build, check and
;; test go through compile (dev-compile.el picks the command). Built in unless noted:
;;
;; C / C++     cc-mode, K&R braces, one tab per level (shown 4 wide) - the shape of the file templates
;; Rust        rust-mode + cargo-minor-mode (packages):  C-c C-c C-b build   C-c C-c C-r run   C-c C-c C-t test   C-c C-c C-l clippy
;; Go          go-mode (package); gofmt with C-c f
;; Bash        sh-mode, see dev-shell.el
;; Perl        cperl-mode for every Perl file
;; Python      python-mode; pyvenv (package) picks up a project's .venv by itself, so `python', pip and compile see its
;;             packages; pip-requirements for requirements*.txt;  M-x my/pip-install-requirements
;; GDScript    gdscript-mode (package), see dev-godot.el
;; Ruby/Rails  ruby-mode for .rb Rakefile Gemfile .rake .gemspec; web-mode (package) for .erb views. From a Rails app,
;;             C-c r offers bin/rails test
;; TypeScript  typescript-mode (package) for .ts; web-mode for .tsx / .jsx
;; Nix         nix-mode (package) for *.nix

;;; C / C++

(setq c-default-style '((java-mode . "java") (awk-mode . "awk") (other . "linux")))
(add-hook 'c-mode-common-hook
          (lambda () (setq-local indent-tabs-mode t
                                 c-basic-offset tab-width)))

;;; Rust

(use-package rust-mode
  :mode "\\.rs\\'"
  :init (setq rust-format-on-save nil))      ; formatting is explicit: C-c f

(use-package cargo
  :hook (rust-mode . cargo-minor-mode))

;;; Go

(use-package go-mode
  :mode "\\.go\\'")                          ; tabs and gofmt's layout come with the mode; format with C-c f

;;; Perl

(add-to-list 'major-mode-remap-alist '(perl-mode . cperl-mode))
(setq cperl-indent-level 4)

;;; Python

(use-package pyvenv
  :commands (pyvenv-activate pyvenv-deactivate pyvenv-workon))

(use-package pip-requirements
  :mode ("requirements.*\\.txt\\'" . pip-requirements-mode))

(defun my/python-venv-dir ()
  "The nearest .venv or venv directory above the current file, or nil."
  (when-let* ((root (or (locate-dominating-file default-directory ".venv")
                       (locate-dominating-file default-directory "venv"))))
    (let ((dir (expand-file-name (if (file-directory-p (expand-file-name ".venv" root)) ".venv" "venv") root)))
      (and (file-exists-p (expand-file-name "bin/python" dir)) dir))))

(add-hook 'python-mode-hook
          (lambda ()
            (when-let* ((venv (my/python-venv-dir)))
              (require 'pyvenv)
              (unless (equal pyvenv-virtual-env (file-name-as-directory venv))
                (pyvenv-activate venv)))))

(defun my/pip-install-requirements ()
  "pip install -r requirements.txt of the current project, inside its venv (created as .venv if there is none)."
  (interactive)
  (let* ((root (or (locate-dominating-file default-directory "requirements.txt")
                   (user-error "no requirements.txt above %s" default-directory)))
         (default-directory root)
         (venv (or (let ((default-directory root)) (my/python-venv-dir)) (expand-file-name ".venv" root))))
    (compile (format "[ -x %s/bin/python ] || python3 -m venv %s; %s/bin/python -m pip install -r requirements.txt"
                     (shell-quote-argument venv) (shell-quote-argument venv) (shell-quote-argument venv)))))

;;; Ruby / Rails, TypeScript

;; ruby-mode registers its own files; web-mode takes the templates: Rails views, and TSX/JSX that typescript-mode can't indent
(use-package web-mode
  :mode ("\\.erb\\'" "\\.[jt]sx\\'")
  :init
  (setq web-mode-markup-indent-offset 2
        web-mode-css-indent-offset 2
        web-mode-code-indent-offset 2
        web-mode-content-types-alist '(("jsx" . "\\.[jt]sx\\'"))))

(use-package typescript-mode
  :mode ("\\.ts\\'" "\\.[cm]ts\\'")
  :init (setq typescript-indent-level 2))

;;; Nix

(use-package nix-mode
  :mode "\\.nix\\'")

(provide 'dev-lang)
;;; dev-lang.el ends here
