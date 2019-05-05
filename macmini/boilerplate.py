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
############################
# Python 2to3 Compatibility
############################
from __future__ import print_function

############################
# Python System Packages
############################
import os
import sys
import glob
import math
import cmath
import time
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

############################
# UI packages
############################
import tqdm

############################
# Data Science Packages
############################

import numpy as np
import scipy as sp
import pandas as pd
import matplotlib as mpl
import matplotlib.pyplot as plt

############################
# Jupyter Setup 
############################
### Get local variable for ipython
from IPython import get_ipython
ipython = get_ipython()

### autoreload extension
if 'autoreload' not in ipython.extension_manager.loaded:
    %load_ext autoreload
%autoreload 2

### Magic for matplotlib
%matplotlib inline

### Options for pandas
pd.options.display.max_columns = 50
pd.options.display.max_rows = 30


### Display all cell outputs
from IPython.core.interactiveshell import InteractiveShell
InteractiveShell.ast_node_interactivity = 'all'


