# Thinkpad X60 Setup and Dotfiles

Reviving an old Thinkpad X60 1709CTO

* Intel Core Duo processor T2400(1.83GHz) 32-bit processor
* 2 MB onboard L2 cache memory
* 1Gb Ethernet soldered on system board
* 12.1inch (1024x768 resolution) TFT display
* Intel GMA 950 - integrated graphicschipset

More specs on the [ThinkWiki](https://www.thinkwiki.org/wiki/Category:X60s)

## Hardware Upgrades

* OWC 4.0GB Kit (2X 2GB) PC2-5300 DDR2 667MHz SO-DIMM 200 Pin Memory Upgrade Kit ($27.99)
* Crucial MX500 250GB 3D NAND SATA 2.5 Inch Internal SSD - CT250MX500SSD1(Z) ($35.99)

Needs a new battery

## OS choices

Want a Ubuntu 18.04 derivative to make ROS Melodic easy

- Bodhi Linux: Enlightenment window manager. 18.04 LTS.
	- Gratuoutous animations. What the heck is this. No top shelf. 
- Lubuntu. LXDE. Officially supported Ubuntu. 18.04.02 LTS.
- Linux Lite. 18.04.02 LTS.
- Mint Linux. Cinnamon window manager. 
	- seems promising

**Window Manager Choices:**
- Enlightenment 145MB
- LXDE 266MB
- XFCE 283MB
- Cinnamon 409MB
- MATE 441MB
- Unity 788MB

### Making a bootable USB stick from an ISO image

```
hdiutil convert -format UDRW -o linuxmint-19.1-cinnamon-32bit.img linuxmint-19.1-cinnamon-32bit.iso
sudo dd if=linuxmint-19.1-cinnamon-32bit.img of=/dev/rdisk2 bs=1m
```

## Linux Mint Setup

* Git
	* `apt-get install git`
	* Add SSH Keys. Follow Github guide.
	* `mkdir -p ~/Code; cd ~/Code; git clone git@github.com:njoubert/dotfiles.git`
* sublime text
	* `sudo apt-get install sublime-text`
* tmux
	* `sudo apt-get install tmux`
	* Install tmux package manager. `git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm`
	* Edit tmux.conf (linked into dotfiles here)	
