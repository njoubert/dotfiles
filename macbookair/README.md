# Macbook Air Setup

## Computer Details
```
* MacBook Air (M1, 2020)
* 8 core CPU, 8 core GPU
* 16 GB Ram
* 1 TB SSD
```

## 2024.07.01  Big Update 👈

After taking a new job at StackAV where I was asked to do more IC work, 
I spent time reconfiguring my terminal and vim.

### ZSH Enhancements

MacOS default shell is `zsh` so I'm going with that.

For custom prompts, there's the venerable [powershell10k](https://github.com/romkatv/powerlevel10k) and the new kid [starship.rs](https://starship.rs/). I tried both and Powerlevel10k is faster, while Starship is buggy and the documentation is often incorrect. So, P10K it is.

As for plugins, I have yet to get into [oh-my-zsh](https://ohmyz.sh/) and enable all the [fancy](https://dev.to/abdfnx/oh-my-zsh-powerlevel10k-cool-terminal-1no0) [stuff](https://www.lorenzobettini.it/2024/01/oh-my-zsh-and-powerlevel10k-in-macos/).

**See zshrc file**

### VIM Enhancements

Vim is a good quick-and-dirty text editor that I find myself using regularly on the command line.
So a little bit of tweaking to make it nice is great.

**See the vimrc file.**

### Sublime Text 4 Enhancements

I do still use and love Sublime Text for how lightweight and great it is. 
At my last 3 jobs, everyone is using Visual Studio Code and there's a lot of good stuff in there.


## 2021.08.18

* Homebrew is native on Mac M1
	* https://code2care.org/howto/install-homebrew-brew-on-m1-mac
	* `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`
* youtube-dl the manual way

## 2021.05.20

* Sublime Text 4 for M1 Mac!



## 2021.03.25

* PrivateInternetAccess (rosetta)
* Evernote (rosetta)

## 2021.03.23

Useful Website to find M1 apps.
* [isitapplesiliconready.com](https://isapplesiliconready.com/)
* [doesitarm.com](https://doesitarm.com/)


Useful fonts: 
* https://github.com/powerline/fonts
* MesloLG Nerd Font [preview](https://www.programmingfonts.org/#meslo) [download](https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/Meslo.zip)


### Applications Installed

* Brave Browser
* Google Chrome
* Loopback Audio
	* Had to Enable System Extensions. Shut down computer, power on into Startup Security Utility, enable Kernel Extensions.
	* `Name: Niels Joubert`
	* `Code: VADS-RU2E-AQNY-3HFD-FGW8-YEMU-KWHP-VGE2-XBQJ`
* Rectangle app
* iStatMenus 6
	* `Email: njoubert@gmail.com`
	* `Key: GAWAE-FCPBJ-JNK34-SA32X-G2K3Y-YZEXB-VT4G2-AM3QC-CRJX5-FHVPT-33DVC-HDQ6L-BAD3G-SKSZR-W2AA`
* Apple Developer Tools (type `git` in the command line and it pops up the installer)
* VSCode
* iTerm2
	* set colors to `vscode-iterm`
	* Install Menlo for Powerline, set font pt 14
* VLC
* Setup SSH Keys for Github
	* https://docs.github.com/en/enterprise-server@3.0/github/authenticating-to-github/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent
		

