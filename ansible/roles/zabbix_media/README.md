# Zabbix Import Chatwork Role

このロールは、Chatwork webhook メディアタイプを Zabbix に自動インポートするための Ansible Role です。

## 機能

- Chatwork webhook メディアタイプの自動インポート
- `community.zabbix.zabbix_mediatype` モジュールによる冪等性の確保
- YAML ファイルから設定を読み込み、Ansible で管理

## 要件

- Ansible 2.9 以上
- `community.zabbix` collection
- Zabbix Server 7.4 以上
- 環境変数:
  - `ZABBIX_URL`: Zabbix JSON-RPC API の URL（例: http://zabbix/api_jsonrpc.php）
  - `ZABBIX_API_TOKEN`: Zabbix API 認証トークン

## ファイル構成

```
roles/zabbix_import_chatwork/
├── README.md                    # このファイル
├── defaults/
│   └── main.yml                # デフォルト変数
└── tasks/
    ├── main.yml                # メインタスク
    └── media_type_chatwork.yml # Chatwork メディアタイプインポート
```

## 作成されるリソース

### Chatwork メディアタイプ

**ファイル**: `templates/media/chatwork/media_chatwork.yaml`

以下の設定を含みます：

- **タイプ**: WEBHOOK
- **パラメータ**:
  - `chatwork_token`: Chatwork API トークン（必須）
  - `chatwork_room_id`: 通知先ルームID（必須）
  - `alert_subject`: アラート件名
  - `alert_message`: アラートメッセージ
  - イベント関連パラメータ（イベントソース、重要度、タグなど）

- **機能**:
  - トリガーアラート（PROBLEM、RECOVERY、UPDATE）
  - 検出（Discovery）イベント
  - 自動登録（Autoregistration）イベント
  - 内部（Internal）イベント
  - サービス（Service）イベント
  - Chatwork 独自メッセージフォーマット `[info][title]...[/title]...[/info]`

詳細は `templates/media/chatwork/README.md` を参照してください。

## 使用方法

### Playbook での使用方法

```yaml
---
- hosts: zabbix
  gather_facts: no
  roles:
    - zabbix_import_chatwork
```

### 実行例

```bash
# 環境変数を設定（direnv を使用する場合）
direnv allow

# Playbook を実行
ansible-playbook zabbix_import_chatwork.yml
```

### Verbose オプション

```bash
# 詳細ログを出力
ansible-playbook -vv zabbix_import_chatwork.yml

# チェックモード（実行せず確認）
ansible-playbook -C zabbix_import_chatwork.yml
```

## 冪等性

このロールは完全な冪等性を保ちます：

- `community.zabbix.zabbix_mediatype` モジュールが自動的に状態を確認
- メディアタイプが既に存在する場合はスキップ
- 複数回実行しても安全

ロジックは以下の通りです：
1. YAML ファイルからメディアタイプ設定を読み込み
2. `zabbix_mediatype` モジュールで create/update を試行
3. モジュールが自動的に冪等性を保証

## インポート後の設定

Chatwork メディアタイプがインポートされた後、Zabbix UI で以下を設定してください：

1. **Zabbix UI で設定**:
   - **管理** → **メディアタイプ** → **Chatwork** をクリック
   - **パラメータ** セクションで以下を設定:
     - `chatwork_token`: Chatwork API トークン
     - `chatwork_room_id`: 通知先ルームID
   - **更新** をクリック

詳細は `templates/media/chatwork/README.md` を参照してください。

## トラブルシューティング

### メディアタイプが表示されない

- **原因**: API トークンが無効
- **解決**: `ZABBIX_API_TOKEN` が正しく設定されているか確認

### モジュールエラー

`community.zabbix` collection がインストールされているか確認：

```bash
ansible-galaxy collection install community.zabbix
```

### ユーザーメディアが機能しない

1. メディアタイプが正しくインポートされているか確認
2. **管理** → **ユーザー** でユーザーにメディアが追加されているか確認
3. アクションが正しく設定されているか確認

## 参考資料

- [Zabbix メディアタイプ設定](https://www.zabbix.com/documentation/current/manual/config/notifications/media)
- [Zabbix Webhook メディアタイプ](https://www.zabbix.com/documentation/current/manual/config/notifications/media/webhook)
- [community.zabbix.zabbix_mediatype](https://docs.ansible.com/ansible/latest/collections/community/zabbix/zabbix_mediatype_module.html)
- [Chatwork Webhook README](../../../templates/media/chatwork/README.md)

## ライセンス

MIT

## 作成者

Generated with Claude Code
