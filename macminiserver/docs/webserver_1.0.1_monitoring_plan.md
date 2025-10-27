# Mac Mini Webserver v1.0.1 - Basic Monitoring Plan

**Goal:** Add simple, low-overhead monitoring before building a full monitoring stack in v1.4.

**Time to Implement:** ~20 minutes  
**Resource Overhead:** Negligible (~1-2 MB RAM)  
**Prerequisites:** v1.0.0 complete

---

## Overview: Quick Wins for Monitoring

This document outlines **three simple monitoring options** you can implement immediately after completing v1.0.0. These provide visibility into your server's health without the complexity of a full monitoring stack (Prometheus/Grafana).

### Options Summary

| Option | Best For | Complexity | Access Method |
|--------|----------|------------|---------------|
| **1. Status Dashboard** | Visual overview | Low | Web browser |
| **2. Menu Bar App** | Always-visible status | Very Low | macOS menu bar |
| **3. Health Endpoint** | External monitoring | Very Low | API/curl |

**Recommendation:** Implement all options for comprehensive coverage with minimal effort.

**Note:** Terminal status commands are built into the `manage-all.sh` script (created in v1.0.0 Phase 4). Use `web-manage status` and `web-manage health` for quick terminal checks.

---

## Option 1: Simple Status Dashboard 🌐

**Create an HTML status page served by Caddy that auto-refreshes.**

### What You Get
- ✅ Visual overview of all services
- ✅ Container status and health
- ✅ System resource usage
- ✅ Auto-refreshes every 30 seconds
- ✅ Password protected
- ✅ No external dependencies

### Implementation

#### Step 1: Create Status Generation Script

```bash
cat > ~/webserver/scripts/generate-status.sh << 'EOF'
#!/bin/bash
# Generate simple status page

OUTPUT="/usr/local/var/www/status/index.html"
mkdir -p /usr/local/var/www/status

cat > "$OUTPUT" << 'HTML'
<!DOCTYPE html>
<html>
<head>
    <title>Mac Mini Server Status</title>
    <meta http-equiv="refresh" content="30">
    <style>
        body { 
            font-family: system-ui; 
            max-width: 1200px; 
            margin: 50px auto; 
            padding: 20px;
            background: #f5f5f5;
        }
        h1 { color: #333; }
        .status { 
            padding: 15px; 
            margin: 15px 0; 
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .healthy { 
            background: #d4edda; 
            border-left: 4px solid #28a745;
        }
        .unhealthy { 
            background: #f8d7da; 
            border-left: 4px solid #dc3545;
        }
        table { 
            width: 100%; 
            border-collapse: collapse; 
            margin: 20px 0;
            background: white;
            border-radius: 8px;
            overflow: hidden;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        th, td { 
            padding: 12px; 
            text-align: left; 
            border-bottom: 1px solid #ddd; 
        }
        th { 
            background: #f8f9fa;
            font-weight: 600;
        }
        .timestamp { 
            color: #666; 
            font-size: 0.9em;
            text-align: right;
        }
        .footer {
            text-align: center;
            margin-top: 40px;
            padding: 20px;
            color: #666;
        }
        .metric-value {
            font-weight: bold;
            color: #333;
        }
    </style>
</head>
<body>
    <h1>🖥️ Mac Mini Server Status</h1>
    <p class="timestamp">Last updated: $(date '+%Y-%m-%d %H:%M:%S %Z')</p>
HTML

# Check Caddy status
if brew services list | grep caddy | grep -q started; then
    cat >> "$OUTPUT" << 'HTML'
    <div class="status healthy">✅ <strong>Caddy</strong>: Running</div>
HTML
else
    cat >> "$OUTPUT" << 'HTML'
    <div class="status unhealthy">❌ <strong>Caddy</strong>: Stopped</div>
HTML
fi

# Docker containers table
cat >> "$OUTPUT" << 'HTML'
    <h2>Docker Containers</h2>
    <table>
        <tr>
            <th>Container</th>
            <th>Status</th>
            <th>Health</th>
        </tr>
HTML

# Get container status
if docker ps -a --format "{{.Names}}|{{.Status}}|{{.State}}" > /dev/null 2>&1; then
    docker ps -a --format "{{.Names}}|{{.Status}}|{{.State}}" | while IFS='|' read -r name status state; do
        if [ "$state" = "running" ]; then
            health_icon="✅"
            class="healthy"
        else
            health_icon="❌"
            class="unhealthy"
        fi
        
        echo "        <tr class='$class'><td>$name</td><td>$status</td><td>$health_icon</td></tr>" >> "$OUTPUT"
    done
fi

# System resources
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5 " used (" $3 " / " $2 ")"}')
UPTIME_INFO=$(uptime | sed 's/.*up //' | sed 's/, [0-9]* user.*//')

cat >> "$OUTPUT" << HTML
    </table>
    
    <h2>System Resources</h2>
    <table>
        <tr>
            <th>Metric</th>
            <th>Value</th>
        </tr>
        <tr>
            <td>Disk Usage</td>
            <td class="metric-value">$DISK_USAGE</td>
        </tr>
        <tr>
            <td>Uptime</td>
            <td class="metric-value">$UPTIME_INFO</td>
        </tr>
        <tr>
            <td>Docker Containers</td>
            <td class="metric-value">$(docker ps -q | wc -l | xargs) running / $(docker ps -aq | wc -l | xargs) total</td>
        </tr>
    </table>
    
    <div class="footer">
        <p><a href="/">← Back to Home</a> | Auto-refreshes every 30 seconds</p>
    </div>
</body>
</html>
HTML

chmod 644 "$OUTPUT"
EOF

chmod +x ~/webserver/scripts/generate-status.sh
```

#### Step 2: Generate Initial Status Page

```bash
~/webserver/scripts/generate-status.sh
```

#### Step 3: Add to Caddyfile

```bash
# Backup Caddyfile
cp /usr/local/etc/Caddyfile /usr/local/etc/Caddyfile.v1.0.1.backup

# Edit Caddyfile
sudo nano /usr/local/etc/Caddyfile
```

Add this block:

```caddy
# Status monitoring dashboard
status.njoubert.com {
    root * /usr/local/var/www/status
    file_server
    
    # Password protection (generate password hash first!)
    basicauth {
        admin JDJhJDE0JHlvdXJfaGFzaGVkX3Bhc3N3b3JkX2hlcmU
    }
    
    log {
        output file /usr/local/var/log/caddy/status.log
    }
}
```

**Generate password hash:**
```bash
caddy hash-password
# Enter your desired password when prompted
# Copy the hash and replace the value above
```

#### Step 4: Set Up Auto-Update with Cron

```bash
# Edit crontab
crontab -e

# Add this line (updates every minute):
* * * * * /Users/$(whoami)/webserver/scripts/generate-status.sh
```

#### Step 5: Reload Caddy

```bash
~/webserver/scripts/manage-caddy.sh validate
~/webserver/scripts/manage-caddy.sh reload
```

#### Step 6: Test

Visit `https://status.njoubert.com` in your browser. You should see:
- Caddy status
- All Docker containers with their health
- System resource usage
- Page auto-refreshes every 30 seconds

---

## Option 2: macOS Menu Bar App 📱

**Display server status directly in your Mac's menu bar.**

### What You Get
- ✅ Always-visible status in menu bar
- ✅ Quick access to container info
- ✅ One-click restart functionality
- ✅ Updates every 5 minutes
- ✅ Native macOS integration

### Implementation

#### Step 1: Install SwiftBar

```bash
brew install swiftbar
```

#### Step 2: Create Plugin

```bash
mkdir -p ~/Library/Application\ Support/SwiftBar

cat > ~/Library/Application\ Support/SwiftBar/webserver.5m.sh << 'EOF'
#!/bin/bash
# <bitbar.title>Webserver Status</bitbar.title>
# <bitbar.version>v1.0</bitbar.version>
# <bitbar.author>Niels Joubert</bitbar.author>
# <bitbar.desc>Shows webserver container status</bitbar.desc>
# <swiftbar.refreshOnOpen>true</swiftbar.refreshOnOpen>

# Count running containers
RUNNING=$(docker ps -q 2>/dev/null | wc -l | xargs)
TOTAL=$(docker ps -aq 2>/dev/null | wc -l | xargs)

# Caddy status
if brew services list | grep caddy | grep -q started; then
    CADDY="✅"
else
    CADDY="❌"
fi

# Menu bar display (shows in menu bar itself)
echo "$CADDY $RUNNING/$TOTAL"
echo "---"

# Dropdown menu content
echo "🌐 Webserver Status"
echo "---"
echo "Caddy: $(brew services list | grep caddy | awk '{print $2}')"
echo "---"
echo "Docker Containers:"
docker ps --format "  {{.Names}}: {{.Status}}" 2>/dev/null | head -10
echo "---"
echo "🔗 Open Dashboard | href=https://status.njoubert.com"
echo "🔄 Restart All | bash=$HOME/webserver/scripts/manage-all.sh param1=restart terminal=true refresh=true"
echo "📊 Status | bash=$HOME/webserver/scripts/manage-all.sh param1=status terminal=true"
echo "---"
echo "⚙️ Refresh | refresh=true"
EOF

chmod +x ~/Library/Application\ Support/SwiftBar/webserver.5m.sh
```

#### Step 3: Launch SwiftBar

```bash
open -a SwiftBar
```

SwiftBar will show an icon in your menu bar. The `5m` in the filename means it refreshes every 5 minutes.

**Change refresh rate:**
- `webserver.1m.sh` = every 1 minute
- `webserver.5m.sh` = every 5 minutes
- `webserver.10m.sh` = every 10 minutes

---

## Option 3: Health Check Endpoint 🏥

**JSON health endpoint for programmatic monitoring and external services.**

### What You Get
- ✅ JSON response with service status
- ✅ Machine-readable format
- ✅ Works with external monitoring services
- ✅ Can integrate with alerting tools
- ✅ Minimal overhead

### Implementation

#### Step 1: Create Health Check Script

```bash
cat > ~/webserver/scripts/health-check.sh << 'EOF'
#!/bin/bash
# Returns JSON health status

CADDY_HEALTHY=$(brew services list | grep caddy | grep -q started && echo "true" || echo "false")
CONTAINERS_RUNNING=$(docker ps -q 2>/dev/null | wc -l | xargs)
CONTAINERS_TOTAL=$(docker ps -aq 2>/dev/null | wc -l | xargs)
CONTAINERS_HEALTHY=$(docker ps --filter "health=healthy" -q 2>/dev/null | wc -l | xargs)

# Calculate overall health
if [ "$CADDY_HEALTHY" = "true" ] && [ "$CONTAINERS_RUNNING" -gt 0 ]; then
    OVERALL_HEALTHY="true"
else
    OVERALL_HEALTHY="false"
fi

cat << EOF
{
  "healthy": $OVERALL_HEALTHY,
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "services": {
    "caddy": {
      "healthy": $CADDY_HEALTHY,
      "status": "$(brew services list | grep caddy | awk '{print $2}')"
    },
    "docker": {
      "running": $CONTAINERS_RUNNING,
      "total": $CONTAINERS_TOTAL,
      "healthy": $CONTAINERS_HEALTHY
    }
  },
  "containers": [
$(docker ps --format '    {"name": "{{.Names}}", "status": "{{.Status}}", "state": "{{.State}}"}' 2>/dev/null | sed '$!s/$/,/')
  ],
  "resources": {
    "disk_usage": "$(df -h / | awk 'NR==2 {print $5}')",
    "uptime": "$(uptime | sed 's/.*up //' | sed 's/, [0-9]* user.*//')"
  }
}
EOF
EOF

chmod +x ~/webserver/scripts/health-check.sh
```

#### Step 2: Update Status Site Caddyfile

Edit your status site configuration in `/usr/local/etc/Caddyfile`:

```caddy
# Status monitoring dashboard
status.njoubert.com {
    # Public health endpoint (no auth required)
    handle /health {
        respond `{exec ~/webserver/scripts/health-check.sh}` 200 {
            header Content-Type application/json
        }
    }
    
    # Password-protected dashboard
    handle {
        root * /usr/local/var/www/status
        file_server
        
        basicauth {
            admin JDJhJDE0JHlvdXJfaGFzaGVkX3Bhc3N3b3JkX2hlcmU
        }
    }
    
    log {
        output file /usr/local/var/log/caddy/status.log
    }
}
```

#### Step 3: Reload Caddy

```bash
~/webserver/scripts/manage-caddy.sh validate
~/webserver/scripts/manage-caddy.sh reload
```

#### Step 4: Test Health Endpoint

```bash
curl https://status.njoubert.com/health | jq
```

Expected output:
```json
{
  "healthy": true,
  "timestamp": "2025-10-26T12:34:56Z",
  "services": {
    "caddy": {
      "healthy": true,
      "status": "started"
    },
    "docker": {
      "running": 5,
      "total": 5,
      "healthy": 5
    }
  },
  "containers": [
    {"name": "lydiajoubert-wordpress", "status": "Up 2 hours", "state": "running"},
    {"name": "lydiajoubert-db", "status": "Up 2 hours (healthy)", "state": "running"}
  ],
  "resources": {
    "disk_usage": "45%",
    "uptime": "3 days"
  }
}
```

### Use with External Monitoring Services

#### UptimeRobot (Free)
1. Sign up at [uptimerobot.com](https://uptimerobot.com)
2. Create "New Monitor"
   - Monitor Type: HTTP(s)
   - URL: `https://status.njoubert.com/health`
   - Monitoring Interval: 5 minutes (free tier)
3. Get email/SMS alerts when site goes down

#### Healthchecks.io (Free)
1. Sign up at [healthchecks.io](https://healthchecks.io)
2. Create a new check
3. Add this to crontab (checks every 5 minutes):
```bash
*/5 * * * * curl -fsS --retry 3 https://hc-ping.com/your-uuid-here > /dev/null
```

#### Better Uptime (Free Tier)
1. Sign up at [betteruptime.com](https://betteruptime.com)
2. Add `https://status.njoubert.com/health` as monitored URL
3. Configure alerts (Slack, email, SMS)

---

## Recommended Implementation: Combined Approach

**Implement all three options for comprehensive monitoring at zero cost:**

### Step-by-Step (20 minutes)

1. **Status Dashboard (15 min)**
   - Create generation script
   - Add to Caddyfile
   - Set up cron job
   - Test dashboard

2. **Health Endpoint (5 min)**
   - Create health check script
   - Update Caddyfile
   - Test endpoint

3. **Menu Bar App (5 min)** *(Optional - only on Mac Mini desktop)*
   - Install SwiftBar
   - Create plugin
   - Launch app

### What You'll Have

✅ **Visual monitoring** - Dashboard at `https://status.njoubert.com`  
✅ **API monitoring** - Health endpoint at `https://status.njoubert.com/health`  
✅ **External alerts** - UptimeRobot watching your endpoint  
✅ **Terminal commands** - Use `web-manage status` and `web-manage health` (already in v1.0.0)  
✅ **Menu bar** - Always-visible status (if using Mac Mini desktop)

**Total resource cost:** ~2 MB RAM, cron job runs once per minute  
**Setup time:** 20 minutes  
**Maintenance:** Zero - runs automatically

---

## Verification Checklist

After implementation, verify everything works:

- [ ] Status dashboard accessible at `https://status.njoubert.com`
- [ ] Dashboard shows correct Caddy status
- [ ] Dashboard shows all Docker containers
- [ ] Dashboard auto-refreshes every 30 seconds
- [ ] Health endpoint returns valid JSON
- [ ] Health endpoint accessible without password
- [ ] Terminal commands work (`web-manage status`, `web-manage health`)
- [ ] External monitoring service configured (UptimeRobot/Healthchecks.io)
- [ ] Receiving test alerts from monitoring service
- [ ] SwiftBar plugin working (if installed)
- [ ] Cron job running (check with `crontab -l`)

---

## Troubleshooting

### Dashboard Not Updating
```bash
# Check cron job is running
crontab -l

# Manually run generation script
~/webserver/scripts/generate-status.sh

# Check cron logs
grep CRON /var/log/system.log
```

### Health Endpoint Returns Error
```bash
# Test script directly
~/webserver/scripts/health-check.sh

# Check Caddy logs
tail -f /usr/local/var/log/caddy/status.log
```

### SwiftBar Not Showing
```bash
# Check plugin permissions
ls -la ~/Library/Application\ Support/SwiftBar/webserver.5m.sh

# Make sure it's executable
chmod +x ~/Library/Application\ Support/SwiftBar/webserver.5m.sh

# Restart SwiftBar
killall SwiftBar && open -a SwiftBar
```

---

## Next Steps

Once v1.0.1 monitoring is in place:

- **v1.2**: Add resource limits to Docker containers
- **v1.4**: Upgrade to full monitoring stack (Prometheus + Grafana)
  - Keep the simple dashboard as a backup
  - Health endpoint becomes part of Prometheus scraping
- **v1.6**: Implement automated backup strategy

**Your monitoring foundation is ready! 🎉**
