;;; rust.el --- Rust (rust-mode + cargo, format with C-c f)  -*- lexical-binding: t; -*-

(use-package rust-mode
  :mode "\\.rs\\'"
  :init (setq rust-format-on-save nil))      ; formatting is explicit: C-c f

(use-package cargo
  :hook (rust-mode . cargo-minor-mode))


(provide 'lang-rust)
;;; rust.el ends here
