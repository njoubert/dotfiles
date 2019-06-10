# Mac Mini Personal Server

## INSTALLATION

### dotfiles symlinks

**Bash**
```bash
ln -s /Users/njoubert/Code/dotfiles/macmini/bash_profile /Users/njoubert/.bash_profile
ln -s /Users/njoubert/Code/dotfiles/macmini/bashrc /Users/njoubert/.bashrc
```

** Git**
```bash
ln -s /Users/njoubert/Code/dotfiles/macmini/gitconfig /Users/njoubert/.gitconfig
ln -s /Users/njoubert/Code/dotfiles/swift/gitignore_global /Users/njoubert/.gitignore_global
```

**General Config**
```bash
ln -s /Users/njoubert/Code/dotfiles/macmini/config /Users/njoubert/.config
```

**Python**
```bash
ln -s /Users/njoubert/Code/dotfiles/macmini/jupyter /Users/njoubert/.jupyter
ln -s /Users/njoubert/Code/dotfiles/macmini/ipython /Users/njoubert/.ipython
ln -s /Users/njoubert/Code/dotfiles/macmini/matplotlib /Users/njoubert/.matplotlib
```

**tmux**
```bash
ln -s /Users/njoubert/Code/dotfiles/tmux /Users/njoubert/.tmux
ln -s /Users/njoubert/Code/dotfiles/tmux.conf /Users/njoubert/.tmux.conf
```

### public/private keys

* Setup SSH Keys 
    * https://help.github.com/en/articles/connecting-to-github-with-ssh
* Install keys in Github
* Install keys in my private servers

## Mac Defaults

* App Store: Enable Automatic Updates
* Screen: Enable Night Shift
* Keyboard: Fast key repeat
* Mouse: Uncheck natural scrolling direction
* Remove all the unnecessary dock icons
* Finder: 
    * Show status bar
    * Change Sidebar
* Terminal:
    * Set Novel as default theme
* Sharing
    * Change name
    * Enable Screen Sharing
    * Enable File Sharing
    * Enable Remote Login
    * Access only to Niels Joubert user
* Firewall
    * Enable Firewall
* Energy Saver
    * Enable “Start up automatically after a power failure”
* Printer
    * Add my home printer
* Software Update
    * Check “Install macOS updates”
* Users
    * Disable Guest Account
* Network
    * Setup custom DNS (see below)
* Spotlight
    * Turn off Command-Space Keyboard Shortcut (We will be using Quicksilver)

### Custom DNS
```
1.1.1.1         # Cloudflare
208.67.222.222  # OpenDNS
8.8.8.8         # Google
1.0.0.1         # Cloudflare
208.67.220.220  # OpenDNS
8.8.4.4         # Google
```


## General Software

*Can use Home-brew Cask!*

* Quicksilver
    * https://qsapp.com/download.php
    * Setup Keyboard Shortcut as Command-Spave 
* Avast Antivirus
    * https://www.avast.com/en-us/index
* VLC
    * https://www.videolan.org/vlc/download-macosx.html
* Transmission
    * https://transmissionbt.com/download/
        * Ignore unencrypted peers
        * Blocklist: https://giuliomac.wordpress.com/2014/02/19/best-blocklist-for-transmission/
        * 
* Divvy
    * https://mizage.com/divvy/
        * Setup Left and Right Shortcuts
        * 
* Private Internet Access
    * Launch at Login
    * Connect on Launch
    * Request Port Forwarding
    * VPN Killswitch: Auto
    * MACE: On
* Google Chrome
    * Login and turn on sync
    * Install LastPass Extension
        * Unclear how to separate personal and swiftnav. Going with swiftnav for now.
* iState Menus 5
* GrandPerspective

## Cloud Storage and Data Management

* Dropbox
	* Sync to external harddrive

## Communication


## Software Development

* Homebrew
    * https://brew.sh
* Xcode
    * Download through App Store
* VirtualBox
* HexFiend
    * https://ridiculousfish.com/hexfiend/

### Terminal Apps and Configuration

**tmux**

`brew install tmux`
    
### Data Science

**References**
- https://jakevdp.github.io/PythonDataScienceHandbook/
- https://nbviewer.jupyter.org/github/jakevdp/WhirlwindTourOfPython/blob/master/00-Introduction.ipynb



* Git
    * brew install git
    * Setup SSH Keys in Github
        * https://help.github.com/en/articles/connecting-to-github-with-ssh
* Sublime Text
   * Package Control https://packagecontrol.io/installation
   * GitGutter
   * `subl` https://www.sublimetext.com/docs/3/osx_command_line.html
*  Miniconda
    * https://docs.conda.io/en/latest/miniconda.html
    * Install `Miniconda3-latest-MacOSX-x86_64.sh` which is Python 3
    * It stores config in bash_profile. Rip that out and put it in bashrc
    * `conda create --name py2 python=2.7`
    * `conda create --name py3 python=3.7`
    * Update the conda config in bashrc to activate py2 environment by default
* Jupyter and datascience packages
    * Install in Python 2 environment:
        * `conda activate py2`
        * `conda install numpy pandas scipy scikit-learn scikit-image sympy pillow matplotlib seaborn jupyter notebook ipykernel line_profiler memory_profiler numexpr pandas-datareader plotly opencv tqdm basemap basemap-data-hires`
        * `ipython kernel install --user` enables this environment from jupyter notebooks
    * Install in Python 3 environment:
        * `conda activate py3`
        * `conda install numpy pandas scipy scikit-learn scikit-image sympy pillow matplotlib seaborn jupyter notebook ipykernel line_profiler memory_profiler numexpr pandas-datareader plotly opencv tqdm basemap basemap-data-hires`
        * `ipython kernel install --user` enables this environment from jupyter notebooks

[See `boilerplate.py` for default Python Imports.](https://raw.githubusercontent.com/njoubert/dotfiles/master/macmini/boilerplate.py)

### Setup Jupyter Notebook Defaults and Extentions

from https://towardsdatascience.com/set-your-jupyter-notebook-up-right-with-this-extension-24921838a332

* Setup Jupyter Notebook Extentions
    * `pip install jupyter_contrib_nbextensions && jupyter contrib nbextension install`
* Link our `nbextention-setup` to the appropriate directory
    * Find the directory with `pip show jupyter_contrib_nbextensions`
    * navigate to `jupyter_contrib_nbextensions/nbextensions`
    * Create symbolic link: `ln -s /Users/njoubert/Code/dotfiles/swift/nbextention-setup setup`
* Install extentions
    * `jupyter contrib nbextensions install`
    * **NOTE:** You need to rerun this any time you change the `nbextention-setup` files.
* Enable extentions
    * Run jupyter notebook
    * go to `nbextentions` tab
    * enable "setup" extention



## Media 

* Spotify

* Vox

* somaFM app

Youtube-dl
* brew install youtube-dl

### Media Conversion and Editing

* ffmpeg
    * `brew install ffmpeg`
    * Concerning: installs a lot of dependencies including homebrew's own Python 3.7.3 distribution.

### Plex Media Server
* Download Plex
    * Create an account
    * Point it to the default, currently empty Mac directories for music, etc
    * Try out media:
        * It does NOT pick up .iso files. 
        * Need to transcode or remux 
            * https://support.plex.tv/articles/201358273-converting-iso-video-ts-and-other-disk-image-formats/
        * Media Prep
            * https://support.plex.tv/articles/categories/media-preparation/

* Download Plex Media Player for Mac
* Download Handbrake
* Download MakeMKV
    * http://makemkv.com/download/


## Random Useful Stuff

* `brew install qrencode`
    * QR Code generation: `echo "http://njoubert.com" | qrencode -o - | open -f -a /Applications/Preview.app/`
* `brew install zbar`
    * QR Code decode: `zbarimg qrcode_file.png`

## References:

* https://medium.com/@tretuna/macbook-pro-web-developer-setup-from-clean-slate-to-dev-machine-1befd4121ba8
* https://github.com/nicolashery/mac-dev-setup
* https://hackernoon.com/personal-macos-workspace-setup-adf61869cd79
* https://www.stuartellis.name/articles/mac-setup/
* https://sourabhbajaj.com/mac-setup/SublimeText/




