# Zabbix 7.0 Ansible Setup

## インストール・環境変数設定

```bash
$ cat <<E > .envrc
layout python3 
export ZABBIX_HOST=zabbixhost
export ZABBIX_PORT=8080
export ZABBIX_API_TOKEN=xxxxxxxxxxxxxx
E
$ direnv allow
$ pip install ansible
$ ansible-galaxy collection install community.zabbix
```

### 実行

```bash
ansible-playbook  -i ansible/inventory/hosts.yml ansible/playbooks/setup_zabbix.yml
```

## 実装内容

- ✅ Admin, Guest ユーザーを無効化
- ✅ Zabbix server ホスト: インターフェース設定を DNS: zabbix-agent2 (useip: 0) に変更
- ✅ Zabbix server ホスト: Linux by Zabbix agent active テンプレートをリンク
- ✅ 自動登録アクション: metadata に "linux" が含まれる場合、Linux servers グループに追加し、テンプレートを適用

## 注記

- 実行ユーザー (tk) は Super Admin 権限で事前に作成済みであること
