


# Make the dock only show active apps
defaults write com.apple.dock static-only -bool true
killall Dock

# Configure DNS resolver for local domain
echo "Configuring DNS resolver for cloudsrest domain..."
sudo mkdir -p /etc/resolver
echo "nameserver 10.0.0.1" | sudo tee /etc/resolver/cloudsrest
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
echo "DNS resolver configured"

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