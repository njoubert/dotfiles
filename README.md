# Niels Joubert's dotfiles

check out "Github does Dotfiles!" https://dotfiles.github.io/

## Great command line tools to know:

- [mtr](https://formulae.brew.sh/formula/mtr) Like traceroute and ping all in one


## Non-dotfile-related utilities I use

- Quicksilver
- Divvy

## Installing

Manually make symbolic links from your home directory. For example:

```bash
ln -s /Users/njoubert/Code/dotfiles/swift/bash_profile .bash_profile
ln -s /Users/njoubert/Code/dotfiles/swift/bashrc .bashrc
```

## Mac Terminal Settings

I like iTerm2, with:
- Menlo for Powerline fonts, 14 pt
- the `vscode-iterm.itermcolors` in the repo

For the raw terminal, I like:

- Novel theme
- SF Mono 12pt

## My Mac Knowledge and Best Practices

### LaunchDaemons and LaunchAgents

[How to Catch and Remove Hidden LaunchDaemons and LaunchAgents on Mac](https://www.makeuseof.com/tag/hidden-launchdaemons-launchagents-mac/)

LaunchDaemons typically run as root, meaning they work regardless of whether a user is logged in or not. They cannot display information using the graphical user interface and they affect the entire system.

```
/System/Library/LaunchDaemons for native macOS processes
/Library/LaunchDaemons for installed third-party apps
```

Mac LaunchAgents start when a user logs in. Unlike daemons, they can access the user interface and display information. For example, a calendar app can monitor the user's calendar account for events and notify you when the event occurs. The lists of agents live in the following locations:


```
/Library/LaunchAgents for all user accounts
~/Library/LaunchAgents for a specific user account
/System/Library/LaunchAgents for macOS only
```

## My Bash Knowledge and Best Practices

### Important Background Info

`.bash_profile` is executed for login shells. `.bashrc` is executed for interactive non-login shells. When you login for the first time, `.bash_profile` is executed. If you open a new terminal when you're already logged in, `.bashrc` is executed. 

In general, I stick everything into `.bashrc` and point `.bash_profile` there.


Symbolic links points to a name. Hard links points to the inode of a chunk of data on a storage medium. Thus, symbolic links break when you move a file. Hard links do not. But hard links can't span filesystems.


### Aliases

Stick useful commands into `.bashrc`, for example:

```bash
alias ll="ls -lah"
```

### Special Variables and Escape Characters

Customize bash behavior with special variables.

**PS1** sets the value of the current prompt. You can use special escape strings and even call functions to customize your prompt.

### Special Bash Variables

http://tldp.org/LDP/abs/html/internalvariables.html

## Housekeeping

This repository uses [pre-commit](https://pre-commit.com/) to housekeep. 
