# Niels Joubert's dotfiles

## Installing

Manually make symbolic links from your home directory. For example:

```bash
ln -s /Users/njoubert/Code/dotfiles/swift/bash_profile .bash_profile
ln -s /Users/njoubert/Code/dotfiles/swift/bashrc .bashrc
```

## Mac Terminal Settings

I like:

- Novel theme
- SF Mono 12pt

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