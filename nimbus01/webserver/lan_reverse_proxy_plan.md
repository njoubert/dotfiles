# LAN Reverse Proxy Plan

**Goal:** Use nimbus01 as the single public-facing server, proxying requests to internal LAN servers.

**Domains:**
- `nimbus.wtf` → proxied to 10.1.0.2 (macminiserver)
- `nielsshootsfilm.com` → proxied to 10.1.0.2 (macminiserver)
- `weshootfilm.com` → served directly by nimbus01

## Architecture

```
Internet → Cloudflare → Router:443 → nimbus01 (10.1.0.x)
                                          ↓
                                    nginx reverse proxy
                                          ↓
                         ┌────────────────┴────────────────┐
                         ↓                                 ↓
                   weshootfilm.com                  nimbus.wtf
                   (served locally)            nielsshootsfilm.com
                                                       ↓
                                              10.1.0.2 (macminiserver)
                                              (HTTP only, LAN restricted)
```

## How It Works

1. **DNS**: All domains point to nimbus01's public IP (via Cloudflare)
2. **SSL Termination**: nimbus01 handles HTTPS certificates for ALL domains
3. **Proxy**: nginx forwards requests to internal server based on `Host` header
4. **Internal Traffic**: Goes over LAN as plaintext HTTP (fast, trusted network)
5. **Cert Management**: Single certbot instance on nimbus01 manages all certs

## Benefits

- ✅ Single point of SSL termination and cert management
- ✅ 10.1.0.2 no longer needs to be publicly exposed
- ✅ No more certbot on 10.1.0.2 for these domains
- ✅ Centralized logging and rate limiting on nimbus01
- ✅ Internal traffic is fast (no SSL overhead on LAN)

---

## Part 1: Configure nimbus01 (Reverse Proxy)

### 1.1 Request Certificates

```bash
# 1. Get certificates on nimbus01 for the proxied domains
sudo certbot certonly \
  --dns-cloudflare \
  --dns-cloudflare-credentials /etc/letsencrypt/cloudflare/credentials.ini \
  --dns-cloudflare-propagation-seconds 30 \
  -d nimbus.wtf -d www.nimbus.wtf \
  -d nielsshootsfilm.com -d www.nielsshootsfilm.com \
  --non-interactive --agree-tos --email njoubert@gmail.com

# 2. Create nginx config for each proxied domain
sudo tee /etc/nginx/sites-available/nimbus.wtf << 'EOF'
# nimbus.wtf - Reverse proxy to LAN server
server {
    listen 80;
    listen [::]:80;
    server_name nimbus.wtf www.nimbus.wtf;
    return 301 https://nimbus.wtf$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name nimbus.wtf www.nimbus.wtf;

    ssl_certificate /etc/letsencrypt/live/nimbus.wtf/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/nimbus.wtf/privkey.pem;
    include /etc/nginx/snippets/ssl-params.conf;

    access_log /var/log/nginx/nimbus.wtf.access.log main;
    error_log /var/log/nginx/nimbus.wtf.error.log;

    location / {
        include /etc/nginx/snippets/proxy-params.conf;
        proxy_pass http://10.1.0.2;  # Internal server
    }
}
EOF

# 3. Enable and reload
sudo ln -sf /etc/nginx/sites-available/nimbus.wtf /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

### 1.2 Create Reverse Proxy Config for nielsshootsfilm.com

```bash
sudo tee /etc/nginx/sites-available/nielsshootsfilm.com << 'EOF'
# nielsshootsfilm.com - Reverse proxy to LAN server (10.1.0.2)
server {
    listen 80;
    listen [::]:80;
    server_name nielsshootsfilm.com www.nielsshootsfilm.com;
    return 301 https://nielsshootsfilm.com$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name nielsshootsfilm.com www.nielsshootsfilm.com;

    ssl_certificate /etc/letsencrypt/live/nielsshootsfilm.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/nielsshootsfilm.com/privkey.pem;
    include /etc/nginx/snippets/ssl-params.conf;

    access_log /var/log/nginx/nielsshootsfilm.com.access.log main;
    error_log /var/log/nginx/nielsshootsfilm.com.error.log;

    location / {
        include /etc/nginx/snippets/proxy-params.conf;
        proxy_pass http://10.1.0.2;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/nielsshootsfilm.com /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

---

## Part 2: Configure 10.1.0.2 (Internal Server - macminiserver)

The internal server needs to:
1. Accept HTTP traffic from the LAN (for nimbus01 proxy)
2. Stop running certbot for these domains
3. Remove HTTPS server blocks (no longer needed)

### 2.1 Disable Certbot for Proxied Domains

```bash
# On 10.1.0.2 (macminiserver)

# List current certificates
sudo certbot certificates

# Delete certificates for domains now handled by nimbus01
sudo certbot delete --cert-name nimbus.wtf
sudo certbot delete --cert-name nielsshootsfilm.com

# Verify they're gone
sudo certbot certificates
```

### 2.2 Update nginx to Accept HTTP from LAN Only

For each site, replace the HTTPS config with an HTTP-only config that only accepts LAN traffic.

**Example for nimbus.wtf** (adjust path for macOS nginx):

```nginx
# /usr/local/etc/nginx/servers/nimbus.wtf.conf

server {
    listen 80;
    server_name nimbus.wtf www.nimbus.wtf;

    # Only allow requests from LAN (nimbus01 proxy)
    allow 10.1.0.0/24;
    deny all;

    # Your existing root/location config
    root /path/to/nimbus.wtf/public;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }
}

# DELETE or comment out the entire HTTPS server block (listen 443)
# It's no longer needed since nimbus01 handles SSL
```

**Example for nielsshootsfilm.com:**

```nginx
# /usr/local/etc/nginx/servers/nielsshootsfilm.com.conf

server {
    listen 80;
    server_name nielsshootsfilm.com www.nielsshootsfilm.com;

    # Only allow requests from LAN
    allow 10.1.0.0/24;
    deny all;

    # Your existing root/location config
    root /path/to/nielsshootsfilm.com/public;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }
}

# DELETE or comment out the entire HTTPS server block
```

### 2.3 Reload nginx on 10.1.0.2

```bash
# On macOS (10.1.0.2)
nginx -t && sudo nginx -s reload
```

---

## Part 3: Update DNS and Router

### 3.1 Update Cloudflare DNS

Point both domains to nimbus01's public IP:

| Type | Name | Content | Proxy |
|------|------|---------|-------|
| A | nimbus.wtf | (nimbus01 public IP) | Orange ☁️ |
| A | www.nimbus.wtf | (nimbus01 public IP) | Orange ☁️ |
| A | nielsshootsfilm.com | (nimbus01 public IP) | Orange ☁️ |
| A | www.nielsshootsfilm.com | (nimbus01 public IP) | Orange ☁️ |

### 3.2 Update Router Port Forwarding

Ensure ports 80 and 443 forward to **nimbus01 only**. Remove any forwarding to 10.1.0.2.

---

## Verification

### Step 1: Test Internal Connectivity (from nimbus01)

```bash
curl -I http://10.1.0.2
curl -I -H "Host: nimbus.wtf" http://10.1.0.2
curl -I -H "Host: nielsshootsfilm.com" http://10.1.0.2
```

### Step 2: Test Full Chain (after DNS propagates)

```bash
curl -I https://nimbus.wtf
curl -I https://nielsshootsfilm.com
```

---

## Checklist

1. [ ] **nimbus01**: Request certificates for nimbus.wtf and nielsshootsfilm.com
2. [ ] **nimbus01**: Create reverse proxy nginx configs
3. [ ] **nimbus01**: Test internal connectivity to 10.1.0.2
4. [ ] **10.1.0.2**: Delete certbot certificates for both domains
5. [ ] **10.1.0.2**: Update nginx configs to HTTP-only with LAN restriction
6. [ ] **10.1.0.2**: Remove HTTPS server blocks
7. [ ] **Cloudflare**: Update DNS to point to nimbus01
8. [ ] **Router**: Update port forwarding to nimbus01 only
9. [ ] **Test**: Verify HTTPS works end-to-end

---

## Rollback Plan

If something goes wrong:

1. **Revert DNS**: Point domains back to 10.1.0.2's public IP in Cloudflare
2. **Restore certs on 10.1.0.2**: `sudo certbot certonly -d nimbus.wtf -d nielsshootsfilm.com`
3. **Restore HTTPS config**: Uncomment the HTTPS server blocks on 10.1.0.2
4. **Disable proxy on nimbus01**: 
   ```bash
   sudo rm /etc/nginx/sites-enabled/nimbus.wtf
   sudo rm /etc/nginx/sites-enabled/nielsshootsfilm.com
   sudo nginx -s reload
   ```
