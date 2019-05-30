# 2019-05-29 ROS Installation on Mac

## Ubuntu 18.04 in Virtualbox

* download ubuntu 18.04 iso
* install virtualbox
* create a new VM
* load ubuntu ISO as CD drive
* install minimal ubuntu install in virtual machine
* auto-update ubuntu
* "VirtualBox > Devices > Insert Guest Additions CD image" to install virtualbox <> ubuntu link for screen resizing, etc.

* Change keyboard shortcuts
	* Change virtualbox to use Right-Command as the Host key
	* Swap the LCTL and LWIN keys:
		* Edit `/usr/share/X11/xkb/symbols/pc` and swap `key <LCTL>` and `key <LWIN> `
		* `rm -rf /var/lib/xkb/*` to clear the cache
		* reboot

### public/private keys

* Setup SSH Keys 
    * https://help.github.com/en/articles/connecting-to-github-with-ssh
* Install keys in Github
* Install keys in my private servers

## Installing supporting apps

* Sublime Text 3
	* Follow the instructions on the website. This adds sublime text to Apt package manager.
* git
	* `apt-get install git`

