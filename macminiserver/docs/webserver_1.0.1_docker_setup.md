# Mac Mini Webserver - Docker Setup

## Overview

Docker Desktop is configured on the Mac Mini to run containerized applications (WordPress, Go APIs, etc.) with automatic startup on boot. This document describes the complete setup that was implemented.

**Status:** ✅ **COMPLETE** - Tested and verified after reboot on October 27, 2025

## Why Docker Desktop (Not Homebrew Docker)?

**Docker Desktop** was chosen because:
- Uses Apple's native **Virtualization.framework** for better performance
- Provides much better integration with macOS
- Official Docker product with full feature support
- Automatic updates and maintenance

**Homebrew's docker package** was avoided because:
- Uses older virtualization technology
- Not suitable for production use
- Limited macOS integration

## Architecture

### Startup Sequence

```
Power On
    ↓
macOS Boot
    ↓
LaunchDaemon starts nginx (no login required) ← Static sites work immediately
    ↓
Auto-Login to user account
    ↓
Docker Desktop starts automatically ← Dynamic sites/containers start here
```

**Key Design:**
- ✅ **nginx (static sites)** - Starts at boot via LaunchDaemon - **no login required**
- ✅ **Docker containers (dynamic apps)** - Start after auto-login - **requires login**
- ✅ **Fallback:** If auto-login fails, static sites still work
- ✅ **Best of both worlds:** Reliability + full Docker functionality

## Setup Steps

### 1. Install Docker Desktop

Docker Desktop must be installed manually from the official Docker website:

```bash
# Download from: https://www.docker.com/products/docker-desktop

# Or install via Homebrew Cask:
brew install --cask docker

# Launch Docker Desktop
open -a Docker
```

**Verify Installation:**
```bash
# Check Docker is running
docker --version

# Check for Docker Desktop context
docker context ls
# Should show "desktop-linux" context

# Test with hello-world
docker run hello-world
```

### 2. Configure Auto-Login (Required for Docker)

**Why:** Docker Desktop for Mac only starts when a user is logged in. To ensure Docker containers start automatically after reboot, auto-login must be enabled.

**Security Note:** This is standard practice for home servers. Physical security is provided by your home. The server is behind your firewall and not directly exposed to the internet.

#### Option A: Via System Settings (GUI)

1. Open System Settings:
   ```bash
   open "x-apple.systempreferences:com.apple.preferences.users"
   ```

2. Enable Automatic Login:
   - Click the ⓘ button next to your username
   - Enable "Automatically log in as this user"
   - Enter your password when prompted
   - Close System Settings

#### Option B: Via Command Line

```bash
# Enable auto-login for current user
sudo defaults write /Library/Preferences/com.apple.loginwindow autoLoginUser "$(whoami)"

# Verify the setting
sudo defaults read /Library/Preferences/com.apple.loginwindow autoLoginUser
# Should show your username
```

### 3. Configure Docker Desktop to Start at Login

1. Open Docker Desktop:
   ```bash
   open -a Docker
   ```

2. Configure startup settings:
   - Click Settings (gear icon)
   - Go to **General** tab
   - Check ✅ **"Start Docker Desktop when you log in"**
   - Click **"Apply & Restart"**

### 4. Verification

#### Test Auto-Login and Docker Startup

```bash
# Reboot the Mac Mini
sudo reboot

# After reboot, the Mac should:
# 1. Auto-login to your account
# 2. Start Docker Desktop automatically (takes 30-60 seconds)
# 3. nginx already running (started via LaunchDaemon before login)
```

#### Verify After Reboot

```bash
# SSH into the Mac Mini after reboot

# Check Docker is running (wait 30-60 seconds after login)
docker ps
# Should show Docker is running

# Check Docker context
docker context ls | grep desktop-linux
# Should show active context

# Check Docker Desktop status
ps aux | grep -i docker
# Should show multiple Docker processes
```

## Usage

### Basic Docker Commands

```bash
# List running containers
docker ps

# List all containers (including stopped)
docker ps -a

# View Docker images
docker images

# Check Docker disk usage
docker system df

# Clean up unused resources
docker system prune
```

### Running Containers

Containers are typically managed via docker-compose in individual site directories:

```bash
# Example: WordPress site
cd ~/webserver/sites/example.com/
docker-compose up -d

# Check logs
docker-compose logs -f

# Stop containers
docker-compose down
```

## Troubleshooting

### Docker Not Starting After Reboot

1. **Check auto-login is enabled:**
   ```bash
   sudo defaults read /Library/Preferences/com.apple.loginwindow autoLoginUser
   ```

2. **Verify Docker Desktop startup setting:**
   - Open Docker Desktop
   - Settings → General
   - Ensure "Start Docker Desktop when you log in" is checked

3. **Check Docker process:**
   ```bash
   ps aux | grep -i docker
   ```

4. **Manually start Docker Desktop:**
   ```bash
   open -a Docker
   ```

### Docker Performance Issues

```bash
# Check resource usage
docker stats

# Check allocated resources in Docker Desktop:
# Settings → Resources
# - CPUs: Adjust based on workload
# - Memory: Adjust based on container needs
# - Disk: Ensure sufficient space
```

### Container Issues

```bash
# View container logs
docker logs <container_name>

# Restart a container
docker restart <container_name>

# Remove a problematic container
docker rm -f <container_name>

# Rebuild and restart
docker-compose up -d --build
```

## Directory Structure

Docker containers and their configurations live within site directories:

```
~/webserver/sites/
├── example-wordpress.com/
│   ├── docker-compose.yml      # Container orchestration
│   ├── .env                    # Environment variables (gitignored)
│   ├── wp-content/             # WordPress files (volume mount)
│   └── README.md
│
└── example-api.com/
    ├── docker-compose.yml
    ├── Dockerfile
    ├── .env
    └── src/                    # Application code
```

## Security Considerations

### Auto-Login Security

**Acceptable for:**
- ✅ Home servers with physical security
- ✅ Machines in locked locations
- ✅ Servers behind firewalls

**NOT recommended for:**
- ❌ Laptops or portable devices
- ❌ Machines in shared or public spaces
- ❌ Devices that leave secure locations

### Docker Security

1. **Network Isolation:** Containers run in isolated Docker networks
2. **Volume Permissions:** Mounted volumes respect host filesystem permissions
3. **Resource Limits:** Set CPU/memory limits in docker-compose.yml
4. **Updates:** Keep Docker Desktop updated for security patches

## Maintenance

### Regular Maintenance Tasks

```bash
# Update Docker Desktop
# (Done automatically via GUI update prompts)

# Clean up old images and containers (weekly)
docker system prune -a --volumes

# Check disk usage
docker system df

# Update container images
cd ~/webserver/sites/example.com/
docker-compose pull
docker-compose up -d
```

### Backup Considerations

**What to backup:**
- Docker compose files (`docker-compose.yml`)
- Environment files (`.env`)
- Volume data directories (e.g., `wp-content/`)

**What NOT to backup:**
- Docker images (can be rebuilt)
- Container filesystem (ephemeral)

## Summary

✅ **Docker Desktop installed and configured**  
✅ **Auto-login enabled for automatic Docker startup**  
✅ **Docker Desktop starts automatically on login**  
✅ **Verified working after reboot**  
✅ **nginx starts before login, Docker after login**  

This setup provides:
- Reliable static site hosting (nginx starts at boot, no login needed)
- Full Docker functionality for dynamic applications
- Automatic recovery after power failures or reboots
- Isolation between different projects and applications