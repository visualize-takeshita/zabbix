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

- **zabbix_template**: Creates monitoring templates with discovery rules, item prototypes, and trigger prototypes
  - File structure:
    - `tasks/main.yml`: Template creation, templateid retrieval, and imports other task files
    - `tasks/discovery.yml`: Discovery rule creation and filter configuration
    - `tasks/itemprototype.yml`: Item prototype creation via JSON-RPC
    - `tasks/triggerprototype.yml`: Trigger prototype creation
  - Uses `community.zabbix.zabbix_template`, `community.zabbix.zabbix_discoveryrule`, and JSON-RPC for advanced features
  - Defaults in `defaults/main.yml` define template name and group
  - Default template: "Linux minimal" with:
    - User macros: `{$DISK_USAGE_THRESHOLD}` (default: 90)
    - **LLD discovery rule** (`vfs.fs.discovery`): Auto-discovers mounted filesystems
    - **Filter configuration**: Excludes specific mount points (/, /var/lib/mysql, /var/sy, /backup) using NOT_MATCHES_REGEX
    - **Item prototypes**: Per-filesystem disk usage monitoring (`vfs.fs.size[{#FSNAME},pused]`)
    - **Trigger prototypes**: Alerts when disk usage exceeds `{$DISK_USAGE_THRESHOLD}%`
  - Uses JSON-RPC directly for features not supported by Ansible modules (filters, complex configurations)

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
direnv exec . ansible-playbook zabbix_user.yml
direnv exec . ansible-playbook zabbix_template.yml
```

Note: Always use `direnv exec .` to ensure environment variables are loaded.

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
- **.envrc**: direnv configuration for Python 3 environment and environment variables
- **README.md**: User-facing documentation
- **CLAUDE.md**: This file - guidance for Claude Code

## Key Implementation Patterns

### 1. No Fact Gathering
All playbooks use `gather_facts: no` since connection is httpapi (not SSH).

### 2. Environment Variable Substitution
Connection credentials and URLs are injected at runtime via `lookup('env', 'VAR_NAME')`.

### 3. JSON-RPC Direct Calls
When Ansible modules don't support certain features (e.g., discovery rule filters), use `uri` module to call Zabbix JSON-RPC API directly:
```yaml
- name: Update discovery rule filter
  uri:
    url: "{{ lookup('env', 'ZABBIX_URL') }}"
    method: POST
    headers:
      Content-Type: application/json-rpc
      Authorization: "Bearer {{ lookup('env', 'ZABBIX_API_TOKEN') }}"
    body_format: json
    body:
      jsonrpc: "2.0"
      method: "discoveryrule.update"
      params:
        itemid: "{{ discoveryrule_result.result[0].itemids[0] }}"
        filter:
          evaltype: 0
          conditions:
            - macro: "{#FSNAME}"
              value: "^/$|^/var/lib/mysql$"
              operator: 8
      id: 1
```

### 4. Jinja2 Template Escaping
Zabbix macros like `{#FSNAME}` or `{$MACRO}` can be misinterpreted as Jinja2 comment tags. Always escape them:
```yaml
# Bad: '{#FSNAME}'
# Good: "{{ '{#FSNAME}' }}"
```

### 5. Idempotency
- Fetch current state before updating
- Use `changed_when` to indicate when changes occur
- Use `failed_when` to handle expected errors (e.g., "already exists")

Example:
```yaml
- name: Get current filter
  uri: ...
  register: current_filter

- name: Update filter
  uri: ...
  changed_when: >
    current_filter.json.result[0].filter.evaltype | string != "0" or
    current_filter.json.result[0].filter.conditions[0].value != "expected_value"
```

### 6. Task File Organization
Complex roles should split tasks into separate files:
- `main.yml`: Primary logic and imports
- `discovery.yml`: Discovery rule specific tasks
- `itemprototype.yml`: Item prototype tasks
- `triggerprototype.yml`: Trigger prototype tasks

Use `ansible.builtin.import_tasks` to include them:
```yaml
- name: Import Discovery Rule tasks
  ansible.builtin.import_tasks: discovery.yml
```

### 7. Dynamic ID Resolution
Ansible modules may not return IDs in expected format. Always:
1. Register the result
2. Debug the structure if needed
3. Use correct path to access IDs

Example:
```yaml
- name: Create discovery rule
  community.zabbix.zabbix_discoveryrule: ...
  register: discoveryrule_result

# Result structure: discoveryrule_result.result[0].itemids[0]
# NOT: discoveryrule_result.itemid
```

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
4. Create `roles/zabbix_<resource>/README.md` documenting the role

## Troubleshooting Tips

### Environment Variables Not Loading
```bash
direnv allow
direnv exec . ansible-playbook <playbook>.yml
```

### Debugging API Responses
Add debug tasks to inspect registered variables:
```yaml
- name: Debug result
  debug:
    var: variable_name
```

### Testing JSON-RPC Calls
Convert `uri` tasks to curl for manual testing:
```bash
curl -X POST "${ZABBIX_URL}" \
  -H "Content-Type: application/json-rpc" \
  -H "Authorization: Bearer ${ZABBIX_API_TOKEN}" \
  -d '{"jsonrpc":"2.0","method":"method.name","params":{...},"id":1}'
```

### Common Issues
1. **Missing `hostid` parameter**: For item prototypes, use `hostid` with templateid value (not `templateid` parameter)
2. **Jinja2 syntax errors**: Escape Zabbix macros properly
3. **Empty result arrays**: Check if resources were created successfully before accessing array elements
4. **formulaid not supported**: Some Zabbix versions don't require `formulaid` in filter conditions

## Dependencies

- Requires `community.zabbix` collection (typically installed via `requirements.yml` or galaxy)
- Python dependencies managed via direnv and `.envrc`

## Documentation Standards

- Each role should have a `README.md` with:
  - Overview and features
  - Requirements
  - Variables
  - Resources created
  - Usage examples
  - Customization guide
  - Troubleshooting

## Best Practices for Claude Code

When working on this codebase:

1. **Always use direnv**: Run playbooks with `direnv exec . ansible-playbook ...`
2. **Check existing patterns**: Look at `zabbix_template` role for JSON-RPC examples
3. **Test incrementally**: Add debug tasks to verify data structures
4. **Maintain idempotency**: Always check current state before making changes
5. **Document changes**: Update relevant README.md files
6. **Escape macros**: Use `"{{ '{#MACRO}' }}"` for Zabbix macros in YAML
7. **Verify paths**: Module return values may differ; always debug register variables first
8. **Split complex tasks**: Use separate task files for better organization

## Reference

- [Zabbix API Documentation](https://www.zabbix.com/documentation/current/manual/api)
- [community.zabbix Collection Docs](https://docs.ansible.com/ansible/latest/collections/community/zabbix/)
- [Ansible httpapi Connection](https://docs.ansible.com/ansible/latest/plugins/connection/httpapi.html)
