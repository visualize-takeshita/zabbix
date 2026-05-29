# Zabbix Media Type Role

このロールは、Zabbix のメディアタイプを管理・自動設定するための Ansible Role です。Chatwork、Slack、Teams、Discord などのチャットツール連携を設定します。

## 機能

- Chatwork メディアタイプの自動インポート
- メディアタイプの自動構成（冪等性を保証）
- 複数のメディアタイプ対応が可能な拡張性

## 要件

- Ansible 2.9 以上
- `community.zabbix` collection
- Zabbix Server 7.4 以上（YAML インポート機能をサポート）
- 環境変数:
  - `ZABBIX_URL`: Zabbix JSON-RPC API の URL（例: http://zabbix/api_jsonrpc.php）
  - `ZABBIX_API_TOKEN`: Zabbix API 認証トークン

## ロール変数

### デフォルト変数 (defaults/main.yml)

```yaml
zabbix_media_types:
  - name: Chatwork
    enabled: true
```

メディアタイプのリストを拡張することで、複数の統合を管理できます。

## ファイル構成

```
roles/zabbix_media/
├── README.md                    # このファイル
├── defaults/
│   └── main.yml                # デフォルト変数
└── tasks/
    ├── main.yml                # メインタスク（各メディアタイプのインポート）
    └── media_type_chatwork.yml # Chatwork メディアタイプ設定
```

## 作成されるリソース

### 1. Chatwork メディアタイプ

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
  - カスタムメッセージフォーマット

詳細は `templates/media/chatwork/README.md` を参照してください。

## 使用方法

### 基本的な使用方法

```yaml
---
- hosts: zabbix
  gather_facts: no
  roles:
    - zabbix_media
```

### 実行例

```bash
# 環境変数を設定（direnv を使用する場合）
direnv allow

# Playbook を実行
ansible-playbook zabbix_media.yml
```

### Verbose オプション

```bash
# 詳細ログを出力
ansible-playbook -vv zabbix_media.yml

# チェックモード（実行せず確認）
ansible-playbook -C zabbix_media.yml
```

## 冪等性

このロールは冪等性を保つように設計されています：

- **メディアタイプの確認**: 既存のメディアタイプをチェック
- **新規作成**: メディアタイプが存在しない場合のみ作成
- **既存更新**: メディアタイプが存在する場合は更新（必要に応じて）

複数回実行しても安全で、設定は常に最新の状態に保たれます。

## カスタマイズ

### Chatwork パラメータの設定

Chatwork メディアタイプをインポート後、以下のパラメータを設定してください：

1. **Zabbix UI で設定**:
   - **管理** → **メディアタイプ** → **Chatwork** をクリック
   - **パラメータ** セクションで以下を設定:
     - `chatwork_token`: Chatwork API トークン
     - `chatwork_room_id`: 通知先ルームID
   - **更新** をクリック

2. **または Ansible 変数で設定**:
   ```yaml
   # playbook で設定
   vars:
     chatwork_api_token: "{{ lookup('env', 'CHATWORK_API_TOKEN') }}"
     chatwork_room_id: "123456789"
   ```

### 新しいメディアタイプの追加

複数のチャットツール統合を実装する場合：

1. **新規メディアタイプファイルを作成**:
   ```
   templates/media/<tool_name>/media_<tool_name>.yaml
   ```

2. **新規タスクファイルを作成**:
   ```
   roles/zabbix_media/tasks/media_type_<tool_name>.yml
   ```

3. **main.yml に import を追加**:
   ```yaml
   - name: Import <Tool> media type tasks
     ansible.builtin.import_tasks: media_type_<tool_name>.yml
   ```

## トラブルシューティング

### メディアタイプが表示されない

- **原因**: API トークンが無効
- **解決**: `ZABBIX_API_TOKEN` が正しく設定されているか確認

### インポートエラー

- **原因**: YAML ファイルのパス問題
- **解決**: `playbook_dir` が正しいかデバッグテスクで確認

```yaml
- debug:
    msg: "Playbook directory: {{ playbook_dir }}"
```

### ユーザーメディアが機能しない

1. メディアタイプが正しくインポートされているか確認
2. **管理** → **ユーザー** でユーザーにメディアが追加されているか確認
3. メディアタイプが **Enabled** になっているか確認

## 参考資料

- [Zabbix メディアタイプ設定](https://www.zabbix.com/documentation/current/manual/config/notifications/media)
- [Zabbix Configuration Import/Export](https://www.zabbix.com/documentation/current/manual/web_interface/frontend_sections/administration/general#import)
- [Zabbix Webhook メディアタイプ](https://www.zabbix.com/documentation/current/manual/config/notifications/media/webhook)

## ライセンス

MIT

## 作成者

Generated with Claude Code
