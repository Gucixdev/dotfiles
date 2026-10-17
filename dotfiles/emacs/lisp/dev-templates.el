;;; dev-templates.el --- file templates and small snippets, built in (auto-insert + skeleton)  -*- lexical-binding: t; -*-
;;
;; No snippet engine, no package: Emacs already has both halves.
;;
;; FILE TEMPLATES  open a file that does not exist yet and its boilerplate is there, cursor where you start typing:
;;   *.sh *.bash, run, bin/NAME, scripts/NAME   shebang, header comment, set -eu
;;   *.c  *.h                                   includes + main / include guard
;;   *.py                                       shebang, docstring, main guard
;;   *.gd                                       extends + _ready
;;   *.el                                       header, lexical-binding, provide
;;   *.pl                                       shebang, strict, warnings
;;   *.rs  *.go  *.cpp  *.md  Makefile  *.org   small skeletons
;;   M-x my/template-insert  pastes any of them into the current buffer.
;;
;; SNIPPETS  C-c i  asks for a snippet that applies to this major mode and fills in the blanks (prompts for names):
;;   C: for if fn struct main        bash: fn case usage read-lines die       python: def class main
;;   GDScript: func signal export    elisp: defun use-package                  rust: fn match
;;   go: func iferr                  perl: sub      ruby: def                  typescript: fn
;; Add one: push a (MODES NAME . SKELETON) onto `my/snippets' - SKELETON is plain `skeleton-insert' syntax, see (info "(autotype)").

(require 'autoinsert)
(require 'skeleton)
(require 'cl-lib)

;;; File templates

(defun my/template--insert (text)
  "Insert TEXT, expanding %FILE% %BASE% %GUARD% %YEAR% and leaving point at the first @@."
  (let* ((name (file-name-nondirectory (or buffer-file-name "untitled")))
         (base (file-name-sans-extension name))
         (guard (upcase (replace-regexp-in-string "[^A-Za-z0-9]" "_" name)))
         (text (replace-regexp-in-string "%FILE%" name text t t))
         (text (replace-regexp-in-string "%BASE%" base text t t))
         (text (replace-regexp-in-string "%GUARD%" guard text t t))
         (text (replace-regexp-in-string "%YEAR%" (format-time-string "%Y") text t t))
         (start (point)))
    (insert text)
    (goto-char start)
    (if (search-forward "@@" nil t)
        (delete-region (- (point) 2) (point))
      (goto-char (point-max)))))

(defconst my/templates
  `(("bash"
     "#!/usr/bin/env bash
# %FILE% - @@
set -eu

")
    ("c"
     "#include <stdio.h>

int main(void)
{
	@@
	return 0;
}
")
    ("c-header"
     "#ifndef %GUARD%
#define %GUARD%

@@

#endif /* %GUARD% */
")
    ("python"
     "#!/usr/bin/env python3
\"\"\"@@\"\"\"


def main():
    pass


if __name__ == \"__main__\":
    main()
")
    ("gdscript"
     "extends Node


func _ready() -> void:
	@@
")
    ("elisp"
     ";;; %FILE% --- @@  -*- lexical-binding: t; -*-

(provide '%BASE%)
;;; %FILE% ends here
")
    ("rust"
     "fn main() {
    @@
}
")
    ("go"
     "package main

func main() {
	@@
}
")
    ("cpp"
     "#include <cstdio>

int main()
{
	@@
	return 0;
}
")
    ("perl"
     "#!/usr/bin/env perl
use strict;
use warnings;

@@
")
    ("markdown"
     "# %BASE%

@@
")
    ("makefile"
     ".PHONY: all clean

all:
	@@

clean:
")
    ("org"
     "#+title: %BASE%
#+date: %YEAR%

* @@
"))
  "Name -> template text. Placeholders: %FILE% %BASE% %GUARD% %YEAR%, and @@ marks where point ends up.")

(defun my/template--text (name) (cadr (assoc name my/templates)))

(defun my/template-insert (name)
  "Insert the file template NAME at point."
  (interactive (list (completing-read "Template: " (mapcar #'car my/templates) nil t)))
  (my/template--insert (my/template--text name)))

(defun my/template--for (name) (lambda () (my/template--insert (my/template--text name))))

(setq auto-insert-query nil             ; just do it, don't ask
      auto-insert-alist nil)            ; ours only
(dolist (rule `(("\\.\\(sh\\|bash\\)\\'"               . "bash")
                ("/run\\'"                              . "bash")
                ("/\\(bin\\|scripts\\)/[^./]+\\'"       . "bash")
                ("\\.c\\'"                              . "c")
                ("\\.h\\'"                              . "c-header")
                ("\\.py\\'"                             . "python")
                ("\\.gd\\'"                             . "gdscript")
                ("\\.el\\'"                             . "elisp")
                ("\\.rs\\'"                             . "rust")
                ("\\.go\\'"                             . "go")
                ("\\.\\(cpp\\|cc\\|cxx\\)\\'"           . "cpp")
                ("\\.pl\\'"                             . "perl")
                ("\\.md\\'"                             . "markdown")
                ("\\(\\`\\|/\\)[Mm]akefile\\'"          . "makefile")
                ("\\.org\\'"                            . "org")))
  (push (cons (car rule) (my/template--for (cdr rule))) auto-insert-alist))
(setq auto-insert-alist (nreverse auto-insert-alist))
(auto-insert-mode 1)

;;; Snippets

(defconst my/snippets
  '((c-mode c++-mode "for"
            ("var: " "for (int " str " = 0; " str " < " (skeleton-read "limit: ") "; " str "++) {\n" > _ "\n}" >))
    (c-mode c++-mode "if"
            ("condition: " "if (" str ") {\n" > _ "\n}" >))
    (c-mode c++-mode "fn"
            ("name: " "static " (skeleton-read "return type: ") " " str "(" (skeleton-read "args: ") ")\n{\n" > _ "\n}" >))
    (c-mode c++-mode "struct"
            ("name: " "struct " str " {\n" > _ "\n};" >))
    (c-mode c++-mode "main"
            (nil "int main(int argc, char **argv)\n{\n" > "(void)argc;\n" > "(void)argv;\n" > _ "\nreturn 0;\n" > "}" >))
    (sh-mode "fn"
             ("name: " str "() {\n" > _ "\n}" >))
    (sh-mode "case"
             ("variable: " "case \"$" str "\" in\n" > "*)\n" > _ ";;\n" > "esac" >))
    (sh-mode "usage"
             (nil "usage() {\n" > "echo \"usage: $(basename \"$0\") " _ "\" >&2\n" > "exit 2\n" > "}" >))
    (sh-mode "read-lines"
             ("file: " "while IFS= read -r line; do\n" > _ "\n" > "done < \"" str "\"" >))
    (sh-mode "die"
             (nil "die() { echo \"$0: $*\" >&2; exit 1; }"))
    (python-mode "def"
                 ("name: " "def " str "(" (skeleton-read "args: ") "):\n" > _ "pass" >))
    (python-mode "class"
                 ("name: " "class " str ":\n" > "def __init__(self):\n" > _ "pass" >))
    (python-mode "main"
                 (nil "def main():\n" > _ "pass\n\n\n" "if __name__ == \"__main__\":\n" > "main()" >))
    (gdscript-mode "func"
                   ("name: " "func " str "(" (skeleton-read "args: ") ") -> void:\n" > _ "pass" >))
    (gdscript-mode "signal"
                   ("name: " "signal " str "(" _ ")"))
    (gdscript-mode "export"
                   ("name: " "@export var " str ": " (skeleton-read "type: ") " = " _))
    (emacs-lisp-mode "defun"
                     ("name: " "(defun " str " (" (skeleton-read "args: ") ")\n" > "\"" _ "\"\n" > ")" >))
    (emacs-lisp-mode "use-package"
                     ("package: " "(use-package " str "\n" > ":config\n" > _ ")" >))
    (rust-mode "fn"
               ("name: " "fn " str "(" (skeleton-read "args: ") ") {\n" > _ "\n}" >))
    (rust-mode "match"
               ("expr: " "match " str " {\n" > "_ => {" _ "}\n" > "}" >))
    (go-mode "func"
             ("name: " "func " str "(" (skeleton-read "args: ") ") {\n" > _ "\n}" >))
    (go-mode "iferr"
             (nil "if err != nil {\n" > "return " _ "err\n" > "}" >))
    (cperl-mode perl-mode "sub"
                ("name: " "sub " str " {\n" > "my (" _ ") = @_;\n" > "}" >))
    (ruby-mode "def"
               ("name: " "def " str "\n" > _ "\nend" >))
    (typescript-mode "fn"
                     ("name: " "function " str "(" (skeleton-read "args: ") "): " (skeleton-read "returns: ") " {\n" > _
                      "\n}" >)))
  "Each entry: (MAJOR-MODE... NAME SKELETON). NAME is a string; SKELETON is `skeleton-insert' syntax.")

(defun my/snippets-for-mode ()
  (let (out)
    (dolist (s my/snippets)
      (let* ((modes (cl-remove-if-not #'symbolp (butlast (butlast s 0) 2)))
             (parts (cl-remove-if #'symbolp s))
             (name (car parts)) (skel (cadr parts)))
        (ignore modes)
        (when (and (stringp name) (apply #'derived-mode-p (cl-remove-if-not #'symbolp s)))
          (push (cons name skel) out))))
    (nreverse out)))

(defun my/snippet-insert (name)
  "Insert the snippet NAME for the current major mode."
  (interactive
   (list (completing-read "Snippet: " (mapcar #'car (my/snippets-for-mode)) nil t)))
  (let ((skel (cdr (assoc name (my/snippets-for-mode)))))
    (unless skel (user-error "no snippet %S for %s" name major-mode))
    (skeleton-insert skel)))

(global-set-key (kbd "C-c i") #'my/snippet-insert)

(provide 'dev-templates)
;;; dev-templates.el ends here
