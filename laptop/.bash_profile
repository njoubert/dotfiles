#
# Tridge's Git Terminal Extention
#

function parse_git_branch {
  /usr/bin/git branch --no-color 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/(\1)/'
}

function proml {
  local      NORMAL="\[\033[0;0m\]"
  local        BLUE="\[\033[0;34m\]"
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
\u@\h:\w$BLUE\$(parse_git_branch)$NORMAL\\$ "
PS2='> '
PS4='+ '
}
proml

# Added by Canopy installer on 2017-05-02
# VIRTUAL_ENV_DISABLE_PROMPT can be set to '' to make the bash prompt show that Canopy is active, otherwise 1
alias activate_canopy="source '/Users/njoubert/Library/Enthought/Canopy_64bit/User/bin/activate'"
VIRTUAL_ENV_DISABLE_PROMPT=1 source '/Users/njoubert/Library/Enthought/Canopy_64bit/User/bin/activate'


#
# Added by Haskell Stack
#
export PATH="/Users/njoubert/.local/bin:$PATH"

#
# Added for GDAL (FlightWave)
#
export GDAL_DATA=/usr/local/Cellar/gdal/1.11.5_2/share/gdal