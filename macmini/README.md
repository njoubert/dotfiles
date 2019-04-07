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


## General Software

*Can use Home-brew Cask!*

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
        * `conda install numpy pandas scipy scikit-learn scikit-image pillow matplotlib seaborn jupyter notebook ipykernel line_profiler memory_profiler numexpr pandas-datareader plotly`
        * `ipython kernel install --user` enables this environment from jupyter notebooks
    * Install in Python 3 environment:
        * `conda activate py3`
        * `conda install numpy pandas scipy scikit-learn scikit-image pillow matplotlib seaborn jupyter notebook ipykernel line_profiler memory_profiler numexpr pandas-datareader plotly`
        * `ipython kernel install --user` enables this environment from jupyter notebooks

Default Python Imports:
```
#!/usr/bin/env python
# -*- coding: utf-8 -*-
# Coyright (C) 2019 Niels Joubert
# Contact: Niels Joubert <njoubert@gmail.com>
#
# This source is subject to the license found in the file 'LICENSE' which must
# be be distributed together with this source. All other rights reserved.
#
# THIS CODE AND INFORMATION IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND,
# EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
"""

"""
# Python 2<>3 Compatibility
from __future__ import print_function

# Python System Packages
import os
import sys
import glob
import math
import cmath
import datetime
import re
import itertools
import functools
import random
import pickle
import json
import csv
import urllib
import requests
import argparse
print(sys.version)

# Data Science Packages
import numpy as np
import scipy as sp
import pandas as pd
import matplotlib.pyplot as plt

# Jupyter Setup
%matplotlib inline
%load_ext autoreload
%autoreload
```



## Media 

* Spotify

* Vox

* somaFM app

Youtube-dl
* brew install youtube-dl


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



## References:

* https://medium.com/@tretuna/macbook-pro-web-developer-setup-from-clean-slate-to-dev-machine-1befd4121ba8
* https://github.com/nicolashery/mac-dev-setup
* https://hackernoon.com/personal-macos-workspace-setup-adf61869cd79
* https://www.stuartellis.name/articles/mac-setup/
* https://sourabhbajaj.com/mac-setup/SublimeText/




