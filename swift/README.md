# INSTALLING


## Bash dotfiles

```bash
ln -s /Users/njoubert/Code/dotfiles/swift/bash_profile /Users/njoubert/.bash_profile
ln -s /Users/njoubert/Code/dotfiles/swift/bashrc /Users/njoubert/.bashrc
```

## Git dotfiles

```bash
ln -s /Users/njoubert/Code/dotfiles/swift/gitconfig /Users/njoubert/.gitconfig
ln -s /Users/njoubert/Code/dotfiles/swift/gitignore_global /Users/njoubert/.gitignore_global
```

## Sublime Text 3 Packages

```bash
ln -s /Users/njoubert/Code/dotfiles/swift/SublimeTextPackagesUser/ /Users/njoubert/Library/Application\ Support/Sublime\ Text\ 3/Packages/User
```

## Python for Datascience: Using the Miniconda Distribution

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

## Setup Jupyter Notebook Defaults and Extentions

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



