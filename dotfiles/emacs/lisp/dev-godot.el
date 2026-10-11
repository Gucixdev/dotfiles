;;; dev-godot.el --- Godot <-> Emacs, no language server  -*- lexical-binding: t; -*-
;;
;; Editing      gdscript-mode for *.gd / *.gdshader (tabs, Godot's indentation rules).
;; Diagnostics  the ENGINE is the checker: on save, `godot --headless --check-only --script' parses the file and flymake shows
;;              the error on its line (C-c d lists, ]d [d jump). Works with the editor closed. It reports the first parse error
;;              of the file, like the engine does - the same thing you would see in the editor's output.
;; External     Godot -> Emacs: Editor Settings > Text Editor > External is `emacsclient ... +{line}:{col} {file}';
;;              dev-server.el makes this Emacs the server, so a click in Godot opens the script as a frame here.
;; Project      a directory with project.godot is a project for project.el, compile and tags.
;;
;;   C-c G r  run the project        C-c G s  run the scene of this buffer       C-c G e  open the project in the editor
;;   C-c G c  check this script with the engine, output in a compilation buffer (clickable errors)
;;   C-c f    format (gdformat from gdtoolkit when installed, see dev-nav.el)

(require 'project)
(require 'subr-x)

(defun my/godot-project-root (&optional dir)
  "The nearest directory above DIR (default: here) containing project.godot, or nil."
  (locate-dominating-file (or dir default-directory) "project.godot"))

(defun my/godot-project-find (dir)
  (when-let* ((root (my/godot-project-root dir)))
    (cons 'transient root)))
(add-to-list 'project-find-functions #'my/godot-project-find)

(defun my/godot--exe ()
  (or (executable-find "godot") (user-error "godot is not on PATH")))

(defun my/godot--root ()
  (or (my/godot-project-root) (user-error "not inside a Godot project (no project.godot above here)")))

(defun my/godot--res-path (file root)
  (concat "res://" (file-relative-name file root)))

(defun my/godot-run-project ()
  "Run the project (its main scene) and keep the engine's output in a compilation buffer."
  (interactive)
  (let ((default-directory (my/godot--root)))
    (compile (format "%s --path %s" (shell-quote-argument (my/godot--exe)) (shell-quote-argument default-directory)))))

(defun my/godot-run-scene ()
  "Run the scene in the current buffer (or, in a script, the scene with the same base name next to it)."
  (interactive)
  (let* ((root (my/godot--root))
         (file (or buffer-file-name (user-error "buffer has no file")))
         (scene (if (string-suffix-p ".tscn" file) file (concat (file-name-sans-extension file) ".tscn"))))
    (unless (file-exists-p scene)
      (user-error "no scene to run: %s" (file-name-nondirectory scene)))
    (let ((default-directory root))
      (compile (format "%s --path %s %s" (shell-quote-argument (my/godot--exe)) (shell-quote-argument root)
                       (shell-quote-argument (my/godot--res-path scene root)))))))

(defun my/godot-check-script ()
  "Check the current .gd with the engine itself (no editor needed), output in a compilation buffer."
  (interactive)
  (let* ((root (my/godot--root))
         (file (or buffer-file-name (user-error "buffer has no file")))
         (default-directory root))
    (when (buffer-modified-p) (save-buffer))
    (compile (format "%s --headless --path %s --check-only --script %s"
                     (shell-quote-argument (my/godot--exe)) (shell-quote-argument root)
                     (shell-quote-argument (my/godot--res-path file root))))))

(defun my/godot-open-in-editor ()
  "Open this project in the Godot editor (detached from Emacs)."
  (interactive)
  (let ((root (my/godot--root)))
    (call-process "setsid" nil 0 nil "-f" (my/godot--exe) "--editor" "--path" root)
    (message "starting the Godot editor for %s" root)))

;;; flymake backend: the engine's own parser

(defvar-local my/--godot-check-proc nil)

(defun my/godot--parse (output buffer)
  "Diagnostics for BUFFER from the engine's --check-only OUTPUT."
  (let (diags)
    (with-temp-buffer
      (insert output)
      (goto-char (point-min))
      (while (re-search-forward
              "SCRIPT ERROR: \\(?:Parse Error: \\)?\\(.*\\)\n *at: GDScript::reload (res://[^:]+:\\([0-9]+\\))" nil t)
        (let* ((msg (match-string 1)) (line (string-to-number (match-string 2)))
               (region (flymake-diag-region buffer line)))
          (when region
            (push (flymake-make-diagnostic buffer (car region) (cdr region) :error msg) diags)))))
    (nreverse diags)))

(defun my/godot-flymake (report-fn &rest _args)
  "Flymake backend: run the engine's checker on the file as saved on disk."
  (let ((root (and buffer-file-name (my/godot-project-root)))
        (exe (executable-find "godot"))
        (src (current-buffer)))
    (when (process-live-p my/--godot-check-proc)
      (kill-process my/--godot-check-proc))
    (if (not (and root exe (string-suffix-p ".gd" buffer-file-name)))
        (funcall report-fn nil)
      (let* ((out (generate-new-buffer " *godot-check*"))
             (proc (make-process
                    :name "godot-check" :buffer out :noquery t :connection-type 'pipe
                    :command (list exe "--headless" "--path" root "--check-only" "--script"
                                   (my/godot--res-path buffer-file-name root))
                    :sentinel
                    (lambda (p _event)
                      (when (memq (process-status p) '(exit signal))
                        (unwind-protect
                            (when (buffer-live-p src)
                              (with-current-buffer (process-buffer p)
                                (funcall report-fn (my/godot--parse (buffer-string) src))))
                          (kill-buffer (process-buffer p))))))))
        (setq my/--godot-check-proc proc)))))

(defun my/godot-flymake-setup ()
  (add-hook 'flymake-diagnostic-functions #'my/godot-flymake nil t)
  ;; the engine reads the file from disk, so only a check after saving is meaningful
  (setq-local flymake-no-changes-timeout nil)
  (flymake-mode 1))

(use-package gdscript-mode
  :mode ("\\.gd\\'" "\\.gdshader\\'")
  :init
  (setq gdscript-use-tab-indents t
        gdscript-indent-offset 4)
  :hook (gdscript-mode . my/godot-flymake-setup)
  :config
  (define-key gdscript-mode-map (kbd "C-c G r") #'my/godot-run-project)
  (define-key gdscript-mode-map (kbd "C-c G s") #'my/godot-run-scene)
  (define-key gdscript-mode-map (kbd "C-c G c") #'my/godot-check-script)
  (define-key gdscript-mode-map (kbd "C-c G e") #'my/godot-open-in-editor))

;; the same commands from any buffer inside a Godot project (scenes, resources, project.godot)
(global-set-key (kbd "C-c G r") #'my/godot-run-project)
(global-set-key (kbd "C-c G e") #'my/godot-open-in-editor)

(provide 'dev-godot)
;;; dev-godot.el ends here
