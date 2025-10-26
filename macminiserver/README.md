# Mac Mini as Server

This is the dotfiles folder for my old Intel Mac Mini.

```text
3.6GHz quad-core Intel Core i3, 6MB shared L3 cache
32GB of 2666MHz DDR4 SO-DIMM memory
128GB PCIe-based SSD
1 GBps ethernet
C07XKPEAJYVW
```

## Mac Mini Server Provisioning

A self-contained, idempotent provisioning script for setting up a Mac mini as a server running macOS Sequoia 15.7.

### What This Does

This script automatically configures a Mac mini for server use while maintaining the ability to use it directly with a monitor and keyboard when needed.

#### Server Configuration
- **Homebrew**: Installs and configures the package manager
- **Docker Desktop**: Sets up Docker for running containerized services (nginx, etc.)
- **Power Management**: Disables sleep for system, display, and disk; enables wake-on-LAN
- **Firewall**: Enables macOS firewall with stealth mode while allowing signed applications (HTTP/HTTPS through Docker)
- **SSH**: Enables remote login for remote administration
- **Auto Updates**: Configures automatic security updates

#### Developer Tools
- Essential CLI tools: git, wget, curl, htop, iperf3, vim
- GUI applications: Rectangle, Sublime Text, iTerm2
- Menlo for Powerline fonts with full glyph support
- Oh My Zsh with Powerlevel10k theme
- iTerm2 with custom profile pre-configured

#### System Tweaks
- Dock shows only active applications
- Screen saver disabled
- All settings preserved across script runs (idempotent)

#### Monitoring Helper
The script creates `tail_logs.sh`, an interactive log viewer for monitoring:
- System and kernel logs
- Docker container logs
- Network statistics
- Disk usage and I/O
- Process monitoring
- Firewall logs
- And more...

### Usage

```bash
# Make executable
chmod +x provision.sh

# Run the script
./provision.sh

# View logs after provisioning
./tail_logs.sh
```

The script is **fully idempotent** - run it multiple times safely. It checks for existing installations and only makes changes when needed.

### Contents

- `provision.sh` - Main provisioning script
- `njoubert-iterm2-profile.json` - Custom iTerm2 configuration
- `fonts/` - Menlo for Powerline font files
- `tail_logs.sh` - Created by provision script for log monitoring

### Transfer to Server

This directory is self-contained. Simply zip it and transfer to your Mac mini server:

```bash
cd ..
zip -r macminiserver.zip macminiserver/
scp macminiserver.zip user@macmini:/path/to/destination/
```

### After Provisioning

1. Start Docker Desktop: `open -a Docker`
2. Test Docker: `docker run hello-world`
3. Run nginx: `docker run -d -p 80:80 nginx`
4. Configure Powerlevel10k: `p10k configure` (in a new terminal)
5. Monitor system: `./tail_logs.sh`
