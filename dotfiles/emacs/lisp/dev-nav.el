;;; dev-nav.el --- navigation, diagnostics and formatting WITHOUT a language server  -*- lexical-binding: t; -*-
;;
;; No LSP anywhere in this config, on purpose: no resident server per language, no protocol layer between the editor and the code.
;; The compiler, grep and tags are the tools. What does the job instead:
;;
;;   Definitions   M-.   xref over an etags TAGS table. `C-c t' (re)builds it for the project; the first M-. in a project
;;                       without one builds it for you. etags understands C, C++, Rust, Python, Bash, Lisp ...
;;   Find uses     M-?   ripgrep through xref
;;   Diagnostics   flymake on top of tools that exist anyway: shellcheck (sh, dev-shell.el), gcc -fsyntax-only (C/C++),
;;                 the engine's own checker (GDScript, dev-godot.el), the byte-compiler (Emacs Lisp).
;;                 C-c d  list them    ]d [d  next / previous (evil normal state)
;;   Completion    company: what the major mode offers, words from open buffers, file names
;;   Format        C-c f  clang-format (C/C++), rustfmt (Rust), gofmt (Go), shfmt (sh), gdformat (GDScript), prettier
;;                 (TS/JS, when installed), else the mode's indentation
;;   Build / run   C-c r  compile, see dev-compile.el;  M-g n / M-g p  next / previous error

(require 'project)
(require 'subr-x)

;;; Tags

(defconst my/project-markers '(".git" "project.godot" "Cargo.toml" "go.mod" "Gemfile" "package.json" "build.sh" "nob.c"
                               "Makefile" "meson.build" "CMakeLists.txt" "pyproject.toml")
  "A directory holding one of these is a project root when project.el finds no VCS.")

(defun my/project-root ()
  (or (when-let* ((p (project-current))) (project-root p))
      (cl-some (lambda (m) (locate-dominating-file default-directory m)) my/project-markers)
      default-directory))

(defun my/tags-update ()
  "(Re)build TAGS for the current project from the files ripgrep sees (so .gitignore is respected), and use it."
  (interactive)
  (unless (executable-find "etags") (user-error "etags not found"))
  (let* ((root (my/project-root))
         (default-directory root)
         (code (call-process-shell-command
                (if (executable-find "rg") "rg --files | etags -" "git ls-files | etags -")
                nil nil nil)))
    (unless (zerop code) (user-error "building TAGS failed in %s" root))
    (visit-tags-table (expand-file-name "TAGS" root) t)
    (message "TAGS built in %s" root)))
(global-set-key (kbd "C-c t") #'my/tags-update)

(defun my/tags-ensure (&rest _)
  "First M-. in a project without a TAGS table builds one instead of asking for it."
  (unless (or (derived-mode-p 'emacs-lisp-mode 'lisp-interaction-mode)   ; elisp has its own backend
              (and buffer-file-name (locate-dominating-file buffer-file-name "TAGS"))
              (bound-and-true-p tags-file-name))
    (my/tags-update)))

(with-eval-after-load 'xref
  (setq xref-search-program 'ripgrep
        tags-revert-without-query t)
  (advice-add 'xref-find-definitions :before #'my/tags-ensure))

;;; Diagnostics (flymake)

(setq flymake-no-changes-timeout 1.0
      flymake-start-on-save-buffer t)

(defun my/make-check-syntax-command ()
  "(\"make\" \"-s\" \"check-syntax\" ...) when the project's Makefile really defines a check-syntax target, else nil.
(flymake-cc's own detector answers yes for any Makefile, and then make fails on the missing target.)"
  (when-let* ((dir (locate-dominating-file default-directory "Makefile"))
              (mk (expand-file-name "Makefile" dir))
              ((with-temp-buffer
                 (insert-file-contents mk)
                 (re-search-forward "^check-syntax[ \t]*:" nil t))))
    (list "make" "-s" "-C" (directory-file-name dir) "check-syntax" "CHK_SOURCES=-x c -c -")))

(defun my/flymake-cc-command ()
  "Syntax-check command for flymake-cc: the project's own `check-syntax' make target if it has one, else the compiler
in -fsyntax-only mode reading the buffer from stdin."
  (or (my/make-check-syntax-command)
      (let* ((cxx (derived-mode-p 'c++-mode))
             (cc (or (executable-find (if cxx "g++" "gcc")) (executable-find (if cxx "clang++" "clang")))))
        (when cc
          (append (list cc "-fsyntax-only" "-Wall" "-Wextra" "-x" (if cxx "c++" "c"))
                  (mapcar (lambda (d) (concat "-I" d))
                          (delete-dups (list (directory-file-name default-directory)
                                             (directory-file-name (my/project-root))
                                             (expand-file-name "include" (my/project-root)))))
                  (list "-"))))))

(defun my/flymake-cc-setup ()
  (require 'flymake-cc)
  (setq-local flymake-cc-command #'my/flymake-cc-command)
  (add-hook 'flymake-diagnostic-functions #'flymake-cc nil t)
  (flymake-mode 1))
(add-hook 'c-mode-hook #'my/flymake-cc-setup)
(add-hook 'c++-mode-hook #'my/flymake-cc-setup)
(add-hook 'emacs-lisp-mode-hook #'flymake-mode)

(with-eval-after-load 'elisp-mode
  (setq elisp-flymake-byte-compile-load-path (cons "./" load-path)))

(global-set-key (kbd "C-c d") #'flymake-show-buffer-diagnostics)

(with-eval-after-load 'flymake
  (with-eval-after-load 'evil
    (evil-define-key 'normal flymake-mode-map
      (kbd "]d") #'flymake-goto-next-error
      (kbd "[d") #'flymake-goto-prev-error)))

;;; Completion

(with-eval-after-load 'company
  (setq company-backends '((company-capf company-dabbrev-code company-files))
        company-dabbrev-downcase nil
        company-minimum-prefix-length 2))

;;; Format

(defun my/format--run (program &rest args)
  "Pipe the buffer through PROGRAM; on success replace the contents minimally (point and markers survive)."
  (let ((out (generate-new-buffer " *format*")) (src (current-buffer)))
    (unwind-protect
        (let ((code (apply #'call-process-region (point-min) (point-max) program nil out nil args)))
          (unless (zerop code)
            (user-error "%s failed: %s" program (with-current-buffer out (string-trim (buffer-string)))))
          (with-current-buffer src (replace-buffer-contents out)))
      (kill-buffer out))))

(defun my/format-buffer ()
  "Format the buffer with the language's own formatter; fall back to the major mode's indentation."
  (interactive)
  (let ((file (or buffer-file-name "stdin")))
    (cond
     ((and (derived-mode-p 'c-mode 'c++-mode) (executable-find "clang-format"))
      (my/format--run "clang-format" (concat "--assume-filename=" file)))
     ((and (derived-mode-p 'rust-mode) (executable-find "rustfmt"))
      (my/format--run "rustfmt" "--emit" "stdout" "--edition" "2021"))
     ((and (derived-mode-p 'sh-mode) (executable-find "shfmt"))
      (my/format--run "shfmt"))
     ((and (derived-mode-p 'gdscript-mode) (executable-find "gdformat"))
      (my/format--run "gdformat" "-"))
     ((and (derived-mode-p 'go-mode) (executable-find "gofmt"))
      (my/format--run "gofmt"))
     ((and (derived-mode-p 'typescript-mode 'js-mode 'web-mode) (executable-find "prettier"))
      (my/format--run "prettier" "--stdin-filepath" file))
     (t (indent-region (point-min) (point-max))
        (message "no external formatter for %s: re-indented with the major mode's rules" major-mode)))))
(global-set-key (kbd "C-c f") #'my/format-buffer)

(provide 'dev-nav)
;;; dev-nav.el ends here
