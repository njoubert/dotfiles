# SSL/HTTPS Options for Mac Mini Webserver

**Date:** October 27, 2025  
**Status:** Decision Required  
**TL;DR:** Caddy's "automatic HTTPS" has a major gotcha. Claude lied to us

## The Dilemma

Claude convinces us to use Caddy.
That Caddy is so much easier to configure. 
I looked at the configurations and sure, Caddy looked simpler. 
But were we misled.

If you want to run vanilla Caddy with automatic SSL certs, you cannot use Cloudflare. 
If you want to use Cloudflare, you must build a custom caddy build from scratch. 
If you build a custom caddy build from scratch, you do not get simple automatic updates.
This sucks balls.
Claude was so instant that Caddy is the way to go. 
Nope.

We need to choose how to handle automatic HTTPS certificates for our home webserver. The challenge is balancing:
- Automatic SSL certificate management
- Automatic software updates (security patches)
- Cloudflare proxy benefits (DDoS protection, CDN)
- Operational simplicity ("set and forget")

## The Caddy Disappointment

**What we were promised:**
- "Caddy has automatic HTTPS built-in!"
- "It just works out of the box!"
- "Way simpler than Nginx + Certbot!"

**What we actually discovered:**

Caddy's "automatic HTTPS" **only works out of the box for HTTP-01 challenge**. If you:
- Use Cloudflare with proxy enabled (orange cloud)
- Want to keep your server IP hidden
- Need DNS-01 challenge for any reason
- Want wildcard certificates

...then you **must use a DNS provider plugin**, which means:

1. **Building a custom Caddy from source** using `xcaddy`
2. **No more automatic updates** via Homebrew
3. **Homebrew will clobber your custom build** if you run `brew upgrade`
4. **Manual rebuild process** every time there's a security update
5. **Back to manual maintenance** - exactly what we were trying to avoid

**The irony:** We chose Caddy to avoid the complexity of Nginx + Certbot, but **Caddy + custom plugins is MORE complex** than the thing we were avoiding.

### The Plugin Architecture Problem

Caddy's plugin system requires **compile-time plugin integration**. You can't just install a plugin like you would with Nginx modules. This architectural decision means:
- ❌ Can't use package managers for plugins
- ❌ Can't separate core updates from plugin updates  
- ❌ Each plugin update requires rebuilding the entire binary
- ❌ Homebrew becomes useless once you need any plugin

**Meanwhile, Nginx + Certbot:**
- ✅ Nginx and Certbot are separate packages
- ✅ Both update independently via Homebrew
- ✅ Certbot plugins are Python packages: `pip install certbot-dns-cloudflare`
- ✅ All packages update automatically, no custom builds

### Why This Matters for a Home Server

For a home server you want to **"set and forget"**, this is a dealbreaker:

```
Scenario: Security vulnerability discovered in Caddy

With Standard Caddy (HTTP-01 only):
✅ brew upgrade
✅ Done.

With Custom Caddy (with DNS plugin):
❌ Oh no, Homebrew clobbered my custom build
❌ Need to remember I built it custom
❌ Find the xcaddy command I used
❌ Rebuild: xcaddy build --with github.com/caddy-dns/cloudflare
❌ Test the new build
❌ Replace the binary
❌ Restart the service
❌ Hope nothing broke

With Nginx + Certbot:
✅ brew upgrade
✅ Done.
```

**Lesson learned:** "Just works" software that requires custom builds for common use cases doesn't actually "just work."

---

## Why We're Switching to Nginx + Certbot

Despite Nginx having a reputation for complex configuration, **for our use case** it's actually simpler:

1. **Standard packages** - Everything via Homebrew, zero custom builds
2. **Independent updates** - Nginx, Certbot, and plugins all update separately
3. **Automatic renewals** - Certbot handles this via cron, no intervention needed
4. **Proven solution** - Nginx + Certbot + Cloudflare DNS is well-documented and battle-tested
5. **True "set and forget"** - Update once, works forever

**The configuration complexity argument:**

Yes, Nginx config files are more verbose than Caddyfile. But ask yourself:
- How often do you add new sites? (Once every few months at most)
- How often do security updates come out? (Monthly or more)

**We optimize for the common case: security updates, not adding new sites.**

## Background

Let's Encrypt offers two main challenge types for proving domain ownership:

1. **HTTP-01 Challenge**
   - Let's Encrypt connects directly to your server on port 80
   - Verifies you control the domain
   - ✅ Works with standard web servers
   - ❌ Requires your server IP to be publicly accessible
   - ❌ Cannot work with Cloudflare's proxy (orange cloud)

2. **DNS-01 Challenge**
   - Uses DNS TXT records to prove ownership
   - ✅ Works even if server is behind firewall
   - ✅ Works with Cloudflare proxy enabled
   - ✅ Can issue wildcard certificates
   - ❌ Requires API access to your DNS provider

## Our Specific Situation

- **Domain:** nimbus.wtf (and others to come)
- **DNS Provider:** Cloudflare
- **Current Setup:** Cloudflare proxy is ENABLED (orange cloud)
- **Server:** Mac Mini at home, ports 80/443 open
- **Goal:** Minimal long-term maintenance

---

## Option 1: Caddy + HTTP-01 Challenge (Turn Off Cloudflare Proxy)

### Setup
```
Internet → Your IP:80/443 → Caddy (with auto-HTTPS)
         (DNS points directly to your Mac Mini)
```

### Implementation
- Keep current Caddy setup
- Remove Cloudflare API token requirement
- Turn Cloudflare proxy OFF for each domain (grey cloud)
- DNS A records point directly to Mac Mini IP

### Pros
- ✅ **Zero maintenance** - Homebrew auto-updates Caddy
- ✅ **Standard configuration** - No custom builds
- ✅ **Automatic HTTPS** - Caddy handles everything
- ✅ **Simplest possible setup** - One service, just works
- ✅ **Easy troubleshooting** - Standard setup, lots of documentation
- ✅ **No API tokens to manage**

### Cons
- ❌ **No Cloudflare DDoS protection** - Server IP is exposed
- ❌ **No Cloudflare CDN** - All traffic hits your home connection
- ❌ **Exposed home IP** - Your real IP address is visible
- ❌ **No Cloudflare analytics** - Basic logging only

### When This Makes Sense
- Personal/hobby projects
- Low-traffic sites
- Home networks with good upload bandwidth
- When simplicity is the top priority

### Maintenance Required
- **Regular:** None (Homebrew auto-updates)
- **Occasional:** None
- **Emergency:** Standard Caddy troubleshooting

---

## Option 2: Caddy + DNS-01 Challenge (Custom Build with Cloudflare Plugin)

### Setup
```
Internet → Cloudflare Proxy → Your IP:80/443 → Caddy (custom build)
         (DNS points to Cloudflare, Cloudflare proxies to you)
```

### Implementation
- Install `xcaddy` (Caddy build tool)
- Build Caddy with Cloudflare DNS plugin: `xcaddy build --with github.com/caddy-dns/cloudflare`
- Install custom Caddy to `/usr/local/bin/caddy-custom`
- Update LaunchDaemon to use custom Caddy
- Keep Cloudflare API token in `/usr/local/etc/caddy.env`

### Pros
- ✅ **Cloudflare DDoS protection** - Cloudflare filters malicious traffic
- ✅ **Cloudflare CDN** - Static assets cached globally
- ✅ **Hidden IP address** - Real server IP not exposed
- ✅ **Cloudflare analytics** - Traffic insights and monitoring
- ✅ **Wildcard certificates** - Can do `*.nimbus.wtf`
- ✅ **Same great Caddy experience** - Auto-HTTPS, simple config

### Cons
- ❌ **Custom Caddy build required** - Not from Homebrew
- ❌ **Manual update process** - Must rebuild when Caddy updates
- ❌ **Forgotten maintenance risk** - Might forget to update in 6-12 months
- ❌ **Homebrew conflicts** - `brew upgrade caddy` will overwrite custom build
- ❌ **More complex troubleshooting** - Custom build, less common setup
- ❌ **API token management** - Another credential to secure

### Update Process
```bash
# When new Caddy version released (every few months):
cd ~/tmp
xcaddy build --with github.com/caddy-dns/cloudflare
./caddy version  # Test it
sudo mv caddy /usr/local/bin/caddy-custom
~/webserver/scripts/manage-caddy.sh restart
```

### When This Makes Sense
- Public-facing production sites
- High-traffic sites needing CDN
- When DDoS protection is important
- When you have processes for tracking updates

### Maintenance Required
- **Regular:** Monitor Caddy releases (monthly check)
- **Occasional:** Rebuild Caddy when updates released (2-5 times/year)
- **Emergency:** Custom build troubleshooting

---

## Option 3: Nginx + Certbot + Cloudflare DNS Plugin

### Setup
```
Internet → Cloudflare Proxy → Your IP:80/443 → Nginx
                                               → Certbot (manages certs via cron)
```

### Implementation
- Replace Caddy with Nginx
- Install Certbot: `brew install certbot`
- Install Cloudflare plugin: `pip3 install certbot-dns-cloudflare`
- Configure Nginx sites manually
- Set up Certbot renewal cron job
- Certbot uses Cloudflare DNS for challenges

### Pros
- ✅ **Standard packages** - Both Nginx and Certbot from Homebrew
- ✅ **Automatic updates** - Homebrew keeps both updated
- ✅ **Official Cloudflare plugin** - Maintained by Let's Encrypt team
- ✅ **Cloudflare proxy benefits** - DDoS, CDN, hidden IP
- ✅ **Mature ecosystem** - Nginx is battle-tested
- ✅ **Widely documented** - Tons of tutorials and help available

### Cons
- ❌ **More complex setup** - Two services instead of one
- ❌ **Manual configuration** - Nginx config files are verbose
- ❌ **More files to manage** - nginx.conf, site configs, certbot configs
- ❌ **Renewal automation needed** - Certbot cron job, reload hooks
- ❌ **No auto-HTTPS** - Must manually configure each site
- ❌ **More moving parts** - Nginx + Certbot + renewal system

### Configuration Complexity
```nginx
# Sample Nginx config (vs Caddy's 5 lines)
server {
    listen 80;
    listen [::]:80;
    server_name nimbus.wtf www.nimbus.wtf;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name nimbus.wtf www.nimbus.wtf;
    
    ssl_certificate /etc/letsencrypt/live/nimbus.wtf/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/nimbus.wtf/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    
    root /Users/njoubert/webserver/sites/nimbus.wtf/public;
    index index.html;
    
    location / {
        try_files $uri $uri/ =404;
    }
}
```

### When This Makes Sense
- When you need Cloudflare proxy benefits
- When you want standard, auto-updating packages
- When you're comfortable with Nginx configuration
- For production sites with dedicated operations

### Maintenance Required
- **Regular:** Certbot auto-renews (automated via cron)
- **Occasional:** Update Nginx configs when adding sites
- **Emergency:** Standard Nginx troubleshooting

---

## Option 4: Custom DNS Update Daemon ❌ NOT RECOMMENDED

### Why Not
- Requires writing and maintaining custom software
- More complex than any standard solution
- Higher risk of failure
- No community support
- Reinventing the wheel

**Verdict:** Don't do this. Use one of the standard solutions above.

---

## Comparison Matrix

| Feature | Option 1: Caddy + HTTP-01 | Option 2: Caddy + DNS-01 | Option 3: Nginx + Certbot |
|---------|---------------------------|--------------------------|---------------------------|
| **Setup Complexity** | ⭐ Very Simple | ⭐⭐ Moderate | ⭐⭐⭐ Complex |
| **Maintenance** | ⭐ Zero | ⭐⭐⭐ Manual updates | ⭐⭐ Mostly automated |
| **Auto-Updates** | ✅ Yes (Homebrew) | ❌ No (custom build) | ✅ Yes (Homebrew) |
| **DDoS Protection** | ❌ No | ✅ Yes (Cloudflare) | ✅ Yes (Cloudflare) |
| **CDN/Caching** | ❌ No | ✅ Yes (Cloudflare) | ✅ Yes (Cloudflare) |
| **Hidden IP** | ❌ No (exposed) | ✅ Yes (proxied) | ✅ Yes (proxied) |
| **Config Simplicity** | ⭐⭐⭐ Excellent | ⭐⭐⭐ Excellent | ⭐ Complex |
| **Troubleshooting** | ⭐⭐⭐ Easy | ⭐⭐ Moderate | ⭐⭐ Moderate |
| **Wildcard Certs** | ❌ No | ✅ Yes | ✅ Yes |
| **"Set and Forget"** | ⭐⭐⭐ Yes! | ⭐ No (updates) | ⭐⭐ Mostly |

---

## Decision Framework

### Choose Option 1 (Caddy + HTTP-01) if:
- [ ] This is a personal/hobby project
- [ ] Traffic will be low to moderate
- [ ] Simplicity is your top priority
- [ ] You want truly zero maintenance
- [ ] You don't need DDoS protection
- [ ] Your home upload bandwidth is good (>20 Mbps)

### Choose Option 2 (Caddy + DNS-01 custom) if:
- [ ] You need Cloudflare protection/CDN
- [ ] You're comfortable managing update processes
- [ ] You have a system for tracking software updates
- [ ] You can commit to checking for updates monthly
- [ ] Caddy's simplicity is important to you
- [ ] You're willing to trade convenience for features

### Choose Option 3 (Nginx + Certbot) if:
- [ ] You need Cloudflare protection/CDN
- [ ] You want automatic updates via Homebrew
- [ ] You're comfortable with Nginx configuration
- [ ] You value standard packages over simplicity
- [ ] You're okay with more configuration complexity
- [ ] This is closer to a production setup

---

## Recommendation for Your Situation

Based on your stated priorities:
- "I do not want to have to manually check on Caddy"
- "Or remember in a year that we built a special version"
- "We either automate completely, or turn off Cloudflare"

And based on the Caddy plugin architecture limitations discovered:
- Caddy's "automatic HTTPS" requires custom builds for common scenarios
- Custom builds mean no automatic updates
- This defeats the entire point of choosing Caddy

### My Updated Recommendation: **Option 3 (Nginx + Certbot + Cloudflare DNS)**

**Reasoning:**
1. **You want Cloudflare proxy** - It provides value (DDoS, CDN, hidden IP)
2. **You want zero manual maintenance** - Nginx + Certbot delivers this via Homebrew
3. **Caddy's promise was broken** - "Automatic HTTPS" isn't actually automatic for your use case
4. **Nginx is actually simpler** - When you factor in the full lifecycle (setup + maintenance)
5. **Configuration once vs updates forever** - We write verbose config once, but get updates forever

**Action Items:**
1. Switch from Caddy to Nginx
2. Install Certbot with Cloudflare DNS plugin
3. Set up automatic renewal via cron
4. Keep Cloudflare proxy enabled (orange cloud)
5. Get automatic updates via Homebrew forever

### Why Not Option 1 (Caddy + HTTP-01)?

While this would give you automatic updates, you'd lose:
- Cloudflare DDoS protection
- Cloudflare CDN (faster global access)
- Hidden server IP address
- Cloudflare analytics

**For a public-facing site, these features are worth having.**

### Why Not Option 2 (Caddy + Custom Build)?

This was the original plan, but we discovered it requires:
- Manual rebuilds for every Caddy update
- Remembering you have a custom build
- Risk of Homebrew clobbering your build
- **Everything we wanted to avoid**

**The whole point of choosing Caddy was simplicity. Custom builds aren't simple.**

---

## The Path Forward: Migrating to Nginx

Since we've only deployed Phase 1 (hello world), switching now is easy:

1. **Keep everything else the same:**
   - LaunchDaemon (just change the binary)
   - Directory structure (`~/webserver/sites/`)
   - Management scripts architecture
   - Cloudflare DNS setup

2. **What changes:**
   - Replace Caddy binary with Nginx
   - Replace Caddyfile with nginx.conf
   - Add Certbot for certificate management
   - Update management scripts

3. **Benefits:**
   - More standard approach
   - Better long-term maintainability
   - Automatic updates for everything
   - Larger community and more documentation

This is a **one-time migration cost** for **permanent operational simplicity**.

---

## Migration Path

If you start with Option 1 and later need to switch:

### From Option 1 → Option 2 (Add Cloudflare proxy)
- Build custom Caddy with DNS plugin
- Update Caddyfile to use DNS-01
- Enable Cloudflare proxy (orange cloud)
- Minimal downtime

### From Option 1 → Option 3 (Switch to Nginx)
- Install Nginx and Certbot
- Migrate site configurations
- Set up certificate renewal
- Can test in parallel before switching

**Bottom line:** Starting simple doesn't lock you in.

---

## Questions to Consider

Before making your decision, ask yourself:

1. **How much traffic do you expect?**
   - <1000 visitors/day → Cloudflare probably not needed
   - >10,000 visitors/day → Cloudflare helps significantly

2. **Is this a public-facing production site?**
   - Personal blog → Simple is fine
   - Business website → Consider Cloudflare

3. **How much time can you dedicate to maintenance?**
   - Zero time → Option 1
   - 30 min/month → Option 2
   - 1 hour/month → Option 3

4. **What's your comfort level with ops work?**
   - Want simple → Option 1
   - Okay with some ops → Option 2 or 3
   - Love tinkering → Any option

5. **Do you have a process for tracking software updates?**
   - No → Option 1 or 3
   - Yes → Option 2 is viable

---

## Next Steps

Once you've made your decision:

1. **Document the choice** - Update implementation plan
2. **Update provisioning scripts** - Implement the chosen approach
3. **Test thoroughly** - Verify HTTPS works end-to-end
4. **Document maintenance** - Create runbook for any manual steps
5. **Set reminders** - If Option 2, calendar reminder for updates

---

## Additional Resources

### Caddy Documentation
- HTTP-01 Challenge: https://caddyserver.com/docs/automatic-https#http-challenge
- DNS-01 Challenge: https://caddyserver.com/docs/automatic-https#dns-challenge
- Cloudflare Module: https://github.com/caddy-dns/cloudflare

### Let's Encrypt
- Challenge Types: https://letsencrypt.org/docs/challenge-types/
- Rate Limits: https://letsencrypt.org/docs/rate-limits/

### Cloudflare
- Proxy vs DNS Only: https://developers.cloudflare.com/dns/manage-dns-records/reference/proxied-dns-records/
- API Tokens: https://developers.cloudflare.com/fundamentals/api/get-started/create-token/

### Alternative: Nginx + Certbot
- Nginx on macOS: https://nginx.org/en/docs/
- Certbot: https://certbot.eff.org/
- Certbot DNS Cloudflare: https://certbot-dns-cloudflare.readthedocs.io/

---

## Version History

- **2025-10-27:** Initial document created during Phase 2 planning
