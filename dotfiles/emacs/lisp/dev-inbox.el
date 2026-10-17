;;; dev-inbox.el --- what comes in: RSS (elfeed) and mail (Gnus + smtpmail, built in)  -*- lexical-binding: t; -*-
;;
;; The todo list is org (C-c c capture, C-c a agenda, see emac.el). Here the other two inboxes. Their data lives under
;; ~/.local/share/emacs/, never in the repo.
;;
;; RSS   C-c n   elfeed.  G fetch, RET read, b open in the browser (Nyxt when installed), r / u read / unread, s filter.
;;               Feeds: `elfeed-feeds' below, edit freely.
;;
;; Mail  C-c e   Gnus over IMAP.  C-x m writes a mail (message-mode), C-c C-c sends it through SMTP.
;;               Once, in ~/.config/emacs/local.el (gitignored):
;;                 (setq user-full-name "Name" user-mail-address "you@example.com")
;;               and the passwords in ~/.authinfo.gpg (for Gmail an app password):
;;                 machine imap.example.com login you@example.com password SECRET port 993
;;                 machine smtp.example.com login you@example.com password SECRET port 587
;;               Servers are imap./smtp. + the address's domain (gmail.com -> imap.gmail.com, smtp.gmail.com) unless
;;               local.el sets `my/mail-imap-server' / `my/mail-smtp-server'.

(require 'subr-x)

(defvar my/data-dir (expand-file-name "emacs/" (or (getenv "XDG_DATA_HOME") "~/.local/share/")))   ; emac.el sets it

;;; RSS

(use-package elfeed
  :bind ("C-c n" . elfeed)
  :init
  (setq elfeed-db-directory (expand-file-name "elfeed" my/data-dir)
        elfeed-search-filter "@2-weeks-ago +unread"
        elfeed-feeds
        '("https://lwn.net/headlines/rss"
          "https://www.phoronix.com/rss.php"
          "https://archlinux.org/feeds/news/"
          "https://www.kernel.org/feeds/kdist.xml"
          "https://godotengine.org/rss.xml"
          "https://nullprogram.com/feed/"
          "https://www.computerenhance.com/feed"
          "https://planet.emacslife.com/atom.xml"
          "https://hnrss.org/frontpage?points=200")))

;;; Mail

(defun my/mail--configured-p ()
  "Non-nil once local.el has set a real address (Emacs's own default is login@hostname)."
  (and (stringp user-mail-address)
       (not (equal user-mail-address (concat (user-login-name) "@" (or mail-host-address (system-name)))))
       (string-match-p "@.+\\." user-mail-address)))

(defun my/mail--server (kind)
  (when (my/mail--configured-p)
    (concat kind "." (cadr (split-string user-mail-address "@")))))

(defvar my/mail-imap-server (my/mail--server "imap") "IMAP host Gnus reads from.")
(defvar my/mail-smtp-server (my/mail--server "smtp") "SMTP host mail goes out through.")

;; Gnus computes its file names from these when it loads, so they are set before it does
(setq gnus-home-directory (expand-file-name "gnus/" my/data-dir)
      gnus-directory (expand-file-name "News/" gnus-home-directory)
      message-directory (expand-file-name "Mail/" gnus-home-directory)
      gnus-select-method `(nnimap "mail"
                                  (nnimap-address ,(or my/mail-imap-server "imap.invalid"))
                                  (nnimap-server-port 993)
                                  (nnimap-stream ssl))
      gnus-inhibit-startup-message t)

(setq send-mail-function #'smtpmail-send-it
      message-send-mail-function #'smtpmail-send-it
      smtpmail-smtp-server my/mail-smtp-server
      smtpmail-smtp-service 587
      smtpmail-stream-type 'starttls
      message-kill-buffer-on-exit t)

(defun my/mail ()
  "Read mail: Gnus on `my/mail-imap-server'."
  (interactive)
  (unless (my/mail--configured-p)
    (user-error "No mail address yet: set user-mail-address in %s (see lisp/dev-inbox.el)"
                (abbreviate-file-name (expand-file-name "local.el" user-emacs-directory))))
  (make-directory gnus-home-directory t)
  (gnus))
(global-set-key (kbd "C-c e") #'my/mail)

(provide 'dev-inbox)
;;; dev-inbox.el ends here
