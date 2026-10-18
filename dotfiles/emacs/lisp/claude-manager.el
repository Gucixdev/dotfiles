;;; claude-manager.el --- Claude's skills, tools and tasks in one buffer  -*- lexical-binding: t; -*-
;;
;; M-x claude-manager (C-c C) opens *claude*: one list, three views, Tab and Shift-Tab switch between them.
;;   skills  his skills from claude-config (`skills ls'): priority, #tags, description
;;           RET open the SKILL.md   t filter by #tag   r what it requires, checked on this machine
;;           c validate every header   i rebuild the index   + a new skill with the standard header
;;   tools   the MCP servers Claude Code has (`claude mcp list')
;;           RET details (`claude mcp get')   + add one (`claude mcp add -s user')
;;   tasks   TODO headings of ~/org/claude.org; it sits in `org-directory', so his agenda shows them too
;;           RET go there   + capture a new one   t next state
;; g refreshes, j/k move, q quits. A refresh asks the commands again; nothing is cached, so the list is what they say now.

(require 'cl-lib)
(require 'tabulated-list)
(require 'org)
(require 'subr-x)

(defvar org-capture-templates)   ; special, so the let in `claude-manager-capture-task' reaches org-capture
(declare-function evil-set-initial-state "evil-core")

(defgroup claude-manager nil "Claude's skills, tools and tasks." :group 'tools)

(defcustom claude-manager-skills-command
  (or (executable-find "skills") (expand-file-name "~/dev/claude-config/bin/skills"))
  "The skills tool of claude-config (bin/skills)."
  :type 'file)

(defcustom claude-manager-tasks-file (expand-file-name "claude.org" (or (bound-and-true-p org-directory) "~/org"))
  "Org file with Claude's tasks."
  :type 'file)

(defconst claude-manager--views '(skills tools tasks))
(defvar-local claude-manager--view 'skills)
(defvar-local claude-manager--tag nil "Skills view: only the skills carrying this #tag.")

;;; Data - every view is rows from a command or a file, nothing kept between refreshes

(defun claude-manager--run (program &rest args)
  "Lines PROGRAM ARGS prints on stdout."
  (unless (or (executable-find program) (file-executable-p program))
    (user-error "%s is not installed (or set `claude-manager-skills-command')" program))
  (with-temp-buffer
    (apply #'call-process program nil (list t nil) nil args)
    (split-string (buffer-string) "\n" t)))

(defun claude-manager--skills ()
  (mapcar (lambda (line)
            (let ((f (split-string line "\t")))
              (list (nth 0 f) (vector (or (nth 1 f) "") (nth 0 f) (or (nth 2 f) "") (or (nth 3 f) "")))))
          (apply #'claude-manager--run claude-manager-skills-command "ls" (and claude-manager--tag (list claude-manager--tag)))))

(defun claude-manager--tools ()
  (delq nil (mapcar (lambda (line)
                      (when (string-match "\\`\\([^: ]+\\): \\(.*\\) - \\(.*\\)\\'" line)
                        (let ((name (match-string 1 line)))
                          (list name (vector name (match-string 3 line) (string-trim (match-string 2 line)))))))
                    (claude-manager--run "claude" "mcp" "list"))))

(defun claude-manager--ensure-tasks-file ()
  (unless (file-exists-p claude-manager-tasks-file)
    (make-directory (file-name-directory claude-manager-tasks-file) t)
    (with-temp-file claude-manager-tasks-file (insert "#+title: claude\n\n* Tasks\n"))))

(defun claude-manager--tasks ()
  (claude-manager--ensure-tasks-file)
  (with-current-buffer (find-file-noselect claude-manager-tasks-file)
    (org-map-entries
     (lambda ()
       (list (point-marker)
             (vector (substring-no-properties (or (org-get-todo-state) ""))
                     (if (looking-at ".*?\\[#\\([A-Z0-9]\\)\\]") (match-string-no-properties 1) "")   ; only a cookie he set
                     (substring-no-properties (org-get-heading t t t t))
                     (substring-no-properties (string-join (org-get-tags nil t) " ")))))
     "TODO={.+}" 'file)))

(defun claude-manager--refresh ()
  (pcase claude-manager--view
    ('skills (setq tabulated-list-format [("P" 2 t) ("Skill" 24 t) ("Tags" 36 nil) ("Description" 0 nil)]
                   tabulated-list-entries (claude-manager--skills)))
    ('tools (setq tabulated-list-format [("Server" 20 t) ("Status" 16 t) ("Command or URL" 0 nil)]
                  tabulated-list-entries (claude-manager--tools)))
    ('tasks (setq tabulated-list-format [("State" 12 t) ("P" 2 t) ("Task" 60 t) ("Tags" 0 nil)]
                  tabulated-list-entries (claude-manager--tasks))))
  (setq mode-name (concat "claude:" (symbol-name claude-manager--view)
                          (if (and (eq claude-manager--view 'skills) claude-manager--tag) (concat " " claude-manager--tag) "")))
  (tabulated-list-init-header))

(defun claude-manager--hint ()
  (message "%s" (pcase claude-manager--view
                  ('skills "RET open  t #tag  r requires  c check  i index  + new  TAB view  g refresh  q quit")
                  ('tools "RET details  + add  TAB view  g refresh  q quit")
                  ('tasks "RET go to  t next state  + new  TAB view  g refresh  q quit"))))

(defun claude-manager--show (title program &rest args)
  "Run PROGRAM ARGS and show everything it printed in *claude: TITLE*."
  (let ((buf (get-buffer-create (format "*claude: %s*" title))))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (apply #'call-process program nil t nil args))
      (goto-char (point-min))
      (special-mode))
    (display-buffer buf)))

;;; Commands

(defun claude-manager ()
  "Claude's skills, tools and tasks in one buffer."
  (interactive)
  (let ((buf (get-buffer-create "*claude*")))
    (with-current-buffer buf
      (unless (derived-mode-p 'claude-manager-mode) (claude-manager-mode))
      (claude-manager--refresh)
      (tabulated-list-print t))
    (pop-to-buffer-same-window buf)
    (claude-manager--hint)))

(defun claude-manager-next-view (&optional n)
  "Switch to the next view (N views on; negative goes back)."
  (interactive "p")
  (let ((i (cl-position claude-manager--view claude-manager--views)))
    (setq claude-manager--view (nth (mod (+ i (or n 1)) (length claude-manager--views)) claude-manager--views)))
  (claude-manager--refresh)
  (tabulated-list-print)
  (goto-char (point-min))
  (claude-manager--hint))

(defun claude-manager-previous-view ()
  "Switch to the previous view."
  (interactive)
  (claude-manager-next-view -1))

(defun claude-manager--id ()
  (or (tabulated-list-get-id) (user-error "No row here")))

(defun claude-manager-open ()
  "Skills: open the SKILL.md. Tools: show the server. Tasks: go to the heading."
  (interactive)
  (let ((id (claude-manager--id)))
    (pcase claude-manager--view
      ('skills (find-file (car (claude-manager--run claude-manager-skills-command "path" id))))
      ('tools (claude-manager--show id "claude" "mcp" "get" id))
      ('tasks (org-goto-marker-or-bmk id)))))

(defun claude-manager-tag-or-state ()
  "Skills: only those with a #tag (empty: all). Tasks: next TODO state."
  (interactive)
  (pcase claude-manager--view
    ('skills
     (let ((tag (completing-read "Only #tag (empty: all): "
                                 (mapcar (lambda (l) (car (split-string l "\t")))
                                         (claude-manager--run claude-manager-skills-command "tags")))))
       (setq claude-manager--tag (unless (string-empty-p tag) tag))
       (claude-manager--refresh)
       (tabulated-list-print)))
    ('tasks
     (let ((m (claude-manager--id)))
       (org-with-point-at m (org-todo) (save-buffer))
       (claude-manager--refresh)
       (tabulated-list-print t)))
    (_ (user-error "Nothing to filter in this view"))))

(defun claude-manager--skills-only ()
  (unless (eq claude-manager--view 'skills) (user-error "Only in the skills view")))

(defun claude-manager-requires ()
  "What the skill at point requires, checked on this machine (`skills req')."
  (interactive)
  (claude-manager--skills-only)
  (let ((id (claude-manager--id)))
    (claude-manager--show (concat "req " id) claude-manager-skills-command "req" id)))

(defun claude-manager-check ()
  "Validate every skill header and the index (`skills check')."
  (interactive)
  (claude-manager--skills-only)
  (claude-manager--show "check" claude-manager-skills-command "check"))

(defun claude-manager-index ()
  "Rebuild the map of skills in the claude skill (`skills index')."
  (interactive)
  (claude-manager--skills-only)
  (claude-manager--show "index" claude-manager-skills-command "index"))

(defun claude-manager-new-skill (name)
  "Start skill NAME from the standard header, next to the others."
  (interactive "sNew skill (kebab-case): ")
  (unless (string-match-p "\\`[a-z0-9]+\\(-[a-z0-9]+\\)*\\'" name)
    (user-error "Kebab-case, like bash-everything"))
  (let* ((map (car (claude-manager--run claude-manager-skills-command "path" "claude")))
         (dir (expand-file-name name (file-name-directory (directory-file-name (file-name-directory map)))))
         (file (expand-file-name "SKILL.md" dir)))
    (when (file-exists-p file) (user-error "%s exists already" name))
    (make-directory dir t)
    (find-file file)
    (insert (format "---\nname: %s\ndescription: What it does and when to use it, on one line.\nmetadata:\n  priority: \"2\"\n  tags: \"#\"\n  requires: \"\"\n---\n\n# %s\n\n" name name))
    (message "Fill in description, tags and requires; then i rebuilds the index and c checks it")))

(defun claude-manager-add-tool (name target)
  "Give Claude Code an MCP server NAME: a command line, or an http(s) URL."
  (interactive "sServer name: \nsCommand line or URL: ")
  (if (string-match-p "\\`https?://" target)
      (claude-manager--show (concat "add " name) "claude" "mcp" "add" "-s" "user" "-t" "http" name target)
    (apply #'claude-manager--show (concat "add " name) "claude" "mcp" "add" "-s" "user" name "--"
           (split-string-and-unquote target))))

(defun claude-manager-capture-task ()
  "Capture a new TODO into `claude-manager-tasks-file'."
  (interactive)
  (claude-manager--ensure-tasks-file)
  (let ((org-capture-templates
         (cons `("C" "claude task" entry (file+headline ,claude-manager-tasks-file "Tasks") "* TODO %?\n%U\n" :empty-lines 1)
               (bound-and-true-p org-capture-templates))))
    (org-capture nil "C")))

(defun claude-manager-add ()
  "Add a skill, a tool or a task, by the view."
  (interactive)
  (pcase claude-manager--view
    ('skills (call-interactively #'claude-manager-new-skill))
    ('tools (call-interactively #'claude-manager-add-tool))
    ('tasks (claude-manager-capture-task))))

;;; Mode

(defvar claude-manager-mode-map
  (let ((m (make-sparse-keymap)))
    (define-key m (kbd "TAB") #'claude-manager-next-view)
    (define-key m (kbd "<backtab>") #'claude-manager-previous-view)
    (define-key m (kbd "RET") #'claude-manager-open)
    (define-key m "t" #'claude-manager-tag-or-state)
    (define-key m "r" #'claude-manager-requires)
    (define-key m "c" #'claude-manager-check)
    (define-key m "i" #'claude-manager-index)
    (define-key m "+" #'claude-manager-add)
    (define-key m "j" #'next-line)
    (define-key m "k" #'previous-line)
    m)
  "Keys of `claude-manager-mode'; g, q, S and n/p come from `tabulated-list-mode'.")

(define-derived-mode claude-manager-mode tabulated-list-mode "claude"
  "Claude's skills, tools and tasks.\n\n\\{claude-manager-mode-map}"
  (setq tabulated-list-padding 1)
  (add-hook 'tabulated-list-revert-hook #'claude-manager--refresh nil t))

;; evil would take t, r, c, i as its own keys; this list has its own (j/k move)
(with-eval-after-load 'evil
  (evil-set-initial-state 'claude-manager-mode 'emacs))

(global-set-key (kbd "C-c C") #'claude-manager)

(provide 'claude-manager)
;;; claude-manager.el ends here
