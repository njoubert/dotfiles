# Mac Mini Webserver v1.0.0 - Implementation Guide

This document provides step-by-step implementation phases for setting up the Caddy-based webserver on the Mac Mini. Each phase builds on the previous one and includes verification steps.

**Implementation Approach:**
Instead of running commands directly, **create and maintain a provisioning script** (`~/webserver/webserver_provision.sh`) that implements each phase. This approach:
- Creates a repeatable, idempotent setup process
- Documents exactly what was done in executable form
- Enables easy disaster recovery or setup of additional servers
- Allows review before execution

At each phase, add the commands to your provisioning script, then review and run it. The script should be safe to re-run (idempotent) and should check prerequisites before proceeding.

**Prerequisites:**
- Mac Mini running macOS Sequoia 15.7 (Assume it is an Intel x86 mac mini!)
- Homebrew installed
- **Docker Desktop for Mac** installed (NOT homebrew docker)
  - Download from: https://www.docker.com/products/docker-desktop/
  - Uses Apple's Virtualization.framework (much better performance)
  - Do NOT use `brew install docker` (older, slower virtualization)
- Cloudflare account with API token
- Domains configured in Cloudflare DNS

**Important Notes:**
- This guide uses **system-level LaunchDaemons** for Caddy (starts at boot, no login required)
- Docker Desktop requires **auto-login** to start automatically (standard for Mac servers)
- **Layered availability:** Static sites work immediately at boot, Docker containers start after auto-login
- Caddy binary location differs by architecture:
  - Apple Silicon: `/opt/homebrew/bin/caddy`
  - Intel: `/usr/local/bin/caddy`
- Use `which caddy` to find your path when creating the plist file
- **Build your provisioning script progressively** - add each phase's commands as you go

---

## Phase 1: Caddy Base Setup + Hello World

**Goal:** Get Caddy running with a simple hello world page, proper logging, management scripts, and automatic startup.

### 1.1 Install Caddy

- [x] Verify Docker Desktop is installed (NOT the old homebrew docker)
  ```bash
  # Check if Docker Desktop is installed
  docker --version
  # Should show: Docker version XX.X.X, build XXXXXXX
  
  # Verify it's Docker Desktop (not homebrew docker)
  docker context ls
  # Should show "desktop-linux" context - this confirms Docker Desktop
    ```

- [x] If homebrew docker is installed, remove it

- [x] Install Caddy via Homebrew
  ```bash
  brew install caddy
  ```

- [x] Verify installation
  ```bash
  caddy version
  # Should show: v2.x.x
  ```

- [x] Create necessary directories
  ```bash
  sudo mkdir -p /usr/local/var/www/hello
  sudo mkdir -p /usr/local/var/log/caddy
  sudo mkdir -p /usr/local/etc
  sudo chown -R $(whoami):staff /usr/local/var/www
  sudo chown -R $(whoami):staff /usr/local/var/log/caddy
  ```

### 1.2 Create Hello World Page

- [x] Create a simple HTML page
  ```bash
  cat > /usr/local/var/www/hello/index.html << 'EOF'
  <!DOCTYPE html>
  <html>
  <head>
      <title>Hello from Mac Mini</title>
      <style>
          body { 
              font-family: system-ui; 
              max-width: 800px; 
              margin: 100px auto; 
              padding: 20px;
              text-align: center;
          }
          h1 { color: #2563eb; }
      </style>
  </head>
  <body>
      <h1>🎉 Hello from Mac Mini Webserver!</h1>
      <p>Caddy is running successfully.</p>
      <p><small>Served at: <code id="time"></code></small></p>
      <script>
          document.getElementById('time').textContent = new Date().toISOString();
      </script>
  </body>
  </html>
  EOF
  ```

### 1.3 Create Basic Caddyfile

- [x] Create initial Caddyfile (HTTP only for testing)
  ```bash
  cat > /usr/local/etc/Caddyfile << 'EOF'
  {
      # Global options
      admin off
  }

  # Simple :80 binding responds to all addresses (localhost, IP, etc)
  :80 {
      root * /usr/local/var/www/hello
      file_server
      
      log {
          output file /usr/local/var/log/caddy/access.log
      }
  }
  EOF
  ```

- [x] Test Caddyfile syntax
  ```bash
  caddy validate --config /usr/local/etc/Caddyfile --adapter caddyfile
  # Should show: Valid configuration
  ```

### 1.4 Create Management Script

- [x] Create webserver management script directory
  ```bash
  mkdir -p ~/webserver/scripts
  ```

- [x] Create the management script
  ```bash
  cat > ~/webserver/scripts/manage-caddy.sh << 'EOF'
  #!/bin/bash
  # Caddy Webserver Management Script

  CADDYFILE="/usr/local/etc/Caddyfile"
  LOG_DIR="/usr/local/var/log/caddy"
  ERROR_LOG="$LOG_DIR/caddy-error.log"
  ACCESS_LOG="$LOG_DIR/access.log"
  PLIST_PATH="/Library/LaunchDaemons/com.caddyserver.caddy.plist"

  case "$1" in
    start)
      echo "Starting Caddy..."
      sudo launchctl load -w "$PLIST_PATH"
      sleep 2
      sudo launchctl list | grep caddy
      ;;
      
    stop)
      echo "Stopping Caddy..."
      sudo launchctl unload -w "$PLIST_PATH"
      ;;
      
    restart)
      echo "Restarting Caddy..."
      sudo launchctl unload "$PLIST_PATH"
      sleep 2
      sudo launchctl load "$PLIST_PATH"
      sleep 2
      sudo launchctl list | grep caddy
      ;;
      
    reload)
      echo "Reloading Caddy configuration (zero downtime)..."
      caddy reload --config $CADDYFILE
      ;;
      
    status)
      echo "=== Caddy Service Status ==="
      if sudo launchctl list | grep -q caddy; then
        echo "✅ Caddy LaunchDaemon is loaded"
        sudo launchctl list | grep caddy
      else
        echo "❌ Caddy LaunchDaemon is not loaded"
      fi
      echo ""
      echo "=== Caddy Process ==="
      ps aux | grep -v grep | grep caddy || echo "No Caddy process found"
      echo ""
      echo "=== Recent Error Log ==="
      if [ -f "$ERROR_LOG" ]; then
        tail -5 "$ERROR_LOG"
      else
        echo "No error log found"
      fi
      ;;
      
    logs)
      if [ "$2" = "error" ]; then
        echo "Tailing Caddy error log (Ctrl+C to exit)..."
        tail -f "$ERROR_LOG"
      elif [ "$2" = "access" ]; then
        echo "Tailing Caddy access log (Ctrl+C to exit)..."
        tail -f "$ACCESS_LOG"
      else
        echo "Usage: $0 logs {error|access}"
        exit 1
      fi
      ;;
      
    validate)
      echo "Validating Caddyfile..."
      caddy validate --config $CADDYFILE
      ;;
      
    *)
      echo "Caddy Webserver Management"
      echo ""
      echo "Usage: $0 {start|stop|restart|reload|status|logs|validate}"
      echo ""
      echo "  start    - Start Caddy service"
      echo "  stop     - Stop Caddy service"
      echo "  restart  - Restart Caddy service (brief downtime)"
      echo "  reload   - Reload config (zero downtime)"
      echo "  status   - Show service status and recent errors"
      echo "  logs     - Tail logs (error|access)"
      echo "  validate - Validate Caddyfile syntax"
      exit 1
      ;;
  esac
  EOF
  ```

- [x] Make script executable
  ```bash
  chmod +x ~/webserver/scripts/manage-caddy.sh
  ```

- [x] Create convenient alias
  ```bash
  echo 'alias caddy-manage="~/webserver/scripts/manage-caddy.sh"' >> ~/.zshrc
  source ~/.zshrc
  ```

### 1.5 Test Basic Caddy

- [x] Start Caddy manually first (to catch any errors)
  ```bash
  caddy run --config /usr/local/etc/Caddyfile
  # Watch for errors, then Ctrl+C to stop
  ```

- [x] Start Caddy via management script
  ```bash
  ~/webserver/scripts/manage-caddy.sh start
  ```

- [x] Verify it's running
  ```bash
  ~/webserver/scripts/manage-caddy.sh status
  ```

- [x] Test the hello world page
  ```bash
  # From the Mac Mini itself
  curl http://localhost
  # Should see the HTML
  
  # From another machine on your network
  curl http://<mac-mini-ip>
  # Should see the HTML
  ```

- [x] Test the management script commands
  ```bash
  ~/webserver/scripts/manage-caddy.sh logs access
  # Ctrl+C to exit
  
  ~/webserver/scripts/manage-caddy.sh reload
  ~/webserver/scripts/manage-caddy.sh status
  ```

### 1.6 Setup LaunchDaemon for Auto-Start

**Note:** We're using a system-level LaunchDaemon (not Homebrew's LaunchAgent) so Caddy starts at boot before any user login. This is critical for a headless server setup.

- [x] Stop Caddy if running via manual start
  ```bash
  pkill caddy
  ```

- [x] Find Caddy binary location
  ```bash
  which caddy
  # Should show: /opt/homebrew/bin/caddy (Apple Silicon) or /usr/local/bin/caddy (Intel)
  # Save this path for the plist file
  ```

- [x] Create system LaunchDaemon plist
  ```bash
  sudo tee /Library/LaunchDaemons/com.caddyserver.caddy.plist << 'EOF'
  <?xml version="1.0" encoding="UTF-8"?>
  <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
  <plist version="1.0">
  <dict>
      <key>Label</key>
      <string>com.caddyserver.caddy</string>
      
      <key>ProgramArguments</key>
      <array>
          <string>/opt/homebrew/bin/caddy</string>
          <string>run</string>
          <string>--config</string>
          <string>/usr/local/etc/Caddyfile</string>
          <string>--adapter</string>
          <string>caddyfile</string>
      </array>
      
      <key>RunAtLoad</key>
      <true/>
      
      <key>KeepAlive</key>
      <dict>
          <key>SuccessfulExit</key>
          <false/>
      </dict>
      
      <key>StandardOutPath</key>
      <string>/usr/local/var/log/caddy/caddy-stdout.log</string>
      
      <key>StandardErrorPath</key>
      <string>/usr/local/var/log/caddy/caddy-error.log</string>
      
      <key>WorkingDirectory</key>
      <string>/usr/local/var/www</string>
      
      <key>UserName</key>
      <string>YOUR_USERNAME</string>
      
      <key>GroupName</key>
      <string>staff</string>
      
      <key>EnvironmentVariables</key>
      <dict>
          <key>HOME</key>
          <string>/Users/YOUR_USERNAME</string>
      </dict>
  </dict>
  </plist>
  EOF
  ```

- [x] **IMPORTANT: Update the plist file**
  ```bash
  # Replace YOUR_USERNAME with your actual username
  sudo nano /Library/LaunchDaemons/com.caddyserver.caddy.plist
  
  # Update these lines:
  # - <string>/opt/homebrew/bin/caddy</string> (use output from 'which caddy')
  # - <string>YOUR_USERNAME</string> (replace with $(whoami))
  # - <string>/Users/YOUR_USERNAME</string> (replace with $HOME)
  ```

- [x] Set correct permissions on plist
  ```bash
  sudo chown root:wheel /Library/LaunchDaemons/com.caddyserver.caddy.plist
  sudo chmod 644 /Library/LaunchDaemons/com.caddyserver.caddy.plist
  ```

- [x] Load the LaunchDaemon
  ```bash
  sudo launchctl load -w /Library/LaunchDaemons/com.caddyserver.caddy.plist
  ```

- [x] Verify LaunchDaemon is loaded and running
  ```bash
  sudo launchctl list | grep caddy
  # Should show the service with a PID
  
  ps aux | grep caddy
  # Should show caddy process running as your user
  ```

- [x] Test with management script
  ```bash
  ~/webserver/scripts/manage-caddy.sh status
  curl http://localhost
  ```

- [x] Test auto-start (recommended)
  ```bash
  # Reboot the Mac Mini
  sudo reboot
  
  # After reboot (NO LOGIN REQUIRED), from another machine:
  curl http://<mac-mini-ip>
  # Should see the hello world page without logging in
  
  # Or SSH in and check:
  ~/webserver/scripts/manage-caddy.sh status
  ```

### 1.6.5 Configure macOS Firewall

**Why:** The macOS Application Firewall is designed for laptops on public WiFi, not for servers. For a home server behind a router firewall, it's best to disable it to avoid connectivity issues.

**Security Note:** Your Mac Mini is protected by your router's firewall. The Application Firewall only provides application-level filtering which isn't suitable for port-based server operations.

- [x] Check current firewall status
  ```bash
  sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
  ```

- [x] Disable the Application Firewall
  ```bash
  sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate off
  ```

- [x] Verify it's disabled
  ```bash
  sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
  # Should show: Firewall is disabled. (State = 0)
  ```

- [x] Test access from the Mac Mini itself
  ```bash
  curl http://10.2.0.1
  # Should see the hello world page
  ```

- [x] Test access from another machine on the network
  ```bash
  # From another computer on your local network:
  curl http://<mac-mini-ip>
  # Should now see the hello world page
  ```

### 1.7 Configure Auto-Login (Required for Docker)

**Why:** Docker Desktop for Mac only starts when a user logs in. To ensure Docker containers start automatically after reboot, we need to enable auto-login.

**Important:** This guide requires **Docker Desktop** (not homebrew docker). Docker Desktop uses Apple's native Virtualization.framework which provides much better performance and integration with macOS. Homebrew's docker package uses older virtualization technology and is not suitable for production use.

**Security Note:** This is standard practice for home servers. Physical security is already provided by your home. The server is behind your firewall and not directly exposed to the internet.

- [x] Open System Settings
  ```bash
  # Open System Settings directly to Users & Groups
  open "x-apple.systempreferences:com.apple.preferences.users"
  ```

- [x] Enable Automatic Login
  1. Click the ⓘ button next to your username
  2. Enable "Automatically log in as this user"
  3. Enter your password when prompted
  4. Close System Settings

- [x] Alternative: Enable via command line
  ```bash
  # Replace 'your_username' with your actual username
  sudo defaults write /Library/Preferences/com.apple.loginwindow autoLoginUser "$(whoami)"
  
  # Verify the setting
  sudo defaults read /Library/Preferences/com.apple.loginwindow autoLoginUser
  ```

- [x] Configure Docker Desktop to start at login
  ```bash
  # Open Docker Desktop settings
  open -a Docker
  ```
  
  In Docker Desktop:
  1. Click Settings (gear icon)
  2. General tab
  3. Check "Start Docker Desktop when you log in"
  4. Click "Apply & Restart"

- [x] Test auto-login and Docker startup
  ```bash
  # Reboot the Mac Mini
  sudo reboot
  
  # After reboot, Mac should:
  # 1. Auto-login to your account
  # 2. Start Docker Desktop automatically
  # 3. Keep Caddy running (already started via LaunchDaemon)
  
  # SSH in and verify:
  docker ps
  # Should show Docker is running (might take 30-60 seconds after login)
  
  ~/webserver/scripts/manage-caddy.sh status
  # Should show Caddy is running (started immediately at boot)
  ```

**Why this approach works:**
- ✅ Caddy (static sites) starts at boot via LaunchDaemon - **no login required**
- ✅ Docker containers start after auto-login - **requires login**
- ✅ Fallback: If auto-login fails, static sites still work
- ✅ Best of both worlds: reliability + full Docker functionality

**Status: ✅ COMPLETE** - Tested and verified after reboot on October 27, 2025

### 1.8 Setup Cloudflare DNS Challenge (Prepare for HTTPS)

- [ ] Create Cloudflare API token
  - Log into Cloudflare Dashboard
  - Go to "My Profile" → "API Tokens"
  - Create Token → "Edit zone DNS" template
  - Permissions: Zone / DNS / Edit
  - Zone Resources: Include / All zones (or specific zones)
  - Copy the token

- [ ] Create Caddy environment file
  ```bash
  sudo touch /usr/local/etc/caddy.env
  sudo chmod 600 /usr/local/etc/caddy.env
  ```

- [ ] Add Cloudflare token to environment file
  ```bash
  sudo nano /usr/local/etc/caddy.env
  # Add this line:
  CLOUDFLARE_API_TOKEN=your_actual_token_here
  ```

- [ ] Update LaunchDaemon plist to include environment file
  ```bash
  sudo nano /Library/LaunchDaemons/com.caddyserver.caddy.plist
  ```
  
  Update the `EnvironmentVariables` section to include the Cloudflare token:
  ```xml
  <key>EnvironmentVariables</key>
  <dict>
      <key>HOME</key>
      <string>/Users/YOUR_USERNAME</string>
      <key>CLOUDFLARE_API_TOKEN</key>
      <string>YOUR_CLOUDFLARE_TOKEN_HERE</string>
  </dict>
  ```

- [ ] Reload LaunchDaemon to apply environment changes
  ```bash
  sudo launchctl unload /Library/LaunchDaemons/com.caddyserver.caddy.plist
  sudo launchctl load -w /Library/LaunchDaemons/com.caddyserver.caddy.plist
  ```

- [ ] Verify Caddy restarted successfully
  ```bash
  ~/webserver/scripts/manage-caddy.sh status
  curl http://localhost
  ```

### Phase 1 Verification Checklist

- [ ] Caddy is installed and version shows v2.x
- [ ] Hello world page displays at `http://localhost`
- [ ] Hello world page displays at `http://<mac-mini-ip>` from another device
- [ ] Management script works: start, stop, restart, reload, status, logs
- [ ] LaunchDaemon starts Caddy automatically at boot (before login)
- [ ] Auto-login is configured for your user account
- [ ] Docker Desktop starts automatically after login
- [ ] Cloudflare API token is configured in LaunchDaemon
- [ ] Caddyfile validates without errors
- [ ] Caddy runs as your user (not root) - verify with `ps aux | grep caddy`
- [ ] After reboot: Caddy serves static content before login, Docker starts after auto-login

**Phase 1 Complete! ✅**

---

## Phase 2: Setup njoubert.com Static Site

**Goal:** Configure Caddy to serve njoubert.com with automatic HTTPS using Cloudflare DNS challenge.

### 2.1 Prepare Static Site Directory

- [ ] Create directory for njoubert.com
  ```bash
  mkdir -p /usr/local/var/www/njoubert.com
  ```

- [ ] Create placeholder index.html
  ```bash
  cat > /usr/local/var/www/njoubert.com/index.html << 'EOF'
  <!DOCTYPE html>
  <html>
  <head>
      <title>Niels Joubert</title>
      <style>
          body { 
              font-family: system-ui; 
              max-width: 800px; 
              margin: 100px auto; 
              padding: 20px;
          }
      </style>
  </head>
  <body>
      <h1>Niels Joubert</h1>
      <p>Site under construction. Real content coming soon!</p>
  </body>
  </html>
  EOF
  ```

- [ ] **User Action Required:** Copy actual njoubert.com static files to `/usr/local/var/www/njoubert.com/` when ready

### 2.2 Update Caddyfile for njoubert.com

- [ ] Backup current Caddyfile
  ```bash
  cp /usr/local/etc/Caddyfile /usr/local/etc/Caddyfile.phase1.backup
  ```

- [ ] Update Caddyfile to add njoubert.com
  ```bash
  cat > /usr/local/etc/Caddyfile << 'EOF'
  {
      email njoubert@gmail.com
      # Cloudflare DNS challenge for automatic certs
      acme_dns cloudflare {env.CLOUDFLARE_API_TOKEN}
  }

  # Main website - njoubert.com
  njoubert.com, www.njoubert.com {
      root * /usr/local/var/www/njoubert.com
      file_server
      encode gzip
      
      # Rate limiting
      rate_limit {
          zone static {
              key {remote_host}
              events 100
              window 1m
          }
      }
      
      # Security headers
      header {
          X-Frame-Options "SAMEORIGIN"
          X-Content-Type-Options "nosniff"
          X-XSS-Protection "1; mode=block"
          Referrer-Policy "strict-origin-when-cross-origin"
      }
      
      # Cache static assets
      @static {
          path *.css *.js *.jpg *.jpeg *.png *.gif *.ico *.svg *.woff *.woff2
      }
      header @static Cache-Control "public, max-age=31536000, immutable"
      
      log {
          output file /usr/local/var/log/caddy/njoubert.com.log
      }
  }

  # Catch-all for testing (responds to direct IP access)
  :80 {
      root * /usr/local/var/www/hello
      file_server
      
      log {
          output file /usr/local/var/log/caddy/access.log
      }
  }
  EOF
  ```

- [ ] Validate new Caddyfile
  ```bash
  ~/webserver/scripts/manage-caddy.sh validate
  ```

- [ ] Reload Caddy with new config
  ```bash
  ~/webserver/scripts/manage-caddy.sh reload
  ```

### 2.3 Test njoubert.com

- [ ] Test HTTP access locally (will redirect to HTTPS)
  ```bash
  curl -I http://njoubert.com
  # Should see 308 redirect to https://
  ```

- [ ] Test HTTPS access
  ```bash
  curl https://njoubert.com
  # Should see the HTML content
  ```

- [ ] Test from browser
  - [ ] Visit https://njoubert.com
  - [ ] Verify SSL certificate is valid (Let's Encrypt)
  - [ ] Verify www.njoubert.com also works

- [ ] Check Caddy logs for any errors
  ```bash
  ~/webserver/scripts/manage-caddy.sh logs error
  # Ctrl+C to exit
  
  tail -20 /usr/local/var/log/caddy/njoubert.com.log
  ```

### 2.4 Verify HTTPS & Certificate

- [ ] Check certificate details
  ```bash
  echo | openssl s_client -connect njoubert.com:443 -servername njoubert.com 2>/dev/null | openssl x509 -noout -dates -subject -issuer
  # Should show Let's Encrypt certificate with valid dates
  ```

- [ ] Verify automatic renewal is configured
  ```bash
  # Caddy handles renewal automatically, but verify the cert is stored
  ls -la ~/Library/Application\ Support/Caddy/certificates/
  # Should see acme-v02.api.letsencrypt.org directories
  ```

- [ ] Test rate limiting (optional)
  ```bash
  # Send many rapid requests
  for i in {1..110}; do curl -s -o /dev/null -w "%{http_code}\n" https://njoubert.com; done
  # Should see some 429 (Too Many Requests) responses after ~100 requests
  ```

### Phase 2 Verification Checklist

- [ ] njoubert.com serves content over HTTPS
- [ ] www.njoubert.com works and serves same content
- [ ] SSL certificate is valid (Let's Encrypt)
- [ ] HTTP requests redirect to HTTPS
- [ ] Static assets are cached properly (check browser dev tools)
- [ ] Rate limiting is active
- [ ] Security headers are present (check browser dev tools)
- [ ] Logs are being written to /usr/local/var/log/caddy/njoubert.com.log

**Phase 2 Complete! ✅**

---

## Phase 3: Setup nielsshootsfilm.com (Hybrid Static + API)

**Goal:** Set up nielsshootsfilm.com with static frontend served by Caddy and dynamic Go API in Docker container.

### Phase 3.1: Static Frontend Setup

#### 3.1.1 Prepare Static Site Directory

- [ ] Create directory for nielsshootsfilm.com
  ```bash
  mkdir -p /usr/local/var/www/nielsshootsfilm.com
  ```

- [ ] Create placeholder index.html
  ```bash
  cat > /usr/local/var/www/nielsshootsfilm.com/index.html << 'EOF'
  <!DOCTYPE html>
  <html>
  <head>
      <title>Niels Shoots Film</title>
      <style>
          body { 
              font-family: system-ui; 
              max-width: 800px; 
              margin: 100px auto; 
              padding: 20px;
          }
      </style>
  </head>
  <body>
      <h1>Niels Shoots Film</h1>
      <p>Photography portfolio site under construction.</p>
      <p><a href="/api/health">API Health Check</a></p>
  </body>
  </html>
  EOF
  ```

- [ ] **User Action Required:** Copy actual nielsshootsfilm.com static files when ready

#### 3.1.2 Update Caddyfile

- [ ] Backup current Caddyfile
  ```bash
  cp /usr/local/etc/Caddyfile /usr/local/etc/Caddyfile.phase2.backup
  ```

- [ ] Add nielsshootsfilm.com configuration
  ```bash
  # Edit the Caddyfile to add this block before the catch-all :80 block:
  sudo nano /usr/local/etc/Caddyfile
  ```
  
  Add this section:
  ```caddy
  # Hybrid static + API site
  nielsshootsfilm.com, www.nielsshootsfilm.com {
      root * /usr/local/var/www/nielsshootsfilm.com
      
      # API routes go to Docker container
      handle /api/* {
          reverse_proxy localhost:8003
          
          # API-specific rate limiting
          rate_limit {
              zone api {
                  key {remote_host}
                  events 50
                  window 1m
              }
          }
      }
      
      # Everything else is static
      handle {
          file_server
          try_files {path} {path}/ /index.html
          encode gzip
      }
      
      # Security headers
      header {
          X-Frame-Options "SAMEORIGIN"
          X-Content-Type-Options "nosniff"
          X-XSS-Protection "1; mode=block"
      }
      
      log {
          output file /usr/local/var/log/caddy/nielsshootsfilm.com.log
      }
  }
  ```

- [ ] Validate and reload Caddy
  ```bash
  ~/webserver/scripts/manage-caddy.sh validate
  ~/webserver/scripts/manage-caddy.sh reload
  ```

- [ ] Test static site (API will 502 until Phase 3.2)
  ```bash
  curl https://nielsshootsfilm.com
  # Should see the HTML
  ```

### Phase 3.2: Go API Docker Container

**Note:** This phase involves working in the nielsshootsfilm.com repository. Switch to that repository for these steps.

#### 3.2.1 Prepare Go Application for Docker

- [ ] **Switch to nielsshootsfilm.com repository**
  ```bash
  cd ~/path/to/nielsshootsfilm.com
  ```

- [ ] Create Dockerfile for Go API
  ```dockerfile
  # Dockerfile
  FROM golang:1.21-alpine AS builder

  WORKDIR /app

  # Copy go mod files
  COPY go.mod go.sum ./
  RUN go mod download

  # Copy source code
  COPY . .

  # Build the application
  RUN CGO_ENABLED=0 GOOS=linux go build -o /api ./cmd/api

  # Final stage
  FROM alpine:latest

  RUN apk --no-cache add ca-certificates

  WORKDIR /root/

  # Copy the binary from builder
  COPY --from=builder /api .

  # Expose port
  EXPOSE 8080

  # Run
  CMD ["./api"]
  ```

- [ ] Create .dockerignore file
  ```bash
  cat > .dockerignore << 'EOF'
  .git
  .gitignore
  README.md
  .env
  *.log
  tmp/
  vendor/
  EOF
  ```

- [ ] Create docker-compose.yml
  ```yaml
  version: '3.8'

  services:
    api:
      build: .
      container_name: nielsshootsfilm-api
      restart: always
      ports:
        - "127.0.0.1:8003:8080"
      environment:
        - ENV=production
        - PORT=8080
      env_file:
        - .env
      healthcheck:
        test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:8080/api/health"]
        interval: 30s
        timeout: 10s
        retries: 3
        start_period: 40s
      logging:
        driver: "json-file"
        options:
          max-size: "10m"
          max-file: "3"

  networks:
    default:
      driver: bridge
  ```

- [ ] Create .env file (gitignored)
  ```bash
  cat > .env << 'EOF'
  # Add your environment-specific variables here
  DATABASE_URL=your_database_url_here
  API_KEY=your_api_key_here
  EOF
  ```

- [ ] Update .gitignore
  ```bash
  echo ".env" >> .gitignore
  ```

#### 3.2.2 Build and Test Docker Container

- [ ] Build the Docker image
  ```bash
  docker-compose build
  ```

- [ ] Start the container
  ```bash
  docker-compose up -d
  ```

- [ ] Check container status
  ```bash
  docker-compose ps
  docker-compose logs -f
  # Ctrl+C to exit logs
  ```

- [ ] Test API endpoint locally
  ```bash
  curl http://localhost:8003/api/health
  # Should return health check response
  ```

#### 3.2.3 Deploy to Mac Mini

- [ ] Create webserver project directory on Mac Mini
  ```bash
  # On Mac Mini
  mkdir -p ~/webserver/nielsshootsfilm-api
  ```

- [ ] Copy necessary files to Mac Mini
  ```bash
  # From development machine
  scp -r ./* macmini:~/webserver/nielsshootsfilm-api/
  # Or use git to clone/pull the repository
  ```

- [ ] On Mac Mini: Set up environment variables
  ```bash
  # On Mac Mini
  cd ~/webserver/nielsshootsfilm-api
  nano .env
  # Add production environment variables
  ```

- [ ] Build and start on Mac Mini
  ```bash
  cd ~/webserver/nielsshootsfilm-api
  docker-compose build
  docker-compose up -d
  ```

- [ ] Verify container is running
  ```bash
  docker-compose ps
  docker-compose logs --tail=50
  ```

#### 3.2.4 Test Full Integration

- [ ] Test API through Caddy reverse proxy
  ```bash
  # From Mac Mini
  curl https://nielsshootsfilm.com/api/health
  # Should return health check response with HTTPS
  ```

- [ ] Test from external network
  - [ ] Visit https://nielsshootsfilm.com in browser
  - [ ] Verify static content loads
  - [ ] Test API endpoint: https://nielsshootsfilm.com/api/health
  - [ ] Verify API responses are working

- [ ] Check logs
  ```bash
  # Caddy logs
  tail -50 /usr/local/var/log/caddy/nielsshootsfilm.com.log
  
  # Docker logs
  cd ~/webserver/nielsshootsfilm-api
  docker-compose logs --tail=50
  ```

#### 3.2.5 Configure Auto-Start

- [ ] Add to startup script (we'll create a comprehensive one in Phase 4)
  ```bash
  cat > ~/webserver/scripts/start-containers.sh << 'EOF'
  #!/bin/bash
  # Start all Docker containers

  echo "Starting nielsshootsfilm API..."
  cd ~/webserver/nielsshootsfilm-api
  docker-compose up -d

  echo ""
  echo "All containers started!"
  docker ps --format "table {{.Names}}\t{{.Status}}"
  EOF
  
  chmod +x ~/webserver/scripts/start-containers.sh
  ```

- [ ] Test auto-start script
  ```bash
  ~/webserver/scripts/start-containers.sh
  ```

### Phase 3 Verification Checklist

**Static Frontend:**
- [ ] nielsshootsfilm.com serves static content over HTTPS
- [ ] www.nielsshootsfilm.com works
- [ ] SSL certificate is valid

**Go API:**
- [ ] Docker container builds successfully
- [ ] Container starts and stays running
- [ ] Health check endpoint responds at https://nielsshootsfilm.com/api/health
- [ ] API logs are being written and rotated
- [ ] Container restarts automatically if it crashes (restart: always)

**Integration:**
- [ ] Static routes serve files
- [ ] /api/* routes proxy to Docker container
- [ ] Rate limiting works on API endpoints
- [ ] Both static and API work from external network

**Phase 3 Complete! ✅**

---

## Phase 4: Setup WordPress Sites in Docker

**Goal:** Set up two WordPress sites (lydiajoubert.com and zs1aaz.com) in isolated Docker containers.

### 4.1 Prepare WordPress Site 1: lydiajoubert.com

#### 4.1.1 Create Project Directory

- [ ] Create directory structure
  ```bash
  mkdir -p ~/webserver/wordpress-lydiajoubert
  cd ~/webserver/wordpress-lydiajoubert
  ```

#### 4.1.2 Create docker-compose.yml

- [ ] Create Docker Compose configuration
  ```bash
  cat > docker-compose.yml << 'EOF'
  version: '3.8'

  services:
    wordpress:
      image: wordpress:latest
      container_name: lydiajoubert-wordpress
      restart: always
      ports:
        - "127.0.0.1:8001:80"
      environment:
        WORDPRESS_DB_HOST: db
        WORDPRESS_DB_NAME: wordpress
        WORDPRESS_DB_USER: wpuser
        WORDPRESS_DB_PASSWORD: ${WP_DB_PASSWORD}
      volumes:
        - ./wp-content:/var/www/html/wp-content
        - ./uploads.ini:/usr/local/etc/php/conf.d/uploads.ini
      healthcheck:
        test: ["CMD", "curl", "-f", "http://localhost"]
        interval: 30s
        timeout: 10s
        retries: 3
        start_period: 40s
      logging:
        driver: "json-file"
        options:
          max-size: "10m"
          max-file: "3"
      depends_on:
        db:
          condition: service_healthy

    db:
      image: mysql:8.0
      container_name: lydiajoubert-db
      restart: always
      environment:
        MYSQL_DATABASE: wordpress
        MYSQL_USER: wpuser
        MYSQL_PASSWORD: ${WP_DB_PASSWORD}
        MYSQL_RANDOM_ROOT_PASSWORD: '1'
      volumes:
        - db-data:/var/lib/mysql
      healthcheck:
        test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "wpuser", "-p${WP_DB_PASSWORD}"]
        interval: 30s
        timeout: 10s
        retries: 3
        start_period: 30s
      logging:
        driver: "json-file"
        options:
          max-size: "10m"
          max-file: "3"

  volumes:
    db-data:

  networks:
    default:
      driver: bridge
  EOF
  ```

#### 4.1.3 Create Configuration Files

- [ ] Create PHP uploads configuration
  ```bash
  cat > uploads.ini << 'EOF'
  file_uploads = On
  memory_limit = 256M
  upload_max_filesize = 64M
  post_max_size = 64M
  max_execution_time = 600
  EOF
  ```

- [ ] Create .env file for secrets
  ```bash
  cat > .env << 'EOF'
  WP_DB_PASSWORD=CHANGE_THIS_TO_SECURE_PASSWORD
  EOF
  ```

- [ ] **User Action Required:** Generate secure password
  ```bash
  # Generate a secure password
  openssl rand -base64 32
  # Copy the output and update .env file
  nano .env
  ```

- [ ] Secure the .env file
  ```bash
  chmod 600 .env
  ```

#### 4.1.4 Migration from Existing Site (If Applicable)

- [ ] **If migrating from existing lydiajoubert.com:**
  
  **Option A: Copy wp-content directory**
  ```bash
  # From old server or backup
  scp -r old-server:/path/to/wp-content ./wp-content
  ```
  
  **Option B: Start fresh and restore later**
  - [ ] Skip this step and configure WordPress from scratch
  - [ ] Use WordPress importer plugin to restore content later

- [ ] **If migrating database:**
  
  Export from old site:
  ```bash
  # On old server
  mysqldump -u wpuser -p wordpress > lydiajoubert-db-backup.sql
  ```
  
  Copy to Mac Mini:
  ```bash
  scp old-server:lydiajoubert-db-backup.sql ~/webserver/wordpress-lydiajoubert/
  ```
  
  Import will be done after containers are running (step 4.1.6)

#### 4.1.5 Start WordPress Container

- [ ] Start the containers
  ```bash
  cd ~/webserver/wordpress-lydiajoubert
  docker-compose up -d
  ```

- [ ] Check container status
  ```bash
  docker-compose ps
  # Both containers should show "Up" and healthy
  ```

- [ ] Check logs
  ```bash
  docker-compose logs -f
  # Watch for any errors, then Ctrl+C to exit
  ```

- [ ] Test WordPress locally
  ```bash
  curl -I http://localhost:8001
  # Should see HTTP 302 redirect to wp-admin/install.php or homepage
  ```

#### 4.1.6 Import Existing Database (If Applicable)

- [ ] **If you have a database backup to restore:**
  ```bash
  # Copy SQL file into container
  docker cp lydiajoubert-db-backup.sql lydiajoubert-db:/tmp/backup.sql
  
  # Import the database
  docker exec lydiajoubert-db mysql -u wpuser -p${WP_DB_PASSWORD} wordpress < /tmp/backup.sql
  
  # Or import from outside:
  docker exec -i lydiajoubert-db mysql -u wpuser -p${WP_DB_PASSWORD} wordpress < lydiajoubert-db-backup.sql
  ```

- [ ] **Update WordPress URLs if domain changed:**
  ```bash
  docker exec -it lydiajoubert-db mysql -u wpuser -p${WP_DB_PASSWORD} wordpress
  
  # In MySQL prompt:
  UPDATE wp_options SET option_value = 'https://lydiajoubert.com' WHERE option_name = 'siteurl';
  UPDATE wp_options SET option_value = 'https://lydiajoubert.com' WHERE option_name = 'home';
  exit;
  ```

#### 4.1.7 Update Caddyfile

- [ ] Backup current Caddyfile
  ```bash
  cp /usr/local/etc/Caddyfile /usr/local/etc/Caddyfile.phase3.backup
  ```

- [ ] Add lydiajoubert.com configuration
  ```bash
  sudo nano /usr/local/etc/Caddyfile
  ```
  
  Add this section:
  ```caddy
  # WordPress site - lydiajoubert.com
  lydiajoubert.com, www.lydiajoubert.com {
      reverse_proxy localhost:8001
      encode gzip
      
      # WordPress-specific rate limiting
      rate_limit {
          zone wordpress {
              key {remote_host}
              events 20
              window 1m
          }
      }
      
      # Security headers
      header {
          X-Frame-Options "SAMEORIGIN"
          X-Content-Type-Options "nosniff"
          X-XSS-Protection "1; mode=block"
          -Server  # Hide server header
      }
      
      log {
          output file /usr/local/var/log/caddy/lydiajoubert.com.log
      }
  }
  ```

- [ ] Validate and reload Caddy
  ```bash
  ~/webserver/scripts/manage-caddy.sh validate
  ~/webserver/scripts/manage-caddy.sh reload
  ```

#### 4.1.8 Test lydiajoubert.com

- [ ] Test HTTPS access
  ```bash
  curl -I https://lydiajoubert.com
  # Should see HTTP 200 or 302 (redirect to login/home)
  ```

- [ ] Test in browser
  - [ ] Visit https://lydiajoubert.com
  - [ ] Verify SSL certificate is valid
  - [ ] Complete WordPress setup wizard (if fresh install)
  - [ ] Or verify existing content loads (if migrated)
  - [ ] Log into WordPress admin: https://lydiajoubert.com/wp-admin

- [ ] Check logs
  ```bash
  tail -50 /usr/local/var/log/caddy/lydiajoubert.com.log
  docker-compose logs --tail=50
  ```

### 4.2 Prepare WordPress Site 2: zs1aaz.com

#### 4.2.1 Create Project Directory

- [ ] Create directory structure
  ```bash
  mkdir -p ~/webserver/wordpress-zs1aaz
  cd ~/webserver/wordpress-zs1aaz
  ```

#### 4.2.2 Create docker-compose.yml

- [ ] Create Docker Compose configuration
  ```bash
  cat > docker-compose.yml << 'EOF'
  version: '3.8'

  services:
    wordpress:
      image: wordpress:latest
      container_name: zs1aaz-wordpress
      restart: always
      ports:
        - "127.0.0.1:8002:80"
      environment:
        WORDPRESS_DB_HOST: db
        WORDPRESS_DB_NAME: wordpress
        WORDPRESS_DB_USER: wpuser
        WORDPRESS_DB_PASSWORD: ${WP_DB_PASSWORD}
      volumes:
        - ./wp-content:/var/www/html/wp-content
        - ./uploads.ini:/usr/local/etc/php/conf.d/uploads.ini
      healthcheck:
        test: ["CMD", "curl", "-f", "http://localhost"]
        interval: 30s
        timeout: 10s
        retries: 3
        start_period: 40s
      logging:
        driver: "json-file"
        options:
          max-size: "10m"
          max-file: "3"
      depends_on:
        db:
          condition: service_healthy

    db:
      image: mysql:8.0
      container_name: zs1aaz-db
      restart: always
      environment:
        MYSQL_DATABASE: wordpress
        MYSQL_USER: wpuser
        MYSQL_PASSWORD: ${WP_DB_PASSWORD}
        MYSQL_RANDOM_ROOT_PASSWORD: '1'
      volumes:
        - db-data:/var/lib/mysql
      healthcheck:
        test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "wpuser", "-p${WP_DB_PASSWORD}"]
        interval: 30s
        timeout: 10s
        retries: 3
        start_period: 30s
      logging:
        driver: "json-file"
        options:
          max-size: "10m"
          max-file: "3"

  volumes:
    db-data:

  networks:
    default:
      driver: bridge
  EOF
  ```

#### 4.2.3 Create Configuration Files

- [ ] Create PHP uploads configuration
  ```bash
  cat > uploads.ini << 'EOF'
  file_uploads = On
  memory_limit = 256M
  upload_max_filesize = 64M
  post_max_size = 64M
  max_execution_time = 600
  EOF
  ```

- [ ] Create .env file with secure password
  ```bash
  # Generate a secure password
  openssl rand -base64 32
  
  # Create .env with the password
  cat > .env << 'EOF'
  WP_DB_PASSWORD=CHANGE_THIS_TO_SECURE_PASSWORD
  EOF
  
  nano .env
  chmod 600 .env
  ```

#### 4.2.4 Migration from Existing Site (If Applicable)

- [ ] **Follow same migration steps as 4.1.4 but for zs1aaz.com**
  - [ ] Copy wp-content if available
  - [ ] Export/copy database backup if available

#### 4.2.5 Start WordPress Container

- [ ] Start the containers
  ```bash
  cd ~/webserver/wordpress-zs1aaz
  docker-compose up -d
  ```

- [ ] Check container status
  ```bash
  docker-compose ps
  docker-compose logs -f
  ```

- [ ] Test WordPress locally
  ```bash
  curl -I http://localhost:8002
  ```

#### 4.2.6 Import Existing Database (If Applicable)

- [ ] **If you have a database backup:**
  ```bash
  docker exec -i zs1aaz-db mysql -u wpuser -p${WP_DB_PASSWORD} wordpress < zs1aaz-db-backup.sql
  
  # Update URLs if needed
  docker exec -it zs1aaz-db mysql -u wpuser -p${WP_DB_PASSWORD} wordpress
  UPDATE wp_options SET option_value = 'https://zs1aaz.com' WHERE option_name = 'siteurl';
  UPDATE wp_options SET option_value = 'https://zs1aaz.com' WHERE option_name = 'home';
  exit;
  ```

#### 4.2.7 Update Caddyfile

- [ ] Backup current Caddyfile
  ```bash
  cp /usr/local/etc/Caddyfile /usr/local/etc/Caddyfile.phase4.1.backup
  ```

- [ ] Add zs1aaz.com configuration
  ```bash
  sudo nano /usr/local/etc/Caddyfile
  ```
  
  Add this section:
  ```caddy
  # WordPress site - zs1aaz.com
  zs1aaz.com, www.zs1aaz.com {
      reverse_proxy localhost:8002
      encode gzip
      
      # WordPress-specific rate limiting
      rate_limit {
          zone wordpress {
              key {remote_host}
              events 20
              window 1m
          }
      }
      
      # Security headers
      header {
          X-Frame-Options "SAMEORIGIN"
          X-Content-Type-Options "nosniff"
          X-XSS-Protection "1; mode=block"
          -Server
      }
      
      log {
          output file /usr/local/var/log/caddy/zs1aaz.com.log
      }
  }
  ```

- [ ] Validate and reload Caddy
  ```bash
  ~/webserver/scripts/manage-caddy.sh validate
  ~/webserver/scripts/manage-caddy.sh reload
  ```

#### 4.2.8 Test zs1aaz.com

- [ ] Test HTTPS access
  ```bash
  curl -I https://zs1aaz.com
  ```

- [ ] Test in browser
  - [ ] Visit https://zs1aaz.com
  - [ ] Verify SSL certificate is valid
  - [ ] Complete WordPress setup wizard or verify content
  - [ ] Log into WordPress admin: https://zs1aaz.com/wp-admin

- [ ] Check logs
  ```bash
  tail -50 /usr/local/var/log/caddy/zs1aaz.com.log
  docker-compose logs --tail=50
  ```

### 4.3 Comprehensive Management Script

- [ ] Create complete management script for all services
  ```bash
  cat > ~/webserver/scripts/manage-all.sh << 'EOF'
  #!/bin/bash
  # Complete Webserver Management Script

  CADDY_SCRIPT="$HOME/webserver/scripts/manage-caddy.sh"
  SITES_DIR="$HOME/webserver"

  case "$1" in
    start)
      echo "========================================="
      echo "Starting All Webserver Services"
      echo "========================================="
      
      echo ""
      echo "1. Starting Caddy..."
      $CADDY_SCRIPT start
      
      echo ""
      echo "2. Starting Docker containers..."
      
      for site in wordpress-lydiajoubert wordpress-zs1aaz nielsshootsfilm-api; do
        if [ -d "$SITES_DIR/$site" ]; then
          echo "   Starting $site..."
          (cd "$SITES_DIR/$site" && docker-compose up -d)
        fi
      done
      
      echo ""
      echo "========================================="
      echo "All services started!"
      echo "========================================="
      docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
      ;;
      
    stop)
      echo "========================================="
      echo "Stopping All Webserver Services"
      echo "========================================="
      
      echo ""
      echo "1. Stopping Docker containers..."
      for site in wordpress-lydiajoubert wordpress-zs1aaz nielsshootsfilm-api; do
        if [ -d "$SITES_DIR/$site" ]; then
          echo "   Stopping $site..."
          (cd "$SITES_DIR/$site" && docker-compose down)
        fi
      done
      
      echo ""
      echo "2. Stopping Caddy..."
      $CADDY_SCRIPT stop
      
      echo ""
      echo "All services stopped."
      ;;
      
    restart)
      $0 stop
      sleep 3
      $0 start
      ;;
      
    status)
      echo "========================================="
      echo "Webserver Status"
      echo "========================================="
      
      echo ""
      echo "=== Caddy Status ==="
      $CADDY_SCRIPT status
      
      echo ""
      echo "=== Docker Containers ==="
      docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
      
      echo ""
      echo "=== Resource Usage ==="
      docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"
      
      echo ""
      echo "=== Disk Usage ==="
      df -h /
      echo ""
      echo "Docker volumes:"
      docker system df -v | grep -A 20 "Local Volumes"
      ;;
      
    logs)
      if [ -z "$2" ]; then
        echo "Usage: $0 logs <service>"
        echo ""
        echo "Available services:"
        echo "  caddy"
        echo "  lydiajoubert-wordpress"
        echo "  lydiajoubert-db"
        echo "  zs1aaz-wordpress"
        echo "  zs1aaz-db"
        echo "  nielsshootsfilm-api"
        exit 1
      fi
      
      if [ "$2" = "caddy" ]; then
        $CADDY_SCRIPT logs access
      else
        docker logs -f "$2"
      fi
      ;;
      
    health)
      echo "========================================="
      echo "Health Check"
      echo "========================================="
      
      echo ""
      echo "Testing all sites..."
      
      sites=(
        "https://njoubert.com"
        "https://nielsshootsfilm.com"
        "https://nielsshootsfilm.com/api/health"
        "https://lydiajoubert.com"
        "https://zs1aaz.com"
      )
      
      for site in "${sites[@]}"; do
        echo -n "  $site ... "
        status=$(curl -s -o /dev/null -w "%{http_code}" "$site")
        if [ "$status" = "200" ] || [ "$status" = "302" ]; then
          echo "✅ OK ($status)"
        else
          echo "❌ FAILED ($status)"
        fi
      done
      
      echo ""
      echo "Container health:"
      docker ps --format "table {{.Names}}\t{{.Status}}"
      ;;
      
    update)
      echo "========================================="
      echo "Updating Docker Images"
      echo "========================================="
      
      for site in wordpress-lydiajoubert wordpress-zs1aaz nielsshootsfilm-api; do
        if [ -d "$SITES_DIR/$site" ]; then
          echo ""
          echo "Updating $site..."
          (cd "$SITES_DIR/$site" && docker-compose pull)
        fi
      done
      
      echo ""
      echo "Images updated. Run '$0 restart' to apply changes."
      ;;
      
    *)
      echo "Webserver Management Script"
      echo ""
      echo "Usage: $0 {start|stop|restart|status|logs|health|update}"
      echo ""
      echo "  start   - Start all services (Caddy + Docker containers)"
      echo "  stop    - Stop all services"
      echo "  restart - Restart all services"
      echo "  status  - Show status of all services and resource usage"
      echo "  logs    - Tail logs for specific service"
      echo "  health  - Run health checks on all sites"
      echo "  update  - Pull latest Docker images"
      exit 1
      ;;
  esac
  EOF
  
  chmod +x ~/webserver/scripts/manage-all.sh
  ```

- [ ] Create convenient alias
  ```bash
  echo 'alias web-manage="~/webserver/scripts/manage-all.sh"' >> ~/.zshrc
  source ~/.zshrc
  ```

- [ ] Test the management script
  ```bash
  ~/webserver/scripts/manage-all.sh status
  ~/webserver/scripts/manage-all.sh health
  ```

### 4.4 Configure Complete Auto-Start

- [ ] Verify all containers have `restart: always`
  ```bash
  # Check each docker-compose.yml has restart: always for all services
  grep -r "restart:" ~/webserver/wordpress-*/docker-compose.yml
  grep -r "restart:" ~/webserver/nielsshootsfilm-api/docker-compose.yml
  ```

- [ ] Test auto-start
  ```bash
  # Stop all services
  ~/webserver/scripts/manage-all.sh stop
  
  # Reboot Mac Mini
  sudo reboot
  
  # After reboot, check everything started
  ~/webserver/scripts/manage-all.sh status
  ~/webserver/scripts/manage-all.sh health
  ```

### Phase 4 Verification Checklist

**lydiajoubert.com:**
- [ ] WordPress container running and healthy
- [ ] MySQL container running and healthy
- [ ] Site accessible via HTTPS
- [ ] SSL certificate valid
- [ ] Can log into WordPress admin
- [ ] Content displays correctly (if migrated)
- [ ] Logs being written and rotated

**zs1aaz.com:**
- [ ] WordPress container running and healthy
- [ ] MySQL container running and healthy
- [ ] Site accessible via HTTPS
- [ ] SSL certificate valid
- [ ] Can log into WordPress admin
- [ ] Content displays correctly (if migrated)
- [ ] Logs being written and rotated

**System Integration:**
- [ ] All containers start automatically after reboot
- [ ] Management script works: start, stop, restart, status, logs, health
- [ ] Resource usage is reasonable (check with `docker stats`)
- [ ] All sites respond to health checks
- [ ] Rate limiting is working on WordPress sites
- [ ] Caddy reverse proxy working for all sites

**Phase 4 Complete! ✅**

---

## Final Verification: Complete System Test

### System-Wide Checks

- [ ] Caddy starts automatically at boot (via LaunchDaemon, before login)
- [ ] Mac Mini auto-logs in to user account
- [ ] Docker Desktop starts automatically after login
- [ ] All Docker containers start automatically (within 60 seconds of login)
- [ ] All sites are accessible from external network
- [ ] All SSL certificates are valid and auto-renewing
- [ ] Rate limiting is working on all sites
- [ ] Logs are being written and rotated properly
- [ ] Docker containers restart if they crash
- [ ] Management scripts work as expected

### Performance Tests

- [ ] Run basic load test on static site
  ```bash
  # Install apache bench if not present
  brew install apache-bench
  
  # Test static site
  ab -n 1000 -c 10 https://njoubert.com/
  ```

- [ ] Check resource usage under load
  ```bash
  ~/webserver/scripts/manage-all.sh status
  # Monitor CPU and memory usage
  ```

### Security Checks

- [ ] Verify security headers on all sites
  ```bash
  curl -I https://njoubert.com | grep -E "X-Frame|X-Content|X-XSS"
  curl -I https://lydiajoubert.com | grep -E "X-Frame|X-Content|X-XSS"
  ```

- [ ] Test rate limiting
  ```bash
  # Send rapid requests to trigger rate limit
  for i in {1..30}; do curl -s -o /dev/null -w "%{http_code}\n" https://lydiajoubert.com/; done
  # Should see some 429 responses
  ```

- [ ] Verify Docker containers are only accessible via localhost
  ```bash
  # These should fail from external network
  curl http://<mac-mini-ip>:8001
  curl http://<mac-mini-ip>:8002
  curl http://<mac-mini-ip>:8003
  ```

### Documentation

- [ ] Document any custom configuration in README
- [ ] Document database passwords location (keep secure!)
- [ ] Document backup procedures (for future v1.6)
- [ ] Document how to add new sites

---

## 🎉 v1.0.0 Complete!

You now have a fully functional webserver with:

✅ **Static sites** - njoubert.com with fast serving  
✅ **Hybrid site** - nielsshootsfilm.com (static + Go API)  
✅ **WordPress sites** - lydiajoubert.com and zs1aaz.com  
✅ **Automatic HTTPS** - Let's Encrypt via Cloudflare DNS  
✅ **Rate limiting** - Protection against traffic spikes  
✅ **Docker isolation** - Each project in its own container  
✅ **Auto-start** - Everything boots on system startup  
✅ **Management tools** - Easy scripts to control everything  

### Quick Reference Commands

```bash
# Manage all services
~/webserver/scripts/manage-all.sh {start|stop|restart|status|logs|health|update}

# Manage just Caddy
~/webserver/scripts/manage-caddy.sh {start|stop|restart|reload|status|logs|validate}

# Check everything is healthy
web-manage health

# View logs
web-manage logs lydiajoubert-wordpress
web-manage logs caddy

# Check resource usage
web-manage status
```

### Next Steps (Future Versions)

- **v1.0.1**: Dead simple monitoring
- **v1.2**: Add resource limits to Docker containers
- **v1.4**: Set up Prometheus + Grafana monitoring
- **v1.6**: Implement automated backup strategy

**Congratulations! Your Mac Mini webserver is production-ready! 🚀**
