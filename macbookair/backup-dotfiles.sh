#!/bin/bash
#
# Silly little script to copy over dotfiles into this directory.
#

. /Users/njoubert/Code/dotfiles/macbookair/color.sh  # Importing color printing

###
### Config
###

# Files to Copy
HOMEDIR="/Users/njoubert/"
DESTDIR="/Users/njoubert/Code/dotfiles/macbookair/dotfiles/"
WORKTREE="/Users/njoubert/Code/dotfiles/"
GITDIR="/Users/njoubert/Code/dotfiles/.git/"

declare -a DOTFILES=(".vimrc"
	".zshrc"
	".p10k.zsh"
	".gitconfig"
	)

###
### Now the actual copying
###

assert_with_msg() {
	if [ "$1" -eq "0" ]; then
		print_success "$2";
	else
		print_fail "$3..Aborting!";
		exit;
	fi;
}

for f in "${DOTFILES[@]}"
do
	FILEPATH="$HOMEDIR$f"
	DESTPATH="$DESTDIR${f#"."}"
	cp "$FILEPATH" "$DESTPATH"
	assert_with_msg $? "Copied $FILEPATH" "Failed to copy $FILEPATH to $DESTPATH"
done

git -C $WORKTREE add -A
assert_with_msg $? "Added all files to git." "Failed to add files to git."

git -C $WORKTREE commit -m "$(date) Additions from ./backup-dotfiles.sh"
assert_with_msg $? "Committed additions to git." "Failed to commit to git."

git -C $WORKTREE push
assert_with_msg $? "Pushed to GitHub: https://github.com/njoubert/dotfiles/tree/master/macbookair" "Failed to push to GitHub."


