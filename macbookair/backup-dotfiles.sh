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
		print_success "Copied $FILEPATH";
	else
		print_fail "Failed to copy $FILEPATH to $DESTPATH"
	fi;
done


git add -A
retval=$?
if [ "$retval" -eq "0" ]; then
	print_success "Added all files to git";
else
	print_fail "Failed to add files to git. Aborting!"
	exit 1
fi;

git -C $WORKTREE commit -m "$(date) Additions from ./backup-dotfiles.sh"
if [ "$retval" -eq "0" ]; then
	print_success "Committed additions to Git";
else
	print_fail "Failed to commit to git. Aborting!"
	exit 1
fi;

git push
retval=$?
if [ "$retval" -eq "0" ]; then
	print_success "Pushed to GitHub: https://github.com/njoubert/dotfiles/tree/master/macbookair";
else
	print_fail "Failed to push to GitHub. Aborting!"
	exit 1
fi;


