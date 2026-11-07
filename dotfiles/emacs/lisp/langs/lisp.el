;;; lisp.el --- Elisp/Lisp: paredit here only, smartparens off in these buffers so they never fight over keys  -*- lexical-binding: t; -*-

;; paredit: M-( wrap, C-) slurp, C-} barf, M-s splice.
(defun my/lisp-structural ()
  (when (fboundp 'smartparens-mode) (smartparens-mode -1))
  (paredit-mode 1))
(use-package paredit
  :hook ((emacs-lisp-mode lisp-mode lisp-interaction-mode scheme-mode) . my/lisp-structural))

(provide 'lang-lisp)
;;; lisp.el ends here
