#
# ~/.bashrc
#

[[ $- != *i* ]] && return

# ── PATH ──────────────────────────────────────────────────────────────────────
export PATH="$HOME/.local/bin:$HOME/dev/bash:$HOME/dev/bash/ezlib:$HOME/dev/bash/distrobuild:$PATH"

# ── Dark theme ────────────────────────────────────────────────────────────────
export QT_QPA_PLATFORMTHEME=qt6ct
export GTK_THEME=Breeze-Dark

# ── Edytor ────────────────────────────────────────────────────────────────────
export EDITOR=fresh
export VISUAL=fresh

# ── nnn ───────────────────────────────────────────────────────────────────────
export NNN_OPENER=~/.config/src/opener
export NNN_TRASH=1
export NNN_COLORS='2136'
export NNN_FCOLORS='c1e2272e006033f7c6d6abc4'
export NNN_TMPFILE="${XDG_CONFIG_HOME:-$HOME/.config}/nnn/.lastd"
export NNN_PLUG='l:symlink;k:keys'

# cd on quit — wyjdz z nnn i laduj w folderze gdzie bylys
n() {
    nnn -Hdiu "$@"
    if [ -f "$NNN_TMPFILE" ]; then
        . "$NNN_TMPFILE"
        rm -f "$NNN_TMPFILE"
    fi
}

# ── Aliasy ────────────────────────────────────────────────────────────────────
alias ls='ls --color=auto'
alias l='ls --color=auto'
alias ll='ls -lh --color=auto'
alias la='ls -lah --color=auto'
alias grep='grep --color=auto'
alias ..='cd ..'
alias ...='cd ../..'

# typo-aliasy (inspirowane bahamas10/dotfiles)
alias chomd='chmod'
alias gerp='grep --color=auto'
alias suod='sudo'

# ── Git aliasy (inspirowane bahamas10/dotfiles) ────────────────────────────────
alias ga='git add . --all'
alias gb='git branch'
alias gc='git clone'
alias gci='git commit -a'
alias gco='git checkout'
alias gd="git diff '!*lock'"
alias gdf='git diff'
alias gi='git init'
alias gl='git log'
alias gp='git push origin HEAD'
alias gr='git rev-parse --show-toplevel'
alias gs='git status'
alias gt='git tag'
alias gu='git pull'

# ── batman: kolorowe man przez bat ─────────────────────────────────────────────
export MANPAGER="sh -c 'col -bx | bat -l man -p'"
alias batman='man'

# ── Prompt (prosty, czytelny) ──────────────────────────────────────────────────
PS1='\[\e[32m\][$(date +%H.%M.%S)][$(date +%d.%m.%y)]\[\e[0m\] \[\e[34m\]\w\[\e[0m\]\$ '

# ── Historia ──────────────────────────────────────────────────────────────────
HISTSIZE=-1
HISTFILESIZE=-1
HISTTIMEFORMAT='[%H.%M.%S][%d.%m.%y] '
shopt -s histappend


# ── Fastfetch (uruchom ręcznie: `fastfetch`) ───────────────────────────────────
export FLATPAK_USER_DIR=/data/flatpak

. "$HOME/.local/share/../bin/env"
