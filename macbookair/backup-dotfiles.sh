#!/bin/bash
#
# Silly little script to copy over dotfiles into this directory.
#

. color.sh  # Importing color printing

###
### Config
###

# Files to Copy
HOMEDIR="/Users/njoubert/"
DESTDIR="/Users/njoubert/Code/dotfiles/macbookair/"
WORKTREE="/Users/njoubert/Code/dotfiles/"
GITDIR="/Users/njoubert/Code/dotfiles/.git/"

declare -a DOTFILES=(".vimrc"
	".zshrc"
	".p10k.zsh"
	)

###
### Now the actual copying
###

for f in "${DOTFILES[@]}"
do
	FILEPATH="$HOMEDIR$f"
	DESTPATH="$DESTDIR${f#"."}"
	cp "$FILEPATH" "$DESTPATH"
	retval=$?
	if [ "$retval" -eq "0" ]; then
		print_success "Copied $FILEPATH to $DESTPATH";
	else
		print_fail "Failed to copy $FILEPATH to $DESTPATH"
	fi;
done


git -C $WORKTREE commit -am "$(date) Additions from ./backup-dotfiles.sh"
git push
