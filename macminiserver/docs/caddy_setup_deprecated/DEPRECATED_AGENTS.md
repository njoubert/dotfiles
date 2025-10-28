# Guidelines for AI Agents Working on Mac Mini Server

This document provides instructions for AI agents working on the Mac Mini webserver setup and maintenance.

## General Principles

### 1. Always Check Context First
- Read relevant documentation files before making changes
- Check current state of system (running processes, configurations, etc.)
- Verify file locations and paths before editing

### 2. Follow the Implementation Plan
- Work through `docs/webserver_1.0.0_implementation.md` sequentially
- Complete each phase before moving to the next
- Run verification steps after each section

### 3. Track Progress with Checkboxes
- **CRITICAL**: Check off `[ ]` → `[x]` as you complete each task
- Update the implementation document after completing each step
- Add new checkboxes if you discover additional steps needed

Example:
```markdown
- [ ] Install Caddy          # Before
- [x] Install Caddy          # After completing
```

### 4. Document Deviations
- If you need to deviate from the plan, add a note in the implementation doc
- Create new todo items for discovered issues
- Update the plan document if you find better approaches

## Working with the Implementation Document

### Checking Off Tasks
When you complete a task in `webserver_1.0.0_implementation.md`:

1. **Find the exact checkbox line** in the file
2. **Use `replace_string_in_file` tool** to change `[ ]` to `[x]`
3. **Include context lines** (3-5 lines before and after) to make the replacement unambiguous
4. **One checkbox at a time** - don't batch updates unless they're in the same code block

Example of proper checkbox update:
```markdown
# Before:
- [ ] Install Caddy via Homebrew
  ```bash
  brew install caddy
  ```

- [ ] Verify installation

# After:
- [x] Install Caddy via Homebrew
  ```bash
  brew install caddy
  ```

- [ ] Verify installation
```

### Adding New Todo Items
If you discover additional steps needed:

1. **Add new checkbox items** in the appropriate section
2. **Be specific** - include commands, file paths, or clear instructions
3. **Add to the bottom** of the current subsection or create a new subsection
4. **Mark as incomplete** `[ ]` initially

Example:
```markdown
### 1.5 Test Basic Caddy

- [x] Start Caddy manually first
- [x] Test the hello world page
- [ ] **ADDED**: Fix permissions on log directory
  ```bash
  sudo chown $(whoami):staff /usr/local/var/log/caddy
  ```
```

## Best Practices

### Assume this is an Intel Mac Mini
- Assume this runs an x86 Intel processor
- Always use paths for Intel locations

### File Editing
- **Always validate syntax** before reloading services (use `caddy validate`, `docker-compose config`, etc.)
- **Backup configuration files** before making changes (copy to `.backup` suffix)
- **Test incrementally** - don't make multiple changes without testing each one

### Running Commands
- **Use `run_in_terminal` tool** for executing commands
- **Check exit codes** - verify commands succeeded before proceeding
- **Capture output** - read command output to verify success
- **Use absolute paths** to avoid ambiguity

### Docker Operations
- **Check container status** after starting: `docker-compose ps`
- **Read logs** if containers aren't healthy: `docker-compose logs`
- **Verify ports** aren't already in use before starting containers
- **Test locally first** (localhost) before testing external access

### Caddy Operations
- **Use `caddy validate`** before reloading configuration
- **Use `caddy reload`** (not restart) for zero-downtime config changes
- **Check logs** after changes: `tail -f /usr/local/var/log/caddy/caddy-error.log`
- **Test HTTP first** (if needed), then add HTTPS

## Phase-Specific Guidelines

### Phase 1: Caddy Setup
- Verify Homebrew is installed before trying to install Caddy
- Create all necessary directories before starting Caddy
- Test with simple config before adding complexity
- Ensure LaunchDaemon loads successfully

### Phase 2: Static Sites
- Verify DNS records are correct before expecting HTTPS to work
- Give Let's Encrypt a few seconds to provision certificates
- Test both `example.com` and `www.example.com`
- Check certificate expiry dates after provisioning

### Phase 3: Docker Containers
- Verify Docker Desktop is running before starting containers
- Use `127.0.0.1:PORT` bindings, not `0.0.0.0:PORT` (security)
- Check healthchecks are passing before marking container as working
- Test API endpoints return expected responses

### Phase 4: WordPress
- Generate strong passwords using `openssl rand -base64 32`
- Never commit `.env` files to git
- Wait for MySQL container to be healthy before importing databases
- Update WordPress URLs after migrating databases
- Test wp-admin login to verify WordPress is working

## Error Handling

### When Something Fails
1. **Don't skip the step** - debug the issue
2. **Read error messages** carefully
3. **Check logs** - Caddy logs, Docker logs, system logs
4. **Add a troubleshooting note** to the implementation doc
5. **Create a checkbox** for the fix you applied

### Common Issues and Solutions

**Caddy won't start:**
- Check Caddyfile syntax: `caddy validate --config /usr/local/etc/Caddyfile`
- Check port 80/443 aren't already in use: `sudo lsof -i :80 -i :443`
- Check logs: `/usr/local/var/log/caddy/caddy-error.log`

**Docker container won't start:**
- Check logs: `docker-compose logs <service-name>`
- Verify port isn't in use: `lsof -i :<port>`
- Check environment variables are set: `docker-compose config`

**HTTPS certificate fails:**
- Verify DNS records point to server
- Check Cloudflare API token is valid
- Wait 1-2 minutes for DNS propagation
- Check Caddy logs for ACME errors

**WordPress shows database connection error:**
- Verify MySQL container is healthy: `docker-compose ps`
- Check environment variables match in both containers
- Check MySQL logs: `docker-compose logs db`

## Security Reminders

- **Never expose database ports** to external network
- **Use strong passwords** for all services
- **Keep `.env` files secure** (chmod 600)
- **Bind containers to 127.0.0.1** only
- **Verify security headers** are present in HTTP responses
- **Test rate limiting** is working

## Verification Before Marking Complete

Before checking off a phase as complete:

1. **Run all verification steps** in that phase
2. **Test from external network** (not just localhost)
3. **Verify HTTPS certificates** are valid
4. **Check all containers are healthy** (if applicable)
5. **Review logs for errors**
6. **Test the management scripts**
7. **Reboot and verify auto-start** (for major milestones)

## Communication with User

### When to Ask for User Input
- Credentials or API tokens needed
- Manual migration of content required
- Decision points (e.g., "migrate now or set up fresh?")
- Unexpected errors that require domain knowledge

### What to Report
- Completed phases/sections
- Any deviations from the plan
- Issues encountered and how they were resolved
- Current status and next steps

## Tool Usage Guidelines

### `read_file` tool
- Read large sections to get context
- Check implementation doc status before starting work
- Verify configuration files before editing

### `replace_string_in_file` tool
- Include 3-5 lines of context before and after
- Make one logical change per invocation
- Verify the change with `read_file` if needed

### `run_in_terminal` tool
- Provide clear explanation of what the command does
- Check exit code and output
- Use `isBackground=true` for long-running processes (servers)
- Use `isBackground=false` for commands that should complete

### `grep_search` or `semantic_search` tools
- Use to find configuration patterns
- Locate where changes need to be made
- Verify consistency across files

## Repository Structure Awareness

```
macminiserver/
├── AGENTS.md                          # This file
├── README.md                          # General information
├── bin/
│   └── tail_logs.sh                   # Log viewing utilities
├── docs/
│   ├── webserver_1.0.0_plan.md        # High-level plan (reference)
│   ├── webserver_1.0.0_research.md    # Alternative approaches (ignore)
│   └── webserver_1.0.0_implementation.md  # WORK FROM THIS FILE
├── dotfiles/
│   ├── vimrc
│   └── zshrc
└── provision.sh                       # Main provisioning script

# On the Mac Mini (at runtime):
/usr/local/etc/Caddyfile              # Main Caddy config
/usr/local/var/www/                    # Static websites
/usr/local/var/log/caddy/              # Caddy logs
~/webserver/                           # Docker projects
~/webserver/scripts/                   # Management scripts
```

## Version Control

### Commit Frequency
- Commit after completing each phase
- Commit after significant configuration changes
- Commit after resolving issues

### Commit Message Format
```
[Phase X.Y] Brief description of what was completed

- Checkbox item 1 completed
- Checkbox item 2 completed
- Any issues resolved
```

Example:
```
[Phase 1.4] Set up Caddy management script

- Created manage-caddy.sh with start/stop/logs commands
- Made script executable
- Added convenient alias to .zshrc
- Tested all script functions
```

## Final Notes

- **Be methodical** - don't rush through steps
- **Verify everything** - don't assume commands worked
- **Update the docs** - keep the implementation guide current
- **Ask when uncertain** - better to clarify than to make wrong assumptions

**The implementation document is your source of truth. Keep it updated!**
