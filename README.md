# dotfiles

My Linux desktop configuration: Hyprland on Wayland, Emacs, bash, foot, dinit and systemd
units, GTK/Qt theme and a few helper scripts. Personal and opinionated; take what is useful.

Everything lives under `dotfiles/` and is applied by symlink, there is no installer.

## Layout

| Path | What it is | Linked to |
|---|---|---|
| `dotfiles/hypr/` | Hyprland config | `~/.config/hypr` |
| `dotfiles/emacs/` | Emacs: evil, org, magit, plus `lisp/dev-*.el` modules | `~/.config/emacs` |
| `dotfiles/bash/` | `.bashrc`, `.bash_profile`, `.profile`, `.zshrc` | `~/` |
| `dotfiles/foot/` | foot terminal | `~/.config/foot` |
| `dotfiles/fastfetch/` | fastfetch | `~/.config/fastfetch` |
| `dotfiles/theme/` | GTK 3/4 and Qt5/6 (`qt5ct`, `qt6ct`) theme | `~/.config/gtk-3.0`, `gtk-4.0`, `qt5ct`, `qt6ct` |
| `dotfiles/autostart/` | one `run` script that starts the session | `~/.config/autostart` |
| `dotfiles/src/` | helper scripts: `maintanance`, `menu`, `steam-games`, `workspcswitch` | `~/.config/src` |
| `dotfiles/systemd-units/` | system and user units | `~/.config/systemd-units` |
| `dotfiles/dinit.d/` | a dinit service tree (see below) | `/etc/dinit.d` on a dinit system |
| `dotfiles/.gitconfig` | git settings, identity is included from `~/.gitconfig.local` | `~/.gitconfig` |
| `dotfiles/firefox/` | `user.js`, `chrome/` (userChrome/userContent), extensions list, bookmark export (see below) | symlinked into the profile |
| `dotfiles/flatpak/` | installed app-id list + any permission overrides (see below) | applied via `flatpak/install` |

Example:

```sh
git clone https://github.com/Gucixdev/dotfiles ~/.dotfiles
ln -s ~/.dotfiles/dotfiles/foot ~/.config/foot
ln -s ~/.dotfiles/dotfiles/bash/.bashrc ~/.bashrc
```

## Emacs

Small on purpose: evil, org and magit, and **no LSP** (the compiler, ripgrep and etags
are the tools). `emac.el` loads the modules in `lisp/` one by one; a module that fails
is reported and skipped, so one broken file cannot take startup down. Delete a name
from the list in `emac.el` to drop a module.

| module | what |
|---|---|
| `dev-nav` | etags, ripgrep, flymake on gcc / shellcheck, company |
| `dev-shell` | bash: shellcheck through flymake, shfmt, bats |
| `dev-lang` | rust-mode + cargo, python venv/pip, nix-mode |
| `dev-debug` | gdb (gud) and dape |
| `dev-godot` | gdscript-mode, engine checker as a flymake backend |
| `dev-merge` | smerge, ediff in one frame, a git mergetool backend |
| `dev-templates` | new-file templates and snippets |
| `dev-server` | this Emacs is the `emacsclient` server other tools open files in |

`lisp/README.md` lists the key bindings and what was and was not exercised.

## dinit

`dotfiles/dinit.d/` is a dinit service tree: `boot` is the initial service and every
base service is a member of `boot.d`, so `boot` reaching STARTED means the system is
up; `subsys/` holds equivalents for systemd units that had no dinit match. This
machine boots with systemd, so the tree is written for a dinit based system and is
not exercised here. `systemd-units/` keeps the unit files used on this machine.

## Firefox

`prefs.js` itself is not tracked — it's almost entirely runtime/session state Firefox
regenerates on its own (telemetry timestamps, session-restore bookkeeping, per-install
random ids), not deliberate choices. What's actually dotfiles-worthy instead:

- `firefox/user.js` — about:config overrides, read fresh on every launch. Symlinked
  straight into the profile (`~/.config/mozilla/firefox/<profile>/user.js` on this
  machine; native Firefox uses `~/.mozilla/firefox/<profile>/` instead).
- `firefox/chrome/userChrome.css` / `userContent.css` — UI and internal-page styling,
  symlinked as the profile's `chrome/` dir. Needs the pref `user.js` already sets.
- `firefox/extensions.txt` — a plain list of AMO slugs to reinstall by hand; there's
  no CLI install path for add-ons, so nothing here applies it automatically.
- `firefox/export-bookmarks` — decodes Firefox's own newest `.jsonlz4` bookmark
  backup (a tiny from-scratch LZ4 block decoder, no `lz4` pip dependency for one file
  format) into a diffable `firefox/bookmarks.json`. Run by hand, not on a timer.

## Flatpak

`flatpak/apps.txt` is the installed app-id list; `flatpak/overrides/` holds any
per-app permission overrides that exist (empty right now). `flatpak/export`
refreshes both from the live system; `flatpak/install` re-installs everything listed
and re-applies the tracked overrides — meant for a fresh machine.

## Secrets and identity

Nothing secret is tracked. Tokens and API keys live in `~/.secrets` (mode 600),
which `.bashrc` loads; it is in `.gitignore`. Git name, e-mail and signing key come
from `~/.gitconfig.local`, which `.gitconfig` includes.

## Notes

- No user name in the tree: qt5ct/qt6ct expand `~` in `color_scheme_path`
  (saving from their GUI writes the full path back, so change it to `~` again
  before committing), and GTK's `gtk-3.0/bookmarks`, which takes only absolute
  `file://` URIs, is not tracked.
- Daily driver: CachyOS (Arch based) with Hyprland.
- MIT, see `LICENSE`.
