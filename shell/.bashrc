#
# ~/.bashrc
#
[[ $- != *i* ]] && return
#----------------------------------------------------------------------------------------------------------------------
#ENV
export PATH="$HOME/.local/bin:$HOME/dev/bash:$HOME/dev/bash/ezlib:$HOME/dev/bash/distrobuild:$PATH"
export QT_QPA_PLATFORMTHEME=qt6ct
export GTK_THEME=Breeze-Dark
export EDITOR=smart-edit
export VISUAL=smart-edit
export FLATPAK_USER_DIR=/data/flatpak
export NNN_OPENER=~/.config/src/opener
export NNN_TRASH=1
export NNN_COLORS='2136'
export NNN_FCOLORS='c1e2272e006033f7c6d6abc4'
export NNN_TMPFILE="${XDG_CONFIG_HOME:-$HOME/.config}/nnn/.lastd"
export NNN_PLUG='l:symlink;k:keys;t:thumbs'
export MANPAGER='less'
export GROFF_NO_SGR=1  # WYLACZA WLASNE ANSI GROFFA, ZEBY LESS_TERMCAP MIAL CO TLUMACZYC

#COLOR MANPAGES
export LESS_TERMCAP_md=$'\e[1;38;5;81m'    # BOLD / NAGLOWKI (NAME, SYNOPSIS...)
export LESS_TERMCAP_mb=$'\e[1;38;5;81m'    # BLINK
export LESS_TERMCAP_me=$'\e[0m'            # KONIEC TRYBU
export LESS_TERMCAP_us=$'\e[4;38;5;114m'   # UNDERLINE (OPCJE, ARGUMENTY)
export LESS_TERMCAP_ue=$'\e[0m'            # KONIEC UNDERLINE
export LESS_TERMCAP_so=$'\e[30;48;5;221m'  # STANDOUT (STATUS/WYSZUKIWANIE)
export LESS_TERMCAP_se=$'\e[0m'            # KONIEC STANDOUT
export LESS_TERMCAP_mr=$'\e[7m'            # REVERSE VIDEO
export LESS_TERMCAP_mh=$'\e[2m'            # HALF-BRIGHT/DIM
export LESS_TERMCAP_ZN=$'\e[74m'           # GRANICE BLOKU ANSI (START L)
export LESS_TERMCAP_ZV=$'\e[75m'           # GRANICE BLOKU ANSI (KONIEC L)
export LESS_TERMCAP_ZO=$'\e[73m'           # GRANICE BLOKU ANSI (START R)
export LESS_TERMCAP_ZW=$'\e[75m'           # GRANICE BLOKU ANSI (KONIEC R)
export LS_COLORS="di=1;38;5;81:ln=1;38;5;114:so=1;38;5;213:pi=38;5;221:ex=1;38;5;120:\
mi=1;38;5;196:or=1;38;5;196:\
bd=38;5;221;1:cd=38;5;221;1:su=38;5;196;1:sg=38;5;220;1:tw=38;5;120;1:ow=38;5;81;1:\
*.tar=1;38;5;203:*.gz=1;38;5;203:*.zip=1;38;5;203:*.7z=1;38;5;203:*.rar=1;38;5;203:\
*.jpg=38;5;213:*.jpeg=38;5;213:*.png=38;5;213:*.gif=38;5;213:*.mp4=38;5;213:*.mkv=38;5;213:\
*.mp3=38;5;114:*.flac=38;5;114:*.wav=38;5;114:\
*.pdf=38;5;221:*.md=38;5;221:*.txt=38;5;221:*.json=38;5;221:\
*.pem=1;38;5;196:*.key=1;38;5;196:*.crt=1;38;5;196:*.cer=1;38;5;196:*.p12=1;38;5;196:\
*.pfx=1;38;5;196:*.gpg=1;38;5;196:*.asc=1;38;5;196:*.env=1;38;5;196:\
*.sh=1;38;5;120:*.py=1;38;5;120:*.pl=1;38;5;120:*.rb=1;38;5;120:\
*.log=2;38;5;250:*.lock=2;38;5;250:*.bak=2;38;5;250:*.swp=2;38;5;250:*~=2;38;5;250"

#HISTORIA
HISTSIZE=-1
HISTFILESIZE=-1
HISTTIMEFORMAT='[%H.%M.%S][%d.%m.%y] '
shopt -s histappend
#----------------------------------------------------------------------------------------------------------------------
#FUNC
# CD ON QUIT
n() {
    nnn -Hdiu "$@"
    if [ -f "$NNN_TMPFILE" ]; then
        # shellcheck disable=SC1090  # nnn generuje ten plik dynamicznie w runtime
        . "$NNN_TMPFILE"
        rm -f "$NNN_TMPFILE"
    fi
}

#(FZF + MAN)
fman() {
    local sel page
    sel=$(man -k . 2>/dev/null \
        | fzf --prompt='man> ' --preview 'echo {} | cut -d" " -f1 | tr -d "," | xargs -r man 2>/dev/null | col -bx')
    [ -z "$sel" ] && return
    page=$(echo "$sel" | cut -d' ' -f1 | tr -d ',')
    man "$page"
}

#(FZF + CD) - szuka pliku, Enter = cd do lokacji gdzie on jest
fcd() {
    local file dir
    file=$(fd --type f --hidden --exclude .git \
        | fzf --ansi --prompt='cd> ' --preview 'ls -pa --color=always "$(dirname {})"')
    [ -z "$file" ] && return
    dir=$(dirname "$file")
    cd "$dir" || return
}

#----------------------------------------------------------------------------------------------------------------------
#ALIASY
alias ls='ls -p --color=auto'
alias l='ls -p --color=auto'
alias ll='ls -plh --color=auto'
alias la='ls -plah --color=auto'
alias grep='grep --color=auto'
alias ..='cd ..'
alias ...='cd ../..'
alias chomd='chmod'
alias gerp='grep --color=auto'
alias suod='sudo'

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
#----------------------------------------------------------------------------------------------------------------------
#PROMPT
PS1="\u:\w\$ "

#EXTERNAL SOURCES
# shellcheck source=/home/drbongo/.local/bin/env
. "$HOME/.local/share/../bin/env"
