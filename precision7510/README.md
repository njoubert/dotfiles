# Precision 7510 Setup

## Laptop Details

```
Dell Precision 7510
Processor:
Memory:
Graphics:
SDD:
Serial Number:
```

## OS and Basics

Ubuntu 20.04.1 Install on a clean formatted drive

Firefox Setup
uBlock Origin

## Dev Environment

* Created and added new keypair to github
```
ssh-keygen -t ed25519 -C "njoubert@gmail.com"
```

* Install stuff:
```
sudo apt install net-tools git vim tmux mosh wget curl zsh
```	

* Make ZSH the default shell
```chsh -s $(which zsh)```

Setup oh-my-zsh
https://www.tecmint.com/install-oh-my-zsh-in-ubuntu/

* Setup symlinks for dotfiles
```
ln -s /home/njoubert/Code/dotfiles/precision7510/vimrc /home/njoubert/.vimrc
ln -s /home/njoubert/Code/dotfiles/precision7510/gitconfig /home/njoubert/.gitconfig
ln -s /home/njoubert/Code/dotfiles/precision7510/bashrc /home/njoubert/.bashrc
ln -s /home/njoubert/Code/dotfiles/precision7510/zshrc /home/njoubert/.zshrc

```

Menlo for Powerline Fonts
https://github.com/abertsch/Menlo-for-Powerline

