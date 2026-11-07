;;; lua.el --- Lua and Teal  -*- lexical-binding: t; -*-

(use-package lua-mode :mode "\\.lua\\'")
;; no maintained teal major mode on MELPA: lua-mode stands in for .tl
(add-to-list 'auto-mode-alist '("\\.tl\\'" . lua-mode))

(provide 'lang-lua)
;;; lua.el ends here
