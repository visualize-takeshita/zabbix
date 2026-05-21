curl -X POST "${ZABBIX_URL}" \
    -H "Content-Type: application/json-rpc" \
    -H "Authorization: Bearer ${ZABBIX_API_TOKEN}" \
    -d '{
      "jsonrpc": "2.0",
      "method": "discoveryrule.update",
      "params": {
      "itemid": "69658",
        "filter": {
          "evaltype": 0,
          "conditions": [
            {
              "macro": "{#FSNAME}",
              "value": "^/$|^/var/lib/mysql$|^/var/sy$|^/backup$",
              "operator": 8
            }
          ]
        }
      },
      "id": 1
    }'
