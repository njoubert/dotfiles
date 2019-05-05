define(['base/js/namespace', 'base/js/events'], function (Jupyter, events) {
  // Template cells including markdown and imports
  var setUp = function () {
    Jupyter.notebook.insert_cell_at_index('markdown', 0)
      .set_text(`# Introduction`)
    Jupyter.notebook.insert_cell_at_index('markdown', 1).set_text(`### Imports`)
    // Define imports and settings
    Jupyter.notebook.insert_cell_at_index('code', 2)
      .set_text(`############################
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
InteractiveShell.ast_node_interactivity = 'all'`)
    Jupyter.notebook.insert_cell_at_index('markdown', 3)
      .set_text(`# Analysis and Modeling`)
    Jupyter.notebook.insert_cell_at_index('code', 4).set_text(``)
    Jupyter.notebook.insert_cell_at_index('markdown', 5).set_text(`# Results`)
    Jupyter.notebook.insert_cell_at_index('code', 6).set_text(``)
    Jupyter.notebook.insert_cell_at_index('markdown', 7)
      .set_text(`# Conclusions and Next Steps`)
    // Run all cells
    Jupyter.notebook.execute_all_cells()
  }
  // Prompts user to enter name for notebook
  var promptName = function () {
    // Open rename notebook box if 'Untitled' in name
    if (Jupyter.notebook.notebook_name.search('Untitled') != -1) {
      document.getElementsByClassName('filename')[0].click()
    }
  }
  // Run on start
  function load_ipython_extension () {
    // Add default cells for new notebook
    if (Jupyter.notebook.get_cells().length === 1) {
      setTimeout(setUp, 500)
    } else {
      promptName()
    }
  }
  // Run when cell is executed
  events.on('execute.CodeCell', function () {
    promptName()
  })
  // Run when notebook is saved
  events.on('before_save.Notebook', function () {
    promptName()
  })
  return {
    load_ipython_extension: load_ipython_extension
  }
})
