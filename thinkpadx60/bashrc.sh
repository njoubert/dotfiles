# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples


# Put local bin directory in path
export PATH="/Users/njoubert/Code/dotfiles/bin:$PATH"

# Add Colors to Terminal
export CLICOLOR=1
export LSCOLORS=ExFxBxDxCxegedabagacad


# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=4000
HISTFILESIZE=6000

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
#shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac


# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

#
# ALIASES and QUICK COMMANDS
#

# general
alias ls='ls -GFh'
alias ll="ls -lah"

# git secific
alias g="git"
alias gd="git diff"
alias gs="git status"
alias ga="git add"
alias gc="git commit"
alias gp="git push"
alias gpf="git push --force"
alias gl="git log"

#
# Tridge's Git Terminal Extention
#
function parse_git_branch {
  /usr/bin/git branch --no-color 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/(\1)/'
}

function proml {
  local      NORMAL="\[\033[0;0m\]"
  local        BLUE="\[\033[0;34m\]"
  local  LIGHT_BLUE="\[\033[1;34m\]"
  local       BLACK="\[\033[0;30m\]"
  local         RED="\[\033[0;31m\]"
  local   LIGHT_RED="\[\033[1;31m\]"
  local       GREEN="\[\033[0;32m\]"
  local LIGHT_GREEN="\[\033[1;32m\]"
  local       WHITE="\[\033[1;37m\]"
  local  LIGHT_GRAY="\[\033[0;37m\]"
  case $TERM in
    xterm*|screen*)
    TITLEBAR='\[\033]0;\u@\h:\w\007\]'
    ;;
    *)
    TITLEBAR=""
    ;;
  esac

PS1="${TITLEBAR}\
$LIGHT_GREEN\u@\h$NORMAL:$LIGHT_BLUE\w$BLUE\$(parse_git_branch)$NORMAL\\$ "
PS2='> '
PS4='+ '
}
proml



################


### Two cases: things that happen 
### Start the things that happen on every shell open
### always {{{


### }}}
### If not running interactively, exit now

# case $- in
#     *i*) ;;
#       *) return;;
# esac

### Do the things that only happen on interactive prompts
