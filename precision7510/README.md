# Precision 7510 Setup

* Ubuntu 20.04.1 Install on a clean formatted drive

* Firefox Setup
	* uBlock Origin

## Dev Environment

* Created and added new keypair to github
```
ssh-keygen -t ed25519 -C "njoubert@gmail.com"
```

* Install stuff:
```
sudo apt install net-tools git vim tmux mosh
```	

* Setup symlinks for dotfiles
```

ln -s /home/njoubert/Code/dotfiles/precision7510/vimrc /home/njoubert/.vimrc
ln -s /home/njoubert/Code/dotfiles/precision7510/gitconfig /home/njoubert/.gitconfig

```


