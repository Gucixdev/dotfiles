;;; dev-lang.el --- Rust (cargo), Python (pip/venv), Nix  -*- lexical-binding: t; -*-
;;
;; No language servers (see dev-nav.el for how navigation, diagnostics and formatting work without one). Here: modes and the
;; project tooling around them.
;;
;; Rust    rust-mode + cargo-minor-mode:  C-c C-c C-b build   C-c C-c C-r run   C-c C-c C-t test   C-c C-c C-l clippy
;;         (rustfmt and cargo are installed; format with C-c f)
;; Python  pyvenv picks up a project's .venv automatically (so `python', pip and compile commands see its packages);
;;         pip-requirements for requirements*.txt;  M-x my/pip-install-requirements
;; Nix     nix-mode for *.nix

(use-package rust-mode
  :mode "\\.rs\\'"
  :init (setq rust-format-on-save nil))      ; formatting is explicit: C-c f

(use-package cargo
  :hook (rust-mode . cargo-minor-mode))

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

(use-package nix-mode
  :mode "\\.nix\\'")

(provide 'dev-lang)
;;; dev-lang.el ends here
