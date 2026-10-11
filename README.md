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
| `dotfiles/dinit.d/` | a complete dinit boot tree (see below) | `/etc/dinit.d` |
| `dotfiles/.gitconfig` | git settings, identity is included from `~/.gitconfig.local` | `~/.gitconfig` |

Example:

```sh
git clone https://github.com/Gucixdev/dotfiles ~/.dotfiles
ln -s ~/.dotfiles/dotfiles/foot ~/.config/foot
ln -s ~/.dotfiles/dotfiles/bash/.bashrc ~/.bashrc
```

## Emacs

Small on purpose: evil, org and magit, no LSP. `emac.el` loads the modules in
`lisp/` one by one, and a module that fails is reported and skipped, so one broken
file cannot take startup down. Delete a name from the list in `emac.el` to drop a
module. Modules: shell (bash + shellcheck), C/Rust/Python tooling, gdb, Godot,
smerge/ediff merge, templates, an editor server. `lisp/README.md` has the details.

## Boot: dinit

`dotfiles/dinit.d/` is a dinit service tree: `boot` is the initial service, every
base service is a member of `boot.d` (so `boot` reaching STARTED means the system is
up), and `subsys/` holds equivalents for systemd units that had no dinit match. The
`systemd-units/` directory keeps the unit files for machines that still boot with systemd.

## Secrets and identity

Nothing secret is tracked. Tokens and API keys live in `~/.secrets` (mode 600),
which `.bashrc` loads; it is in `.gitignore`. Git name, e-mail and signing key come
from `~/.gitconfig.local`, which `.gitconfig` includes.

## Notes

- Qt and GTK files contain absolute paths (`/home/<user>/...`) because those
  toolkits do not expand `$HOME`; edit them for another user name.
- Tested on CachyOS (Arch based). The dinit tree targets Artix/Void style layouts.
- MIT, see `LICENSE`.
