;; -*- lexical-binding: t; -*-
;; Runs before package.el and GUI init — kill chrome before it ever paints.
(setq inhibit-startup-screen t
      inhibit-startup-message t
      inhibit-startup-echo-area-message user-login-name
      initial-scratch-message nil
      use-dialog-box nil
      frame-inhibit-implied-resize t
      gc-cons-threshold most-positive-fixnum)

(push '(menu-bar-lines . 0) default-frame-alist)
(push '(tool-bar-lines . 0) default-frame-alist)
(push '(vertical-scroll-bars . nil) default-frame-alist)
(push '(horizontal-scroll-bars . nil) default-frame-alist)
