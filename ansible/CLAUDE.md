# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an Ansible playbook collection for managing Zabbix monitoring infrastructure. It uses the `community.zabbix` collection to interact with Zabbix via its HTTP API, automating the creation and configuration of templates, users, proxies, host groups, and automation actions.

## Architecture

### Connection Model
- Uses **httpapi connection** to Zabbix (not SSH)
- Connects to Zabbix via HTTP API with token-based authentication
- Configured in `hosts` inventory file with environment variables for credentials

### Role Structure
Each role in the `roles/` directory handles a specific Zabbix resource type:

- **zabbix_template**: Creates monitoring templates with items, discovery rules, item prototypes, and trigger prototypes
  - Uses `community.zabbix.zabbix_template`, `community.zabbix.zabbix_item`, `community.zabbix.zabbix_discoveryrule`, `community.zabbix.zabbix_itemprototype`, and `community.zabbix.zabbix_triggerprototype` modules
  - Defaults in `defaults/main.yml` define template name, group, and items to monitor
  - Default template: "Linux minimal" with:
    - Static items: CPU, memory, uptime, agent ping
    - LLD discovery rules for automatic monitoring:
      - **Filesystem discovery** (`vfs.fs.discovery`): Auto-discovers mounted filesystems and monitors used space percentage
      - **Network interface discovery** (ready for extension): Can discover network interfaces automatically
    - Auto-generated item prototypes from discovery rules (e.g., per-filesystem usage monitoring)
    - Trigger prototypes for automatic alerting (e.g., disk space warnings)

- **zabbix_user**: Manages Zabbix users and roles
  - Currently disables default Admin/Guest users and updates Zabbix server host configuration

- **zabbix_action**: Creates automation actions (e.g., auto-registration)
  - Example: Auto-registers Linux hosts matching metadata criteria and assigns templates/groups

- **zabbix_proxy**: Manages Zabbix proxies

- **zabbix_hostgroup**: Manages host groups

### Playbooks
Top-level `.yml` files (e.g., `zabbix_user.yml`, `zabbix_template.yml`) are playbooks that:
1. Target the `zabbix` host group
2. Disable fact gathering (`gather_facts: no` since it's HTTP API, not SSH)
3. Include one or more roles

## Environment Setup

### Using direnv
The project includes `.envrc` with `layout python3` to manage Python environment:
```bash
direnv allow  # First time setup
```

### Required Environment Variables
All variables are set via environment (not hardcoded in inventory for security):
- `ZABBIX_HOST`: Zabbix server hostname/IP
- `ZABBIX_PORT`: Zabbix API port (usually 80 or 443)
- `ZABBIX_API_TOKEN`: Bearer token for API authentication
- `ZABBIX_URL`: Full Zabbix URL for direct API calls (e.g., http://zabbix/api_jsonrpc.php)

These are referenced in `hosts` inventory file via `lookup('env', '...')`

## Common Commands

### Run a specific playbook
```bash
ansible-playbook zabbix_user.yml
ansible-playbook zabbix_template.yml
```

### Validate playbook syntax
```bash
ansible-playbook --syntax-check zabbix_user.yml
```

### Dry-run (check mode)
```bash
ansible-playbook -C zabbix_user.yml
```

### Verbose output (useful for debugging)
```bash
ansible-playbook -vv zabbix_user.yml
```

## Configuration Files

- **ansible.cfg**: Core Ansible settings (inventory location, roles path, SSH options)
- **hosts**: Inventory file defining Zabbix host and connection parameters
- **.envrc**: direnv configuration for Python 3 environment

## Adding New Playbooks/Roles

1. Create a role directory: `roles/zabbix_<resource>/tasks/main.yml`
2. Optionally add `roles/zabbix_<resource>/defaults/main.yml` for variables
3. Create a playbook `.yml` file at repository root that references the role:
   ```yaml
   ---
   - hosts: zabbix
     gather_facts: no
     roles:
       - zabbix_<resource>
   ```

## Key Patterns

- **No fact gathering**: All playbooks use `gather_facts: no` since connection is httpapi
- **Environment variable substitution**: Connection credentials and URLs are injected at runtime
- **Metadata-based conditions**: Actions use host metadata (e.g., `project:nadv os:linux`) for targeting
- **Commented examples**: Several tasks have commented-out alternatives or experimental code (check for `#` in task definitions)

## Dependencies

Requires `community.zabbix` collection (typically installed via `requirements.yml` or galaxy).
