# Thinkpad X60 Setup and Dotfiles
 
# Installation

```bash
sudo apt-get install git tmux sublime-text mosh
```

```bash
rm -rf .bashrc
ln -s /home/njoubert/Code/dotfiles/thinkpadx60/bashrc.sh /home/njoubert/.bashrc
rm -rf /home/njoubert/.config
ln -s /home/njoubert/Code/dotfiles/thinkpadx60/config /home/njoubert/.config
ln -s /home/njoubert/Code/dotfiles/thinkpadx60/tmux /home/njoubert/.tmux
ln -s /home/njoubert/Code/dotfiles/thinkpadx60/tmux.conf /home/njoubert/.tmux.conf
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

```

# Info

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
* fish shell
	* `sudo apt-get install fish`
	* Create /usr/local/bin/fishlogin with contents
		```
		#!/bin/bash -l
		exec -l fish "$@"
		```
	* Make it executable
		```sudo chmod +x /usr/local/bin/fishlogin```
	* Add it to /etc/shells
		```echo /usr/local/bin/fishlogin | sudo tee -a /etc/shells```
	* Set it as your default shell
		```sudo usermod -s /usr/local/bin/fishlogin $USER```
	* log out and log back in
* mosh for remote shell
	* `sudo apt-get install mosh`

## Installing ROS

Must install Melodic from source to build for i386.
From http://wiki.ros.org/melodic/Installation/Source

`sudo apt-get install python-rosdep python-rosinstall-generator python-wstool python-rosinstall build-essential`

```
sudo rosdep init
rosdep update
```
Yes! see it adding Melodic distro! Let's do the desktop install without all the simulators and stuff. Seems the most prudent balance between easy to build and full-featured.

```
mkdir ~/ros_catkin_ws
cd ~/ros_catkin_ws
rosinstall_generator desktop --rosdistro melodic --deps --tar > melodic-desktop.rosinstall
wstool init -j2 src melodic-desktop.rosinstall
```
Now force a setup for ubuntu:bionic since we're on mint:
`rosdep install --from-paths src --ignore-src --rosdistro melodic -y --os ubuntu:bionic`


# User's Manual for this setup

Use the **`fish`** shell. autocomplete is amazing.


When connecting to remote servers, use **`mosh`**, it keeps connections alive!



