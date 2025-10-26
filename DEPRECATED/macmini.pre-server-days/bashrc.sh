#######################################################################
# Niels Joubert Swift Nav-specific .bashrc file
#
#   NOTE ON BASHRC VS BASH_PROFILE:
#     - I store everything in bashrc, and bash_profile loads bashrc
#     - bashrc is loaded on non-login interactive shells.
#     - bash_profile is loaded on login interactive shells.
#######################################################################


### setup global variables {{{
###  

# Check to see if a local or SSH connection and save as global variable
if [[ $(ps -o comm= -p $PPID) =~ sshd* ]]; then 
  ORIGIN="remote/sshd"
else
  ORIGIN="local"
fi

# Put local bin directory in path
export PATH="/Users/njoubert/Code/dotfiles/bin:$PATH"

# Shows in the prompt
WORKSTATION_ALIAS="macmini"

###
### setup global variables }}}

usage() {
  echo -n "$(tput bold)"
  echo "🌵🌴☠️  WELCOME NIELS ☕☕☕"
  echo "Useful Shortcuts:"
  echo "  ll             ls -lah"
  echo "  bg(1-6)        changes background color"
  echo "  g( |s|a|c|p)   git, status, add, commit, push"   
  echo "💥💥💥 NOW GO BUILD EPIC SHIT 🔥🔥🔥" 
  echo -n "$(tput sgr0)"
}


### background color rotation {{{ 
###

# Setting up pretty colors
declare color_pastel
color_pastel[0]="255 179 186" #red
color_pastel[1]="255 223 186" #orange
color_pastel[2]="255 255 186" #yellow
color_pastel[3]="186 255 201" #green
color_pastel[4]="186 225 255" #blue
color_pastel[5]="210 172 209" #purple
COLOR_PASTEL_COUNT=5

# Convert 8 bit r,g,b,a (0-255) to 16 bit r,g,b,a (0-65535)
# to set terminal background.
# r, g, b, a values default to 255
set_bg () {
    r=${1:-255}
    g=${2:-255}
    b=${3:-255}
    a=${4:-255}

    r=$(($r * 256 + $r))
    g=$(($g * 256 + $g))
    b=$(($b * 256 + $b))
    a=$(($a * 256 + $a))

    osascript -e "tell application \"Terminal\" to set background color of window 1 to {$r, $g, $b, $a}"
}

# Set terminal background based on hex rgba values
# r,g,b,a default to FF
set_bg_from_hex() {
    r=${1:-FF}
    g=${2:-FF}
    b=${3:-FF}
    a=${4:-FF}

    set_bg $((16#$r)) $((16#$g)) $((16#$b)) $((16#$s))
}

set_bg_from_list() {
  set_bg ${color_pastel[$1]}
}

set_bg_randomly() {
  set_bg_from_list $(( ( RANDOM % COLOR_PASTEL_COUNT )  + 1 ))
}
set_bg_sequentially() {
  COUNTERFILE=$HOME/.bash_njoubert_bg_seq
  if [ ! -f $COUNTERFILE ]; then
    echo 0 > $COUNTERFILE
  fi
  COUNTER=$(cat $COUNTERFILE)

  set_bg_from_list $COUNTER
  
  COUNTER=$(($COUNTER + 1))
  if [ $COUNTER -gt $COLOR_PASTEL_COUNT ]; then
    COUNTER=0;
  fi
  echo $COUNTER > $COUNTERFILE
}

###
### }}} background color rotation

# Show usage if this is an interactive shell, and rotate background if also local
if [[ $- == *i* ]]; then
  usage
#  if [ "$ORIGIN" == "local" ]; then
#    set_bg_sequentially
#  fi
fi

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# Add Colors to Terminal
export CLICOLOR=1
export LSCOLORS=ExFxBxDxCxegedabagacad


## aliases {{{
##

# general
alias ls='ls -GFh'
alias ll="ls -lah"
alias bg1="set_bg \${color_pastel[0]}" #red
alias bg2="set_bg \${color_pastel[1]}" #orange
alias bg3="set_bg \${color_pastel[2]}" #yellow
alias bg4="set_bg \${color_pastel[3]}" #green
alias bg5="set_bg \${color_pastel[4]}" #blue
alias bg6="set_bg \${color_pastel[5]}" #purple

# git secific
alias g="git"
alias gd="git diff"
alias gs="git status"
alias ga="git add"
alias gc="git commit"
alias gp="git push"
alias gpf="git push --force"
alias gl="git log"

##
## }}} aliases 


## Tridge's Git Prompt {{{
##
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
$LIGHT_GREEN\u@$WORKSTATION_ALIAS$NORMAL:$LIGHT_BLUE\w$BLUE\$(parse_git_branch)$NORMAL\\$ "
PS2='> '
PS4='+ '
}
proml

##
## }}} Tridge's Git Prompt

## Miniconda3 {{{ 
##
# added by Miniconda3 4.5.12 installer
# >>> conda init >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$(CONDA_REPORT_ERRORS=false '/Users/njoubert/miniconda3/bin/conda' shell.bash hook 2> /dev/null)"
if [ $? -eq 0 ]; then
    \eval "$__conda_setup"
else
    if [ -f "/Users/njoubert/miniconda3/etc/profile.d/conda.sh" ]; then
        . "/Users/njoubert/miniconda3/etc/profile.d/conda.sh"
        ## Modified by njoubert to activate py2 environment by default
        CONDA_CHANGEPS1=false conda activate py3
    else
        \export PATH="/Users/njoubert/miniconda3/bin:$PATH"
    fi
fi
unset __conda_setup
export CONDA_CHANGEPS1=false
# <<< conda init <<<
##
## }}} Miniconda3 
