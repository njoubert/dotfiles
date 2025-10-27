# Webserver Provisioning Script - Progress Report v1.0 (Phase 1.6)

**Date**: October 27, 2025  
**Script**: `webserver_provision.sh`  
**Status**: ✅ Complete and tested

## Overview

Created a comprehensive, production-ready provisioning script for Mac Mini webserver setup that automates phases 1.1-1.6.5 of the webserver implementation plan. The script transforms manual installation steps into a repeatable, safe, and interactive provisioning process.

## Core Requirements Implemented

### 1. **Idempotency** ✅
- Script can be run multiple times safely without creating duplicate resources
- Detects existing files and configurations before making changes
- Only performs actions when necessary (install missing components, update changed files)
- No side effects from repeated execution

### 2. **Interactive File Management** ✅
- Compares file contents using efficient binary comparison (`cmp`)
- Shows unified diff (`diff -u`) when files differ from expected content
- Prompts user with three choices:
  - `[o]` Overwrite - backs up current file, installs new content
  - `[k]` Keep - skips update, preserves current file
  - `[e]` Exit - terminates provisioning script
- Only creates backups when user chooses to overwrite
- Backup naming: `filename.backup.YYYYMMDD_HHMMSS`

### 3. **Helper Function Architecture** ✅
Created `install_file_if_changed()` helper function that:
- Accepts destination path, expected content, and optional sudo flag
- Handles both regular and sudo-required file installations
- Uses temp files for safe content comparison
- Returns success/failure status for conditional logic
- Eliminates code duplication across phases

### 4. **Error Handling** ✅
- `set -e` - exits on any command error
- `set -u` - exits on undefined variable usage
- Clear error messages with emoji indicators (❌)
- Logs shown before errors for debugging context
- Non-zero exit codes on failures

### 5. **User Feedback** ✅
Color-coded logging system:
- 🔵 **Blue** - Informational messages with timestamps
- ✅ **Green** - Success confirmations
- ⚠️ **Yellow** - Warnings (non-fatal issues)
- ❌ **Red** - Errors (fatal issues)

## Phases Implemented

### Phase 1.1: Install Caddy
- Verifies Docker Desktop installation (detects desktop-linux context)
- Installs Caddy via Homebrew (if not present)
- Creates directory structure:
  - `/usr/local/var/www/hello` - web content
  - `/usr/local/var/log/caddy` - log files
  - `/usr/local/etc` - configuration
- Sets proper ownership (`$(whoami):staff`)

### Phase 1.2: Create Hello World Page
- Generates 601-byte responsive HTML test page
- Uses `install_file_if_changed()` for idempotent installation
- Shows diff if existing content differs
- Features: system fonts, emoji, JavaScript timestamp

### Phase 1.3: Create Basic Caddyfile
- Generates simple `:80` binding configuration
- Global options: `admin off`
- File server with access logging
- Validates syntax with `caddy validate`
- Uses `install_file_if_changed()` with sudo

### Phase 1.4: Create Management Script
- Generates `~/webserver/scripts/manage-caddy.sh`
- Commands: start, stop, restart, reload, status, logs, validate
- Makes script executable (`chmod +x`)
- Adds `caddy-manage` alias to `.zshrc` (idempotent)
- Binary comparison for script updates

### Phase 1.5: Test Basic Caddy
- Stops any existing Caddy processes
- Starts Caddy manually in background
- Tests localhost access with `curl`
- Detects and tests local IP address (en0/en1)
- Verifies access log creation
- Validates management script
- Cleans up test process (graceful kill, force if needed)

### Phase 1.6: Setup LaunchDaemon for Auto-Start
- Generates `/Library/LaunchDaemons/com.caddyserver.caddy.plist`
- Dynamic username/path detection
- Configuration:
  - `RunAtLoad: true` - starts at boot
  - `KeepAlive/SuccessfulExit: false` - auto-restart on crash
  - Runs as current user (not root)
  - Logs to `/usr/local/var/log/caddy/`
- Permissions: `root:wheel`, `644`
- Smart loading logic:
  - Loads if not present
  - **Kickstarts if loaded but process not running** (handles Phase 1.5 cleanup)
  - Uses `launchctl kickstart -k` for process restart
- Retry logic: 3 attempts with 2-second intervals
- Verifies both LaunchDaemon registration and running process

### Phase 1.6.5: Configure macOS Firewall
- Disables macOS Application Firewall (`socketfilterfw --setglobalstate off`)
- Rationale: Home server behind router firewall, Application Firewall causes connectivity issues
- Verifies firewall status after disabling
- Tests local IP access with 5-second timeout
- Security note: Router provides network-level protection

## Technical Implementation Details

### File Comparison Strategy
```bash
# Uses cmp for efficient binary comparison
if [[ "$use_sudo" == "true" ]]; then
    sudo cmp -s "$temp_file" "$dest_path" && files_match=true
else
    cmp -s "$temp_file" "$dest_path" && files_match=true
fi
```

### Diff Display
```bash
# Shows unified diff with context
sudo diff -u "$dest_path" "$temp_file" || true
# Format: - current file, + new content
```

### LaunchDaemon Kickstart Logic
```bash
# Handles killed process scenario
if ! ps aux | grep -v grep | grep -q caddy; then
    sudo launchctl kickstart -k system/com.caddyserver.caddy
    sleep 3
fi
```

## Testing Results

### Idempotency Verified ✅
- Running script twice with identical files: No changes, no backups created
- All phases report "already exists and is correct"
- No LaunchDaemon reloading when plist unchanged
- Kickstart only triggered when process not running

### Interactive Diff Tested ✅
- Modified hello world page (added emoji grayscale filter)
- Script detected difference and showed clear diff
- User prompted with options
- Backup created only after choosing overwrite
- New content installed successfully

### LaunchDaemon Resilience ✅
- Handles process killed during Phase 1.5 testing
- Kickstart restarts process without unload/reload cycle
- Retry logic accommodates startup delays
- Both localhost and IP access verified

## Script Statistics

- **Total Lines**: ~913 lines
- **Phases**: 6 main phases + 1 firewall phase
- **Functions**: 9 (logging + helper + phases)
- **Files Managed**: 4 (HTML, Caddyfile, management script, LaunchDaemon plist)
- **External Commands**: Homebrew, Caddy, Docker, launchctl, curl, diff, cmp

## Usage

```bash
# Run provisioning
cd /Users/njoubert/Code/dotfiles/macminiserver
bash webserver_provision.sh

# Interactive prompts appear when files differ
# Choose: [o]verwrite, [k]eep, or [e]xit

# Script requires sudo password for:
# - Directory creation/ownership changes
# - Caddyfile installation
# - LaunchDaemon operations
# - Firewall configuration
```

## Future Enhancements (Not Yet Implemented)

- Phase 1.7: Configure auto-login for Docker Desktop startup
- Phase 1.8: Setup Cloudflare DNS Challenge for HTTPS
- Phase 2+: Add production websites (njoubert.com, nielsshootsfilm.com, WordPress sites)
- Optional: `--yes` flag to skip interactive prompts (auto-accept overwrites)
- Optional: `--dry-run` flag to show what would change without applying
- Optional: Better detection of manual modifications vs. outdated content

## Known Limitations

1. **Manual Review Required**: Diffs require user to understand what changed and why
2. **No Config Validation**: Doesn't validate logical correctness (only syntax)
3. **Docker Desktop Not Managed**: Assumes Docker Desktop already installed and running
4. **Single User**: Designed for single-user Mac Mini, not multi-user systems
5. **Homebrew Dependency**: Requires Homebrew pre-installed

## Success Criteria Met ✅

1. ✅ Script completes all phases 1.1-1.6.5 without errors
2. ✅ Caddy webserver running and accessible on boot
3. ✅ No duplicate backups on repeated runs with unchanged files
4. ✅ User control over file modifications via interactive prompts
5. ✅ Clear visual feedback throughout execution
6. ✅ LaunchDaemon survives Phase 1.5 testing and restarts properly
7. ✅ All existing files detected correctly (true idempotency)

## Conclusion

The provisioning script successfully automates Mac Mini webserver setup with enterprise-grade features: idempotency, interactive change management, comprehensive error handling, and smart service recovery. The script is production-ready and forms a solid foundation for disaster recovery and reproducible deployments.

**Next Steps**: Proceed with Phase 1.7 (auto-login configuration) to enable Docker Desktop automatic startup for container-based services.
