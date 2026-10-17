;;; dev-server.el --- THIS Emacs is the server external programs talk to, and it keeps to one window  -*- lexical-binding: t; -*-
;;
;; Godot's "external editor" setting is `emacsclient --alternate-editor="" -n -c +LINE:COL FILE`. Without a running server that
;; falls back to spawning a fresh --daemon on every click; with this, a click in Godot (or `emacsclient` from a script, or nnn)
;; opens the file in the Emacs you already have. Only the first Emacs becomes the server - later ones skip it.
;;
;; One window: Godot, smart-edit and nnn's opener all pass -c, which asks for a NEW frame per file. While
;; `my/server-one-frame' is on, such a request gets the graphical frame that is already open instead: the file shows up there
;; as a new tab (tab-line, emac.el) and the frame is raised. With no frame open yet, one is made as usual. Terminal frames
;; (emacsclient -t from nnn inside foot) are not touched. A second window on purpose: C-x 5 2.
;;
;; A daemon auto-spawned by that emacsclient call runs inside Godot's subprocess environment (no DISPLAY/WAYLAND_DISPLAY
;; propagated the same way), so it can crash while creating its first frame and leave the socket file behind uncleaned.
;; (server-running-p) erroring on that leftover - instead of returning nil - must never be allowed to abort this whole
;; init just because of a crash two sessions ago, so this clears a dead socket and retries once before giving up quietly.

(require 'server)
(require 'seq)

(unless (or noninteractive (daemonp))      ; a daemon starts its own server once init is done
  (condition-case err
      (unless (server-running-p)
        (server-start))
    (error
     (ignore-errors (delete-file (expand-file-name server-name server-socket-dir)))
     (ignore-errors (server-start))
     (message "dev-server: stale socket cleared after error, retried (%s)" (error-message-string err)))))

;;; One window

(defvar my/server-one-frame t
  "Non-nil: an emacsclient request for a new graphical frame gets the one already open.")

(defun my/server--gui-frame ()
  "The open graphical frame to reuse: the selected one when it is graphical, else any visible graphical frame."
  (seq-find (lambda (f) (and (frame-live-p f) (display-graphic-p f) (eq (frame-visible-p f) t)
                             (not (frame-parameter f 'parent-frame))))   ; child frames (popups) are not windows
            (cons (selected-frame) (frame-list))))

(defun my/server-focus-frame ()
  "Bring the selected frame to the front on Hyprland, which ignores an app's own focus request by default."
  (when (and (display-graphic-p) (getenv "HYPRLAND_INSTANCE_SIGNATURE") (executable-find "hyprctl"))
    (call-process "hyprctl" nil 0 nil "dispatch" "focuswindow" (format "pid:%d" (emacs-pid)))))

(defun my/server-reuse-frame (create display nowait proc parent-id &rest args)
  "Around `server-create-window-system-frame': hand the client the open frame instead of making another."
  (let ((frame (and my/server-one-frame (not parent-id) (my/server--gui-frame))))
    (if (not frame)
        (apply create display nowait proc parent-id args)
      (select-frame frame)
      (my/server-focus-frame)
      frame)))

(advice-add 'server-create-window-system-frame :around #'my/server-reuse-frame)
(add-hook 'server-switch-hook #'my/server-focus-frame)   ; also for plain `emacsclient FILE' and -r

(provide 'dev-server)
;;; dev-server.el ends here
