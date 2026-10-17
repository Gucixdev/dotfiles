# Emacs dev modules

Loaded at the end of `emac.el` (`init.el` is a symlink to it) from `lisp/`. Each file is independent; delete its name from the list
in `emac.el` to drop it. A module that fails to load is reported in `*Messages*` and skipped.

**No LSP, on purpose** (no resident server per language, no protocol layer between editor and code; the compiler, grep and tags
are the tools). `dev-nav` describes what replaces it. Python gets none either.

| module | what | keys |
|---|---|---|
| `dev-server` | this Emacs is the `emacsclient` server, and keeps ONE window: a new-frame request (`-c` from Godot, smart-edit, nnn) opens the file as a tab in the frame already open | - |
| `dev-nav` | tags (etags) for M-., ripgrep for M-?, flymake on gcc / shellcheck / byte-compiler, company, formatting | `C-c t` TAGS, `C-c d` diagnostics, `]d` `[d`, `C-c f` format |
| `dev-compile` | compile-mode for build / check / test: a command per project or language, run from the project root; autotest | `C-c r` compile, `C-c R` again, `M-g n/p` errors, `C-c A` autotest |
| `dev-shell` | bash: shellcheck through flymake, shfmt, bats | `C-c C-b` run bats |
| `dev-lang` | C/C++ style, rust-mode + cargo, go-mode, cperl, python venv/pip, ruby + web-mode (erb, tsx), typescript-mode, nix-mode | cargo: `C-c C-c C-b/r/t/l` |
| `dev-debug` | gdb (gud, many windows) + dape (gdb DAP, Godot DAP, lldb-dap) | `C-c D d/b/c/n/s/o/r/q/e` |
| `dev-godot` | gdscript-mode, engine checker as flymake backend, run/check helpers, project.godot as project root | `C-c G r/s/c/e` |
| `dev-merge` | smerge menu, ediff in one frame, git mergetool backend | `C-c m`, `]n` `[n` |
| `dev-templates` | file templates for new files (auto-insert) + skeleton snippets | `C-c i` snippet |
| `dev-inbox` | RSS (elfeed) and mail (Gnus over IMAP, smtpmail) | `C-c n` news, `C-c e` mail |
| `claude-api` | buffer API for Claude in the shared daemon (`cemacs`) | - |
| `claude-mcp` | the same API as an MCP server for Claude Code (`bin/emacs-mcp`) | - |

The rest lives in `emac.el`: evil (+collection, +org), tab-line (`gt` `gT`), org todo (`C-c c` capture, `C-c a` agenda,
`~/org`), magit (`C-c g`), diff-hl in the margin, which-key, multiple-cursors (`C->` `C-<`, Emacs state while active),
links into Nyxt when it is installed.

## One window
Godot, smart-edit and nnn's opener can keep passing `-c`: while a graphical frame is open, the file opens there as a new tab
and the frame comes to the front (on Hyprland through `hyprctl`, which ignores an app's own focus request by default). No frame
yet: one is made. `emacsclient -t` from a terminal still gets its own terminal frame. A deliberate second window: `C-x 5 2`;
the old behaviour: `(setq my/server-one-frame nil)`.

## Compile
`C-c r` offers, in order: the project's own `compile-command` from `.dir-locals.el`; else a command picked by what the project
root holds (`build.sh`, `nob`, `Cargo.toml`, `go.mod`, `bin/rails`, `Gemfile`, `tsconfig.json`, `package.json`,
`pyproject.toml`, `project.godot`, `Makefile`); else one for the lone file (`cc -std=c89 ...`, `shellcheck -f gcc`,
`perl -wc`, `ruby -wc`, `python3`, `go vet && go run`). The prompt is editable. Godot's `at: (res://file.gd:12)` lines are
clickable errors too. `C-c A` repeats the last compile after every save under its directory.

## Templates and snippets
New file -> boilerplate inserted by extension (`.sh .bash .c .h .cpp .py .pl .go .gd .el .rs .md .org Makefile`) and by place
(`run`, `bin/NAME`, `scripts/NAME`). An existing or non-empty file is never touched. The parent directory must exist (Emacs
only runs the not-found hooks then). `C-c i` offers the snippets for the current mode; add one by pushing onto `my/snippets`.

## Mail and feeds
Feeds: edit `elfeed-feeds` in `dev-inbox.el`. Mail needs `local.el` next to `emac.el` (gitignored):

    (setq user-full-name "Name" user-mail-address "you@example.com")

and `~/.authinfo.gpg` with an IMAP and an SMTP line (Gmail: an app password). Servers default to `imap.`/`smtp.` + the
address's domain. Feed and mail data live in `~/.local/share/emacs/`, outside the repo.

## Claude
`claude-api.el` + `~/.local/bin/cemacs`: Claude works through buffer operations instead of raw file tools, in the SAME
daemon you run (one daemon, one config - evil/magit/everything). See `cemacs help`. The MCP side of it:

    claude mcp add -s user emacs -- ~/.config/emacs/bin/emacs-mcp

gives Claude Code `mcp__emacs__read`, `outline`, `grep`, `replace`, `write`, `insert`, `delete_lines`, `diff`, `buffers`,
`save`, `save_all`, `revert`, `close`, `format`, `eval`, and `show` (opens a file in your window). `bin/emacs-mcp` only moves
lines between stdin/stdout and `emacsclient`; the JSON-RPC is handled in `claude-mcp.el`. With no daemon running it starts one.

## Not installed on this machine (the config copes without them)
`bats` (`pacman -S bats`), `gdformat` (`pipx install gdtoolkit`), `nix`, `lldb`, `prettier`, `nyxt`. Each feature that needs
one says so.

## Git mergetool
    git config --global merge.tool emacs
    git config --global mergetool.emacs.cmd '~/.config/emacs/bin/git-mergetool "$LOCAL" "$REMOTE" "$BASE" "$MERGED"'
    git config --global mergetool.emacs.trustExitCode true

## Verified vs not
Verified headless (Emacs 29, packages cloned from their repos): every module loads and byte-compiles; compile guesses per project
and language; `next-error` on gcc and Godot output with font-lock off; autotest fires for saves inside the compile directory
only; mode per file type; templates; elfeed/Gnus paths; the MCP server over stdio, including Claude Code's own health check.
Verified on a real X display: three `-c` requests -> one frame with three tabs, `-t` still gets a terminal frame, the
`show` tool, tab-line colours. Earlier: smerge flow, shellcheck diagnostics, clang-based C checks via flymake, GDScript parse
errors through the engine, venv detection, dape config presence.
NOT exercised: Wayland/Hyprland focus (`hyprctl` call), an interactive ediff 3-way session, an actual dape/gdb debugging session,
evil key feel in a GUI frame, a real IMAP account, fetching the feeds.
