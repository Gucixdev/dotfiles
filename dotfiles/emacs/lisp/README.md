# Emacs dev modules

Loaded at the end of `emac.el` (`init.el` is a symlink to it) from `lisp/`. Each file is independent; delete its name from the list
in `emac.el` to drop it. A module that fails to load is reported in `*Messages*` and skipped.

**No LSP, on purpose** (no resident server per language, no protocol layer between editor and code; the compiler, grep and tags
are the tools). `dev-nav` describes what replaces it. Python gets none either.

| module | what | keys |
|---|---|---|
| `dev-server` | this Emacs is the `emacsclient` server (Godot's external editor, nnn, scripts open files here) | - |
| `dev-nav` | tags (etags) for M-., ripgrep for M-?, flymake on gcc / shellcheck / byte-compiler, company, formatting | `C-c t` TAGS, `C-c d` diagnostics, `]d` `[d`, `C-c f` format |
| `dev-shell` | bash: shellcheck through flymake, shfmt, bats | `C-c C-b` run bats |
| `dev-lang` | rust-mode + cargo, python venv/pip, nix-mode | cargo: `C-c C-c C-b/r/t/l` |
| `dev-debug` | gdb (gud, many windows) + dape (gdb DAP, Godot DAP, lldb-dap) | `C-c D d/b/c/n/s/o/r/q/e` |
| `dev-godot` | gdscript-mode, engine checker as flymake backend, run/check helpers, project.godot as project root | `C-c G r/s/c/e` |
| `dev-merge` | smerge menu, ediff in one frame, git mergetool backend | `C-c m`, `]n` `[n` |
| `dev-templates` | file templates for new files (auto-insert) + skeleton snippets | `C-c i` snippet |

## Templates and snippets
New file -> boilerplate inserted by extension (`.sh .bash .c .h .py .gd .el .rs .md .org Makefile`) and by place (`run`,
`bin/NAME`, `scripts/NAME`). An existing or non-empty file is never touched. The parent directory must exist (Emacs only
runs the not-found hooks then). `C-c i` offers the snippets for the current mode; add one by pushing onto `my/snippets`.

## Claude's own Emacs
`claude-api.el` + `~/.local/bin/cemacs`: Claude works through buffer operations instead of raw file tools, in the SAME
daemon you run (one daemon, one config - evil/magit/everything). See `cemacs help`.

## Not installed on this machine (the config copes without them)
`bats` (`pacman -S bats`), `gdformat` (`pipx install gdtoolkit`), `nix`, `lldb`. Each feature that needs one says so.

## Git mergetool
    git config --global merge.tool emacs
    git config --global mergetool.emacs.cmd '~/.config/emacs/bin/git-mergetool "$LOCAL" "$REMOTE" "$BASE" "$MERGED"'
    git config --global mergetool.emacs.trustExitCode true

## Verified vs not
Verified headless: smerge flow, shellcheck diagnostics, clang-based C checks via flymake, GDScript parse errors through the
engine, venv detection, templates and snippets, dape config presence.
NOT exercised: an interactive ediff 3-way session, an actual dape/gdb debugging session, evil key feel in a GUI frame.
