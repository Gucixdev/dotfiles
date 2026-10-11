;;; dev-shell.el --- Bash: shellcheck diagnostics, shfmt, bats tests  -*- lexical-binding: t; -*-
;;
;; sh-mode (built in) understands bash. No language server: flymake runs shellcheck itself through sh-mode's own built-in
;; backend (sh-shellcheck-flymake), so diagnostics show as you save/idle. `C-c d' lists them, ]d [d jump.
;; Format with C-c f (shfmt when installed, see dev-nav.el).
;; Syntax highlighting stays off like everywhere else; M-x font-lock-mode turns it on for a buffer.
;;
;; .bats files get bats-mode (sh-mode + test commands). C-c C-b runs bats on the file / the project's test/ dir;
;; needs `bats' on PATH (pacman -S bats).

(add-hook 'sh-mode-hook
          (lambda ()
            (when (executable-find "shellcheck")
              (flymake-mode 1))))

(use-package bats-mode
  :mode "\\.bats\\'"
  :commands (bats-run-current-file bats-run-all bats-run))

(defun my/bats-run ()
  "Run bats on the current file (or the project's test/ directory), with a clear message when bats is missing."
  (interactive)
  (unless (executable-find "bats")
    (user-error "bats is not installed (pacman -S bats)"))
  (let ((default-directory (or (locate-dominating-file default-directory "test")
                               (locate-dominating-file default-directory ".git")
                               default-directory)))
    (compile (if (and buffer-file-name (string-suffix-p ".bats" buffer-file-name))
                 (format "bats --tap %s" (shell-quote-argument buffer-file-name))
               "bats --tap test"))))

(with-eval-after-load 'sh-script
  (define-key sh-mode-map (kbd "C-c C-b") #'my/bats-run))

(provide 'dev-shell)
;;; dev-shell.el ends here
