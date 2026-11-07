;;; c.el --- C and C++ (built-in modes, only the style)  -*- lexical-binding: t; -*-

(setq c-default-style '((c-mode . "k&r") (c++-mode . "stroustrup") (other . "gnu"))
      c-basic-offset 4)
(add-to-list 'auto-mode-alist '("\\.h\\'" . c-mode))   ; headers are C here (holyc is C89 stb-style)

(provide 'lang-c)
;;; c.el ends here
