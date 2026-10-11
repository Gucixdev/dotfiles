;;; dev-debug.el --- gdb (built-in gud) and DAP debuggers (dape)  -*- lexical-binding: t; -*-
;;
;; gdb      M-x gdb RET gdb --args ./prog arg1     many-windows layout: locals / breakpoints / stack / source / io
;; dape     M-x dape  (completing read of debug configs: gdb through gdb's native DAP, and Godot's debug adapter)
;;
;;   C-c D d  start / pick a debug config      C-c D b  toggle breakpoint        C-c D c  continue
;;   C-c D n  next (over)                      C-c D s  step in                  C-c D o  step out
;;   C-c D r  restart                          C-c D q  quit the session         C-c D e  evaluate expression

(setq gdb-many-windows t
      gdb-show-main t
      gdb-debuginfod-enable-setting nil)      ; don't ask to download debug info on every session

(use-package dape
  :commands (dape dape-breakpoint-toggle dape-continue dape-next dape-step-in dape-step-out dape-restart dape-quit dape-eval)
  :init
  (setq dape-buffer-window-arrangement 'gud    ; same gdb-like layout as M-x gdb
        dape-inlay-hints nil)                   ; plain text, like the rest of the setup
  :bind (("C-c D d" . dape)
         ("C-c D b" . dape-breakpoint-toggle)
         ("C-c D c" . dape-continue)
         ("C-c D n" . dape-next)
         ("C-c D s" . dape-step-in)
         ("C-c D o" . dape-step-out)
         ("C-c D r" . dape-restart)
         ("C-c D q" . dape-quit)
         ("C-c D e" . dape-eval)))

(provide 'dev-debug)
;;; dev-debug.el ends here
