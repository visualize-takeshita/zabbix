# Zabbix MySQL Template Role

This role creates a comprehensive MySQL monitoring template for Zabbix.

## Features

- **Master Item**: Collects MySQL status variables via `mysql.get_status_variables["Default"]`
- **Dependent Items**: Extracts individual metrics from the master item using JSONPath preprocessing:
  - Threads connected/running
  - Connection statistics
  - Query counts (SELECT, INSERT, UPDATE, DELETE)
  - Aborted connections
- **Triggers**: Alerts for high thread usage and connection issues
- **User Macros**: Configurable thresholds

## Requirements

- Zabbix server with MySQL monitoring plugin configured
- `Plugins.Mysql.Sessions.Default.Uri`, `User`, and `Password` must be configured on the Zabbix server
- `community.zabbix` Ansible collection

## Template Structure

### Master Item
- **Name**: MySQL Status Variables
- **Key**: `mysql.get_status_variables["Default"]`
- **Interval**: 60 seconds
- **Type**: Zabbix agent
- **Value Type**: Text

### Dependent Items

| Item | Key | Field |
|------|-----|-------|
| MySQL Threads connected | `mysql.threads_connected` | Threads_connected |
| MySQL Threads running | `mysql.threads_running` | Threads_running |
| MySQL Max used connections | `mysql.max_used_connections` | Max_used_connections |
| MySQL Questions | `mysql.questions` | Questions |
| MySQL Select | `mysql.com_select` | Com_select |
| MySQL Insert | `mysql.com_insert` | Com_insert |
| MySQL Update | `mysql.com_update` | Com_update |
| MySQL Delete | `mysql.com_delete` | Com_delete |
| MySQL Aborted connects | `mysql.aborted_connects` | Aborted_connects |

### User Macros

- `{$MYSQL_THREADS_THRESHOLD}`: Default 100 - Alert when threads connected exceeds this value
- `{$MYSQL_CONNECTIONS_THRESHOLD}`: Default 500 - Alert when max used connections exceeds this value

### Triggers

1. **MySQL threads connected exceeds threshold** (warning)
   - Triggers when `mysql.threads_connected > {$MYSQL_THREADS_THRESHOLD}`

2. **MySQL max used connections exceeds threshold** (warning)
   - Triggers when `mysql.max_used_connections > {$MYSQL_CONNECTIONS_THRESHOLD}`

3. **MySQL aborted connects detected** (average)
   - Triggers when `mysql.aborted_connects > 0`

## Usage

### Run the playbook
```bash
direnv exec . ansible-playbook zabbix_template_mysql.yml
```

### Dry-run
```bash
direnv exec . ansible-playbook -C zabbix_template_mysql.yml
```

### Verbose output
```bash
direnv exec . ansible-playbook -vv zabbix_template_mysql.yml
```

## Customization

### Override template variables
```yaml
# Custom template name and group
ansible-playbook zabbix_template_mysql.yml \
  -e "zabbix_template_mysql_name=MySQL-Custom" \
  -e "zabbix_template_mysql_group=Monitoring"
```

### Override master item interval
```bash
ansible-playbook zabbix_template_mysql.yml \
  -e "mysql_master_item_interval=30s"
```

## Auto-registration

This template is designed to work with Zabbix auto-registration using the metadata:
```
app:mysql
```

Hosts that report this metadata during auto-registration will automatically receive this template.

## Dependencies

- Zabbix server with MySQL plugin enabled
- MySQL server accessible from Zabbix server
- Proper MySQL credentials configured in Zabbix

## Variables

See `defaults/main.yml` for all configurable variables.

## Task Files

- `tasks/main.yml`: Main task flow
- `tasks/macros.yml`: User macro creation
- `tasks/items.yml`: Master item creation
- `tasks/dependent_items.yml`: Dependent items creation
- `tasks/triggers.yml`: Trigger creation

## Notes

- Dependent items use JSONPath preprocessing (type: 12) to extract values from the JSON response
- All dependent items have a delay of 0 (inherit from master item)
- Master item interval is 60 seconds by default
- Preprocessing includes error_handler: 0 (do not use custom error handler)

## Troubleshooting

### Master item returns empty values
- Verify Zabbix server MySQL plugin configuration
- Check MySQL credentials in Zabbix server settings
- Verify network connectivity between Zabbix server and MySQL server

### Dependent items show "No data"
- Ensure master item is collecting data
- Check JSONPath field names match MySQL status variable names exactly
- Review Zabbix server logs for preprocessing errors

## References

- [Zabbix MySQL Plugin Documentation](https://www.zabbix.com/documentation/current/manual/config/items/itemtypes/mysql)
- [Zabbix Dependent Items](https://www.zabbix.com/documentation/current/manual/config/items/itemtypes/dependent_items)
- [JSONPath Preprocessing](https://www.zabbix.com/documentation/current/manual/appendix/expression_syntax/functions#jsonpath)
