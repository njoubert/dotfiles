# Macbook Pro M4 Max Dotfiles

This work is based on my [Macbook Air dotfiles.](../macbookair/README.md)

## Managing Dotfiles

**🚨 Run backup-dotfiles.sh every now and then! 🚨**


![Backup Dotfiles](../macbookair/images/backup-dotfiles.gif)

Just like the Macbook Air M1, I chose not to symlink paths. Instead, the backup-dotfiles.sh script copies dotfiles from ~/ to this repository. Then I use git to manage this repository.

**To Install**: Manually copy files back to your home directory.

**Adding more files:** Edit the [`backup-dotfiles.sh`](backup-dotfiles.sh) script.



# Running Notes

## 2025-02-28

3D Modeling and Printing Software:
* Autodesk Fusion for Personal Use, on recommendation from Fergus.

## 2025-02-16 

General Apps Installed:
* Brave Browser
* 1Password
* Rectangle App
* Alfred
* iStat Menus 7
* IINA
* Grand Perspective

Developer-specific Apps Installed:
* Apple Developer Tools - simply type "git" in the command line
* XCode in the App Store
* Sublime Text 4

Developer-specific CLI Apps:
* brew
* `brew install exiftool imagemagick`

Photography-specific Apps Installed:
* Adobe Lightroom Classic, Photoshop, Lightroom
* Polarr Pro Photo editor (from the App Store)

### 1Password SSH Agent

Follow the official instructions [here](https://developer.1password.com/docs/ssh/get-started/). 
Now we can ssh to my servers and github using 1password.

### iTerm2 with my profile and colors.

![iterm2](images/iterm2.png)

I love iTerm2, but it needs some better colors and profiles.

* [Download](https://iterm2.com/downloads.html) and install as usual.
* Set as default terminal
* Load the profile from [njoubert-iterm2-profile.json](../macbookair/njoubert-iterm2-profile.json)
* Also load the vscode-iterm colors from [vscode-iterm.itermcolors](../macbookair/vscode-iterm.itermcolors)

### ZSH and co

I'm duplicating the ZSH setup from my macbook air by following [these instructions]((../macbookair/README.md)

### Sublime Text 4

First we install [sublime text 4](https://www.sublimetext.com/download)

I want the handy `subl` cli shortcut described here.
To install `subl` we update `.zshrc` with this snippet:

```bash
############## START SUBLIME TEXT #################
# 2025.02.19 NIELS
#
export PATH="/Applications/Sublime Text.app/Contents/SharedSupport/bin:$PATH"
############## END SUBLIME TEXT #################
```

### brew
