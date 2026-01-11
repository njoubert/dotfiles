# iperf3 service


iperf3 is installed as a **systemctl** daemon, and uses **journald** for logging.
The `manage-iperf3.sh` script provides everything you need.

`2026-01-10`


## `manage-iperf3.sh`

**Quick start**

```bash
sudo ./manage-iperf3.sh setup    # Does everything
./manage-iperf3.sh status        # Check it's working
./manage-iperf3.sh test          # Verify with local test
```

**Key features:**

- Idempotent - safe to run multiple times
- Uses systemd for service management
- Uses journald for logging with rotation configured (30 days, 500MB max)
- Auto-configures UFW firewall if active
- Runs as nobody:nogroup for security
- Auto-restarts on failure with 5s delay
- Color-coded output matching your mac script style

