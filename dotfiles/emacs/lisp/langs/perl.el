;;; perl.el --- Perl (cperl-mode instead of perl-mode)  -*- lexical-binding: t; -*-

(defalias 'perl-mode 'cperl-mode)
(setq cperl-indent-level 4)

(provide 'lang-perl)
;;; perl.el ends here
