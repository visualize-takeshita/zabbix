# Zabbix Media Types Role

このロールは、Chatwork と Slack の webhook メディアタイプを Zabbix に自動インポートするための Ansible Role です。

## 機能

- Chatwork webhook メディアタイプの自動インポート
- Slack webhook メディアタイプの自動インポート
- 環境変数からのトークン注入（テンプレート処理）
- `community.zabbix.zabbix_mediatype` モジュールによる冪等性の確保
- 初回のみインポート、以降はスキップ

## 要件

- Ansible 2.9 以上
- `community.zabbix` collection
- Zabbix Server 7.4 以上
- 環境変数（`.envrc` で設定）:
  - `ZABBIX_HOST`: Zabbix サーバーのホスト名または IP アドレス
  - `ZABBIX_PORT`: Zabbix API ポート（デフォルト: 80 または 443）
  - `ZABBIX_URL`: Zabbix JSON-RPC API の完全 URL
  - `ZABBIX_API_TOKEN`: Zabbix API 認証トークン
  - `CHATWORK_TOKEN`: Chatwork API トークン（オプション）
  - `SLACK_OAUTH_TOKEN`: Slack OAuth トークン（オプション、`xoxb-` で始まる）

## 環境変数の設定例

`.envrc` ファイルに以下を追加：

```bash
export ZABBIX_HOST=zabbix.example.com
export ZABBIX_PORT=80
export ZABBIX_URL=http://$ZABBIX_HOST:$ZABBIX_PORT/api_jsonrpc.php
export ZABBIX_API_TOKEN=your_zabbix_api_token_here
export CHATWORK_TOKEN=your_chatwork_token_here
export SLACK_OAUTH_TOKEN=xoxb-your-slack-token-here
```

実行時：
```bash
direnv allow
```

## ファイル構成

```
roles/zabbix_media/
├── README.md                      # このファイル
├── defaults/
│   └── main.yml                  # デフォルト変数
├── tasks/
│   ├── main.yml                  # メインタスク（両メディアタイプをインポート）
│   ├── media_type_chatwork.yml   # Chatwork メディアタイプインポート
│   └── media_type_slack.yml      # Slack メディアタイプインポート
└── templates/
    ├── media_chatwork.yaml       # Chatwork メディアタイプ定義
    └── media_slack.yaml          # Slack メディアタイプ定義（Zabbix公式）
```

## 作成されるリソース

### Chatwork メディアタイプ

**ファイル**: `templates/media_chatwork.yaml`

以下の設定を含みます：

- **タイプ**: WEBHOOK
- **パラメータ**:
  - `chatwork_token`: Chatwork API トークン（環境変数 `CHATWORK_TOKEN` から注入）
  - `chatwork_room_id`: `{ALERT.SENDTO}` マクロ（ユーザーメディア設定時に指定）
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

### Slack メディアタイプ

**ファイル**: `templates/media_slack.yaml`

以下の設定を含みます：

- **タイプ**: WEBHOOK
- **ソース**: [Zabbix 公式リポジトリ](https://git.zabbix.com/projects/ZBX/repos/zabbix/browse/templates/media/slack/media_slack.yaml?at=release%2F7.4)
- **パラメータ**:
  - `bot_token`: Slack OAuth トークン（環境変数 `SLACK_OAUTH_TOKEN` から注入）
  - `channel`: `{ALERT.SENDTO}` マクロ（ユーザーメディア設定時に指定）
  - 他多数のイベント関連パラメータ

- **機能**:
  - トリガーアラート
  - 検出（Discovery）イベント
  - 自動登録（Autoregistration）イベント
  - 内部（Internal）イベント
  - サービス（Service）イベント

**注意**: Slack メディアタイプは多くのパラメータを含みます。必要に応じて不要なパラメータは削除してください。

## 使用方法

### Playbook での使用方法

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

# Playbook を実行（Chatwork と Slack の両メディアタイプをインポート）
direnv exec . ansible-playbook zabbix_media.yml
```

### Verbose オプション

```bash
# 詳細ログを出力
direnv exec . ansible-playbook -vv zabbix_media.yml

# チェックモード（実行せず確認）
direnv exec . ansible-playbook -C zabbix_media.yml
```

## 冪等性

このロールは完全な冪等性を保ちます：

- 初回実行時のみメディアタイプをインポート
- 以降の実行ではメディアタイプの存在確認後、既に存在する場合はスキップ
- 複数回実行しても安全（2回目以降は何も変わらない）

ロジックは以下の通りです：
1. YAML ファイルからメディアタイプ設定を読み込み
2. `mediatype.get` API で既存メディアタイプを確認
3. 存在しない場合のみインポートタスク実行
4. インポート時に環境変数からトークンを注入（テンプレート処理）

## インポート後の設定

メディアタイプがインポートされた後、Zabbix UI で以下を設定してください：

### 1. ユーザーメディアの追加

メディアタイプを使用するには、Zabbix ユーザーにメディアを追加します：

1. **管理** → **ユーザー** → 対象ユーザーを選択
2. **メディア** タブ → **追加**
3. 以下を設定:
   - **タイプ**: Chatwork または Slack
   - **送信先**: 通知先の識別子（Chatwork は Room ID、Slack はチャネル名）
   - **いつ有効**: デフォルト（24x7）またはカスタム時間
   - **使用**: チェック ON
4. **更新** をクリック

### 2. アクションの設定

通知を送信するアクションを設定します：

1. **構成** → **アクション** → **トリガーアクション**
2. 新規作成または既存アクションを編集
3. **実行内容** セクションで:
   - **操作タイプ**: ユーザーに送信
   - **送信対象**: メディアを設定したユーザーを選択
   - **メッセージ**: 通知内容（マクロ使用可）
4. **更新** をクリック

詳細は Zabbix 公式ドキュメントを参照してください。

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

### Zabbix ドキュメント
- [Zabbix メディアタイプ設定](https://www.zabbix.com/documentation/current/manual/config/notifications/media)
- [Zabbix Webhook メディアタイプ](https://www.zabbix.com/documentation/current/manual/config/notifications/media/webhook)
- [Zabbix アクション設定](https://www.zabbix.com/documentation/current/manual/config/notifications/action)

### Ansible リファレンス
- [community.zabbix.zabbix_mediatype Module](https://docs.ansible.com/ansible/latest/collections/community/zabbix/zabbix_mediatype_module.html)

### 外部サービス API
- [Chatwork API ドキュメント](https://developer.chatwork.com/docs)
- [Slack API ドキュメント](https://api.slack.com/docs)

### 実装ドキュメント
- [Media Type Integration Thought Log](../../docs/thought_log_20260529_media_type.md)

## ライセンス

MIT

## 作成者

Generated with Claude Code
