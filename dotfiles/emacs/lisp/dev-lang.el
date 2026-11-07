;;; dev-lang.el --- loads lisp/langs/*.el, one file per language  -*- lexical-binding: t; -*-
;;
;; No language servers (see dev-nav.el for navigation, diagnostics and formatting without one). Each file in langs/ is
;; independent: delete the file to drop the language. A file that fails to load is reported and skipped.
;; Rust: C-c C-c C-b build / C-r run / C-t test / C-l clippy.  Python: .venv auto-activated, M-x my/pip-install-requirements.

(let ((dir (expand-file-name "langs" (file-name-directory (or load-file-name buffer-file-name)))))
  (add-to-list 'load-path dir)
  (dolist (f (directory-files dir t "\\.el\\'"))
    (condition-case err
        (load f nil t)
      (error (message "lang %s failed to load: %S" (file-name-base f) err)))))

(provide 'dev-lang)
;;; dev-lang.el ends here
