


# Make the dock only show active apps
defaults write com.apple.dock static-only -bool true
killall Dock

# Brew source installs
PACKAGES=(
 shellcheck
)
for pkg in "${PACKAGES[@]}"; do
  brew install "$pkg" || true
done

# Brew cask installs
CASKS=(
  iterm2 signal whatsapp visual-studio-code
)
for cask in "${CASKS[@]}"; do
  brew install --cask "$cask" || true
done