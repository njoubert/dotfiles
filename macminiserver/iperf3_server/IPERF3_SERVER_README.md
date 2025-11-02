# Mac Mini iPerf3 Server

This configures the Mac Mini to run a persistent iperf3 server for network performance testing.

## Overview

The iperf3 server runs as a system-level LaunchDaemon with the following characteristics:

- **Service**: Runs `iperf3 -s` on default port 5201, bound to all interfaces (0.0.0.0)
- **Startup**: Automatic launch on system boot via LaunchDaemon
- **Reliability**: Auto-restart on crash/exit via KeepAlive
- **User Context**: Runs as user `njoubert` (not root)
- **Logging**: Rotates logs automatically, 7-day retention
- **Log Location**: `/var/log/iperf3/iperf3-server.log`

## Implementation Plan

### 1. Directory Structure

```text
macminiserver/iperf3_server/
├── IPERF3_SERVER_README.md           # This file
├── manage-iperf3.sh                  # Management script
└── com.njoubert.iperf3.plist         # LaunchDaemon template
```

### 2. LaunchDaemon Configuration

**File**: `/Library/LaunchDaemons/com.njoubert.iperf3.plist`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.njoubert.iperf3</string>
    
    <key>ProgramArguments</key>
    <array>
        <string>/opt/homebrew/bin/iperf3</string>
        <string>-s</string>
        <string>--port</string>
        <string>5201</string>
        <string>--bind</string>
        <string>0.0.0.0</string>
    </array>
    
    <key>UserName</key>
    <string>njoubert</string>
    
    <key>RunAtLoad</key>
    <true/>
    
    <key>KeepAlive</key>
    <true/>
    
    <key>StandardOutPath</key>
    <string>/var/log/iperf3/iperf3-server.log</string>
    
    <key>StandardErrorPath</key>
    <string>/var/log/iperf3/iperf3-server-error.log</string>
</dict>
</plist>
```

### 3. Log Rotation Configuration

**File**: `/etc/newsyslog.d/iperf3.conf`

```text
# logfilename                           [owner:group]    mode count size when  flags
/var/log/iperf3/iperf3-server.log      njoubert:staff   644  7     10000 *     GZ
/var/log/iperf3/iperf3-server-error.log njoubert:staff  644  7     10000 *     GZ
```

This rotates logs daily, keeps 7 days, compresses with gzip, max 10MB per file.

### 4. Management Script: `manage-iperf3.sh`

**Usage**: `./manage-iperf3.sh [command]`

**Commands**:

- **`provision`**: Install/update iperf3 via Homebrew
  - Checks if iperf3 is installed
  - Installs or upgrades to latest version
  - Validates installation

- **`install`**: Install the LaunchDaemon service
  - Creates log directory: `/var/log/iperf3/`
  - Pre-creates log files with proper ownership: `sudo touch /var/log/iperf3/*.log && sudo chown njoubert:staff /var/log/iperf3/*.log`
  - Sets proper permissions on log directory and files (owned by njoubert:staff, mode 755 for dir, 644 for files)
  - Copies plist to `/Library/LaunchDaemons/`
  - Sets plist ownership to root:wheel, mode 644
  - Configures log rotation via newsyslog
  - Does NOT start the service automatically

- **`start`**: Start the iperf3 service
  - Loads the LaunchDaemon: `sudo launchctl load -w /Library/LaunchDaemons/com.njoubert.iperf3.plist`
  - Verifies service is running

- **`stop`**: Stop the iperf3 service
  - Unloads the LaunchDaemon: `sudo launchctl unload /Library/LaunchDaemons/com.njoubert.iperf3.plist`
  - Verifies service has stopped

- **`restart`**: Restart the service
  - Calls `stop` then `start`

- **`status`**: Check service status
  - Shows if LaunchDaemon is loaded
  - Shows if iperf3 process is running
  - Shows listening port status: `lsof -i :5201`
  - Shows last 10 log lines

- **`uninstall`**: Remove the service
  - Stops service if running
  - Removes LaunchDaemon plist
  - Removes log rotation config
  - Optionally removes logs (prompts user)
  - Does NOT uninstall iperf3 binary

- **`logs`**: Tail the logs
  - `tail -f /var/log/iperf3/iperf3-server.log`

- **`test`**: Test the iperf3 server
  - Runs a quick client test: `iperf3 -c localhost -t 5`

### 5. Firewall Configuration

The Mac Mini firewall must allow incoming connections on port 5201:

```bash
# Allow iperf3 through the firewall
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /opt/homebrew/bin/iperf3
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp /opt/homebrew/bin/iperf3
```

Or configure manually in System Settings > Network > Firewall.

### 6. Testing from Remote Machines

Once running, test from any machine on the network:

```bash
# Basic test (10 seconds, default)
iperf3 -c macminiserver.local

# Reverse test (server sends to client)
iperf3 -c macminiserver.local -R

# UDP test with 100 Mbps target
iperf3 -c macminiserver.local -u -b 100M

# Parallel streams test
iperf3 -c macminiserver.local -P 4
```

## Quick Start

```bash
cd /Users/njoubert/Code/dotfiles/macminiserver/iperf3_server

# 1. Install iperf3
./manage-iperf3.sh provision

# 2. Install the service
sudo ./manage-iperf3.sh install

# 3. Start the service
sudo ./manage-iperf3.sh start

# 4. Check status
./manage-iperf3.sh status

# 5. Test locally
./manage-iperf3.sh test
```

## Troubleshooting

**Service won't start**:

```bash
# Check for errors in system log
log show --predicate 'process == "iperf3"' --last 5m

# Check LaunchDaemon status
sudo launchctl list | grep iperf3
```

**Can't connect from remote machine**:

```bash
# Verify iperf3 is listening
lsof -i :5201

# Test firewall
nc -zv macminiserver.local 5201
```

**Logs not rotating**:

```bash
# Check newsyslog configuration
sudo newsyslog -v -n

# Force log rotation manually
sudo newsyslog -v
```

## Integration with provision.sh

The main provisioning script (`provision.sh`) should be updated to optionally call:

```bash
cd iperf3_server && ./manage-iperf3.sh provision && sudo ./manage-iperf3.sh install && sudo ./manage-iperf3.sh start
```

