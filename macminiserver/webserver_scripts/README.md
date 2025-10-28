# Webserver Scripts

This directory contains the actual scripts for managing the Mac Mini webserver. These scripts are version-controlled in the dotfiles repo and symlinked from `~/webserver/scripts/`.

## Scripts

### provision_webserver.sh
Main provisioning script that sets up the entire webserver infrastructure.

**Usage:**
```bash
cd ~/webserver/scripts
./provision_webserver.sh
```

**What it does:**
- Installs nginx, certbot, and certbot-dns-cloudflare
- Configures Cloudflare API credentials
- Sets up LaunchDaemons for auto-start, auto-renewal, and auto-updates
- Creates the hello-world test site
- Creates convenient symlinks

### provision_static_site_nginx.sh
Script to add a new static site with automatic SSL.

**Usage:**
```bash
cd ~/webserver/scripts
./provision_static_site_nginx.sh yourdomain.com
```

**What it does:**
- Creates site directory structure
- Requests SSL certificates from Let's Encrypt
- Generates nginx configuration
- Reloads nginx

### manage-nginx.sh
Nginx management utility script.

**Usage:**
```bash
~/webserver/scripts/manage-nginx.sh {start|stop|restart|reload|status|logs|test|sites}
```

**Commands:**
- `start` - Start Nginx service
- `stop` - Stop Nginx service
- `restart` - Restart Nginx service
- `reload` - Reload config (zero downtime)
- `status` - Show service status and recent errors
- `logs {error|access}` - Tail logs
- `test` - Test configuration syntax
- `sites` - List all configured sites

### auto_update.sh
Automatic update script (created by provision_webserver.sh).

Runs weekly via LaunchDaemon to update:
- Homebrew packages (nginx, certbot)
- pip3 packages (certbot-dns-cloudflare)

**Manual run:**
```bash
~/webserver/scripts/auto_update.sh
```

## Symlinks

These scripts are symlinked to `~/webserver/scripts/` for convenient access:

```bash
~/webserver/scripts/provision_webserver.sh → ~/Code/dotfiles/macminiserver/webserver_scripts/provision_webserver.sh
~/webserver/scripts/provision_static_site_nginx.sh → ~/Code/dotfiles/macminiserver/webserver_scripts/provision_static_site_nginx.sh
~/webserver/scripts/manage-nginx.sh → ~/Code/dotfiles/macminiserver/webserver_scripts/manage-nginx.sh
~/webserver/scripts/auto_update.sh → ~/Code/dotfiles/macminiserver/webserver_scripts/auto_update.sh
```

## Version Control

All scripts in this directory are:
- ✅ Version controlled in the dotfiles repo
- ✅ Can be updated with git pull
- ✅ Can be committed and pushed to backup changes
- ✅ Executable from either location (actual or symlink)

## Making Changes

To modify scripts:

1. Edit files in this directory (`~/Code/dotfiles/macminiserver/webserver_scripts/`)
2. Test your changes
3. Commit to git:
   ```bash
   cd ~/Code/dotfiles/macminiserver
   git add webserver_scripts/
   git commit -m "Update webserver scripts"
   git push
   ```

The changes are immediately available via the symlinks in `~/webserver/scripts/`.
