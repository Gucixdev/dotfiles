;;; python.el --- Python (.venv auto-activation, pip)  -*- lexical-binding: t; -*-

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


(provide 'lang-python)
;;; python.el ends here
