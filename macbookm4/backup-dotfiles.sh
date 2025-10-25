#!/bin/bash
#
# Silly little script to copy over dotfiles into this directory.
#

. /Users/njoubert/Code/dotfiles/color.sh  # Importing color printing

###
### Config
###

# Files to Copy
HOMEDIR="/Users/njoubert/"
DESTDIR="/Users/njoubert/Code/dotfiles/macbookm4/dotfiles/"
WORKTREE="/Users/njoubert/Code/dotfiles/"
GITDIR="/Users/njoubert/Code/dotfiles/.git/"

declare -a DOTFILES=(".vimrc"
	".zshrc"
	".p10k.zsh"
	".gitconfig"
	".vimrc"
	)

###
### Functions
###

assert_with_msg() {
	if [ "$1" -eq "0" ]; then
		print_success "$2";
	else
		print_fail "$3..Aborting!";
		exit 1;
	fi;
}

info_with_msg() {
	print_pass "$1";
}

###
### Now the actual copying
###

changed_files=0  # Flag to track if any files have changes

for f in "${DOTFILES[@]}"
do
	FILEPATH="$HOMEDIR$f"
	DESTPATH="$DESTDIR${f#"."}"

	# Check if file exists in destination and if it's different
	if [ -f "$DESTPATH" ] && diff -q "$FILEPATH" "$DESTPATH" > /dev/null; then
		info_with_msg "No changes to $FILEPATH"
	else
		cp "$FILEPATH" "$DESTPATH"
		assert_with_msg $? "Copied $FILEPATH" "Failed to copy $FILEPATH to $DESTPATH"
		changed_files=1  # Mark that at least one file has changed
	fi
done

# Run Git commands only if at least one file has changed
if [ "$changed_files" -eq 1 ]; then
	git -C "$WORKTREE" add -A
	assert_with_msg $? "Added all files to git." "Failed to add files to git."

	git -C "$WORKTREE" commit -m "$(date) Additions from ./backup-dotfiles.sh"
	assert_with_msg $? "Committed additions to git." "Failed to commit to git."

	git -C "$WORKTREE" push
	assert_with_msg $? "Pushed to GitHub: https://github.com/njoubert/dotfiles/tree/master/macbookm4" "Failed to push to GitHub."
else
	info_with_msg "No changes detected. Skipping Git operations."
fi