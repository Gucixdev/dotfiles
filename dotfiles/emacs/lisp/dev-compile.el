;;; dev-compile.el --- compile-mode is the build, check and test tool: one command per project, re-run on save  -*- lexical-binding: t; -*-
;;
;; No language server, no task-runner UI: `compile' runs a shell command and its output is a buffer of clickable errors.
;;
;;   C-c r    compile (emac.el). The prompt starts with this buffer's `compile-command': the project's own when its
;;            .dir-locals.el sets one, else a guess from what the project root holds (`my/compile-project-commands') or,
;;            for a lone file, from the language (`my/compile-file-command'). It runs from that root.
;;   C-c R    recompile: the last command again, same directory, from any buffer
;;   M-g n / M-g p   next / previous error, from any buffer
;;   C-c A    autotest: toggle re-running the last compile whenever a file under its directory is saved
;;
;; A project that knows better says so once, in .dir-locals.el at its root:
;;   ((nil . ((compile-command . "./build.sh && ./test"))))

(require 'compile)
(require 'ansi-color)
(require 'seq)
(require 'subr-x)

(setq compilation-scroll-output 'first-error   ; follow the output, stop at the first error
      compilation-always-kill t                 ; a new run replaces a running one without asking
      ansi-color-for-compilation-mode 'filter)  ; strip colour codes: plain text, and error regexps still match
(add-hook 'compilation-filter-hook #'ansi-color-compilation-filter)

;;; The guess

(defconst my/compile-project-commands
  '(("build.sh"       . "./build.sh")
    ("nob"            . "./nob")
    ("nob.c"          . "cc -o nob nob.c && ./nob")
    ("Cargo.toml"     . "cargo build")
    ("go.mod"         . "go build ./... && go vet ./...")
    ("bin/rails"      . "bin/rails test")
    ("Gemfile"        . "bundle exec rake")
    ("tsconfig.json"  . "npx tsc --noEmit --pretty false -p .")
    ("package.json"   . "npm test")
    ("pyproject.toml" . "python3 -m pytest -q")
    ("project.godot"  . "godot --path .")
    ("Makefile"       . "make -k"))
  "FILE . COMMAND: a directory holding FILE is a project root and builds with COMMAND (run from there).
The nearest such directory above the buffer wins; within it, the first matching FILE.")

(defun my/compile-file-command (file)
  "Command that checks or builds the lone FILE (a relative name) by its major mode, or nil."
  (let ((q (shell-quote-argument file))
        (out (shell-quote-argument (file-name-sans-extension file))))
    (cond
     ((derived-mode-p 'c-mode)          (format "cc -std=c89 -pedantic -Wall -Wextra -g -o %s %s" out q))
     ((derived-mode-p 'c++-mode)        (format "c++ -std=c++17 -Wall -Wextra -g -o %s %s" out q))
     ((derived-mode-p 'go-mode)         (format "go vet %s && go run %s" q q))
     ((derived-mode-p 'rust-mode)       (format "rustc -g %s" q))
     ((derived-mode-p 'sh-mode)         (format "shellcheck -f gcc %s" q))
     ((derived-mode-p 'cperl-mode 'perl-mode) (format "perl -wc %s" q))
     ((derived-mode-p 'python-mode)     (format "python3 %s" q))
     ((derived-mode-p 'ruby-mode)       (format "ruby -wc %s" q))
     ((derived-mode-p 'typescript-mode) (format "npx tsc --noEmit --pretty false %s" q)))))

(defun my/compile--project ()
  "(ROOT . COMMAND) from the nearest directory above here that holds one of `my/compile-project-commands', or nil."
  (when-let* ((root (locate-dominating-file
                     default-directory
                     (lambda (dir) (seq-some (lambda (e) (file-exists-p (expand-file-name (car e) dir)))
                                             my/compile-project-commands)))))
    (cons root (cdr (seq-find (lambda (e) (file-exists-p (expand-file-name (car e) root)))
                              my/compile-project-commands)))))

(defvar-local my/compile-directory nil "Where C-c r runs `compile-command' for this buffer.")

(defun my/compile-setup ()
  "Give this file buffer a `compile-command' and the directory to run it in, unless .dir-locals.el already did."
  (when buffer-file-name
    (if (local-variable-p 'compile-command)
        (setq my/compile-directory (or (locate-dominating-file default-directory ".dir-locals.el") default-directory))
      (if-let* ((project (my/compile--project)))
          (setq-local compile-command (cdr project)
                      my/compile-directory (car project))
        (when-let* ((cmd (my/compile-file-command (file-name-nondirectory buffer-file-name))))
          (setq-local compile-command cmd
                      my/compile-directory default-directory))))))
(add-hook 'hack-local-variables-hook #'my/compile-setup)   ; runs after .dir-locals.el is applied

(defun my/compile ()
  "`compile', started from `my/compile-directory' so ./build.sh and the file names in its errors resolve."
  (interactive)
  (let ((default-directory (or my/compile-directory default-directory)))
    (call-interactively #'compile)))

(global-set-key (kbd "C-c r") #'my/compile)
(global-set-key (kbd "C-c R") #'recompile)

;;; Errors the built-in regexps miss

;; Godot prints `   at: _ready (res://player.gd:12)' after an error; res:// is the project root, where it was run from
(add-to-list 'compilation-error-regexp-alist-alist
             '(godot "^[ \t]*at: [^\n(]*(res://\\([^:)\n]+\\):\\([0-9]+\\))" 1 2))
(add-to-list 'compilation-error-regexp-alist 'godot)

;;; Autotest

(defun my/autotest--buffer ()
  "The last compilation buffer that still has a command to repeat, or nil."
  (let ((buf (get-buffer "*compilation*")))
    (and buf (buffer-local-value 'compilation-arguments buf) buf)))

(defun my/autotest--on-save ()
  (when-let* ((buf (my/autotest--buffer))
              (dir (buffer-local-value 'default-directory buf))
              ((and buffer-file-name (file-in-directory-p buffer-file-name dir)))
              ((not (eq (current-buffer) buf))))
    (with-current-buffer buf
      ;; only this save triggered it: don't stop to ask about (or silently save) other modified buffers
      (let ((compilation-ask-about-save nil)
            (compilation-save-buffers-predicate #'ignore))
        (recompile)))))

(define-minor-mode my/autotest-mode
  "After each save of a file under the last compile's directory, run that compile again (tests, a build, a check).
Turning it on with nothing compiled yet asks for the command first, like C-c r."
  :global t :lighter " autotest" :group 'compilation
  (if (not my/autotest-mode)
      (remove-hook 'after-save-hook #'my/autotest--on-save)
    (add-hook 'after-save-hook #'my/autotest--on-save)
    (unless (my/autotest--buffer)
      (call-interactively #'my/compile))))
(global-set-key (kbd "C-c A") #'my/autotest-mode)

(provide 'dev-compile)
;;; dev-compile.el ends here
