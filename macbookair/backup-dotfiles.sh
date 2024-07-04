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
git -C $WORKTREE commit -am "$(date) Additions from ./backup-dotfiles.sh"
if [ "$retval" -eq "0" ]; then
	print_success "Committed additions to Git";
	git push
	retvall=$?
	if [ "$retvall" -eq "0" ]; then
		print_success "Pushed to GitHub";
	else
		print_fail "Failed to push to GitHub"
	fi;

else
	print_fail "Failed to commir"
fi;


