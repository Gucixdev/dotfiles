;;; dev-server.el --- make THIS Emacs the server external programs talk to  -*- lexical-binding: t; -*-
;;
;; Godot's "external editor" setting is `emacsclient --alternate-editor="" -n -c +LINE:COL FILE`. Without a running server that
;; falls back to spawning a fresh --daemon on every click; with this, a click in Godot (or `emacsclient` from a script, or nnn)
;; opens the file as a new frame of the Emacs you already have. Only the first Emacs becomes the server - later ones skip it.
;;
;; A daemon auto-spawned by that emacsclient call runs inside Godot's subprocess environment (no DISPLAY/WAYLAND_DISPLAY
;; propagated the same way), so it can crash while creating its first frame and leave the socket file behind uncleaned.
;; (server-running-p) erroring on that leftover - instead of returning nil - must never be allowed to abort this whole
;; init just because of a crash two sessions ago, so this clears a dead socket and retries once before giving up quietly.

(require 'server)

(unless noninteractive
  (condition-case err
      (unless (server-running-p)
        (server-start))
    (error
     (ignore-errors (delete-file (expand-file-name server-name server-socket-dir)))
     (ignore-errors (server-start))
     (message "dev-server: stale socket cleared after error, retried (%s)" (error-message-string err)))))

(provide 'dev-server)
;;; dev-server.el ends here
