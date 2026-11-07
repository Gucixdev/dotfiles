;;; java.el --- Java (built-in mode, just the indent)  -*- lexical-binding: t; -*-

(add-hook 'java-mode-hook (lambda () (setq c-basic-offset 4)))

(provide 'lang-java)
;;; java.el ends here
