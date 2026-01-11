# iperf3 Service Setup Plan

## Overview
Set up iperf3 to run automatically as a systemd service on Ubuntu 22.04.

## Steps

### 1. Install iperf3
```bash
sudo apt update
sudo apt install -y iperf3
```

### 2. Create systemd service file
Create `/etc/systemd/system/iperf3.service`:

```ini
[Unit]
Description=iperf3 server
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/iperf3 -s
Restart=on-failure
RestartSec=5s
User=nobody
Group=nogroup

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=iperf3

[Install]
WantedBy=multi-user.target
```

### 3. Configure log rotation and limits
Create `/etc/systemd/journald.conf.d/iperf3.conf`:

```ini
[Journal]
# Store logs persistently
Storage=persistent

# Keep logs from the last 30 days
MaxRetentionSec=30d

# Limit total journal size to 500MB
SystemMaxUse=500M

# Keep at least 100MB free
SystemKeepFree=100M

# Individual log file size limit
SystemMaxFileSize=50M
```

Apply journald configuration:
```bash
sudo systemctl restart systemd-journald
```

### 4. Enable and start the service
```bash
sudo systemctl daemon-reload
sudo systemctl enable iperf3
sudo systemctl start iperf3
```

### 5. Verify service status
```bash
sudo systemctl status iperf3
```

### 6. Test the server
From another machine:
```bash
iperf3 -c <server-ip>
```

### 7. Firewall configuration (if needed)
```bash
sudo ufw allow 5201/tcp
sudo ufw allow 5201/udp
```

## Notes
- Default port: 5201 (TCP/UDP)
- Running as `nobody` user for security
- Service auto-restarts on failure

## Log Management Commands
- View real-time logs: `sudo journalctl -u iperf3 -f`
- View last 100 lines: `sudo journalctl -u iperf3 -n 100`
- View logs since boot: `sudo journalctl -u iperf3 -b`
- View logs for specific date: `sudo journalctl -u iperf3 --since "2026-01-09" --until "2026-01-10"`
- Check disk usage: `sudo journalctl --disk-usage`
- Verify log rotation: `sudo journalctl --verify`
- Manually vacuum old logs: `sudo journalctl --vacuum-time=7d` or `sudo journalctl --vacuum-size=100M`
