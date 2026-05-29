# Zabbix Chatwork Webhook Media Type

このドキュメントでは、Zabbix 7.4 の Chatwork Webhook メディアタイプの設定と使用方法を説明します。

## 概要

Chatwork メディアタイプは、Zabbix のアラート通知を Chatwork のチャットルームに送信するための Webhook 統合です。このメディアタイプにより、Zabbix で検出された問題や重大なイベントを Chatwork 経由でリアルタイムに通知できます。

## 機能

- **複数のイベントソース対応**: Triggers（トリガー）、Discovery（検出）、Auto-registration（自動登録）、Internal（内部）、Service（サービス）のイベント対応
- **イベント状態の自動判定**: PROBLEM（問題）、RECOVERY（回復）、UPDATE（更新）の状態を自動判定
- **カスタマイズ可能なメッセージフォーマット**: `[info][title]...[/title]...[/info]` 形式での Chatwork 独自メッセージ表示
- **パラメータ検証**: Chatwork トークンとルームID の必須チェック
- **エラーハンドリング**: API エラーやネットワークエラーの詳細ログ出力

## 前提条件

- Zabbix Server 7.4 以上
- Chatwork アカウント（ユーザー権限以上）
- Chatwork API トークン
- Chatwork チャットルーム

## Chatwork の準備

### 1. API トークンの取得

1. Chatwork Web にログイン
2. 右上のユーザー名をクリック → **各種設定** → **API トークン**
3. トークンを表示・コピー（このトークンは後でZabbixに設定します）

**重要**: API トークンは外部に公開しないでください。トークンを他人と共有しないこと。

### 2. ルームID の確認

Chatwork ではルームごとに一意の ID が割り当てられています。ルームID は以下の方法で確認できます。

**方法1: URL から確認**
- Chatwork Web でルームを開く
- URL の `rid=` 以降の数字がルームID
- 例: `https://www.chatwork.com/...#!rid=123456789` → ルームID は `123456789`

**方法2: API で確認**
```bash
curl -X GET https://api.chatwork.com/v2/rooms \
  -H "X-ChatWorkToken: YOUR_API_TOKEN"
```

## Zabbix での設定

### 1. メディアタイプのインポート

`media_chatwork.yaml` をZabbix にインポートします。

**GUI での方法:**
1. Zabbix Web → **管理** → **メディアタイプ**
2. **メディアタイプをインポート** → `media_chatwork.yaml` を選択
3. インポート完了

**Ansible での方法:**
```bash
direnv exec . ansible-playbook zabbix_media.yml
```

### 2. メディアタイプのパラメータ設定

インポート後、メディアタイプを編集してパラメータを設定します。

1. **管理** → **メディアタイプ** → **Chatwork** をクリック
2. 以下のパラメータを設定:
   - **chatwork_token**: 手順1で取得した API トークン
   - **chatwork_room_id**: 手順2で確認したルームID

その他のパラメータ（alert_subject、alert_message など）はデフォルトのままで問題ありません。

### 3. ユーザーメディアの設定

Zabbix ユーザーに Chatwork メディアを追加します。

1. **管理** → **ユーザー** → 対象ユーザーを選択
2. **メディア** タブを開く
3. **追加** をクリック
4. 以下を設定:
   - **タイプ**: Chatwork
   - **送信先**: `chatwork` または任意の識別子
   - **いつ有効**: デフォルト（24x7）またはカスタム時間
   - **使用**: チェック ON

保存して設定完了です。

## アクション（自動通知）の設定

メディアタイプが設定されたら、アクションを通じて自動通知を設定します。

### トリガーアラートの自動通知

1. **構成** → **アクション** → **トリガーアクション** をクリック
2. 新しいアクションを作成または既存アクションを編集
3. **実行内容** → **アクション操作** → **新規追加**
4. **実行操作の詳細**:
   - **操作タイプ**: ユーザーに送信
   - **送信対象**: Chatwork メディアを設定したユーザーを選択
   - **メッセージ**:
     ```
     Problem: {TRIGGER.NAME}
     Severity: {TRIGGER.SEVERITY}
     Status: {TRIGGER.STATUS}
     ```

5. 保存

### 回復（RECOVERY）のアクション

1. 上記と同じ手順でアクションを編集
2. **実行条件** → **カスタム式** を設定:
   ```
   {TRIGGER.VALUE}=0
   ```
3. **実行内容** → **アクション操作**:
   ```
   Recovery: {TRIGGER.NAME}
   Status: RECOVERED
   ```

## テスト

### 1. テストメッセージの送信

Chatwork メディアタイプがインポートされたら、テストメッセージを送信できます。

1. **管理** → **メディアタイプ** → **Chatwork** → **テスト**
2. パラメータが自動入力されていることを確認
3. **送信** をクリック

成功すると、Chatwork のルームに以下の形式のメッセージが届きます:
```
[info][title]Test notification[/title]This is a test of Chatwork webhook[/info]
```

### 2. トリガーイベントでのテスト

実際のトリガーイベントで通知をテストします。

**方法1: Zabbix コマンドラインから**
```bash
# トリガーの状態を PROBLEM に変更してテスト
zabbix_sender -z zabbix_server -s test_host -k trigger.key -o 1
```

**方法2: UI から手動でトリガーを発生させる**
1. **監視データ** → **アイテム** でテスト用アイテムを作成
2. **構成** → **ホスト** でトリガーを作成
3. Zabbix Agent を通じて値を送信

### 3. ログの確認

メディアタイプのテストログで詳細な実行結果を確認できます。

1. **管理** → **メディアタイプ** → **Chatwork** → **最新データ** タブ
2. ログで送信状況を確認

## トラブルシューティング

### メッセージが送信されない

**原因1: API トークンが無効**
- 解決: `chatwork_token` が正しく設定されているか確認
- Chatwork Web で API トークンをリセットしていないか確認

**原因2: ルームID が無効**
- 解決: ルームID が数字のみで正しく指定されているか確認
- API で確認: `curl -X GET https://api.chatwork.com/v2/rooms -H "X-ChatWorkToken: TOKEN"`

**原因3: ネットワーク接続**
- 解決: Zabbix Server から Chatwork API(`api.chatwork.com`) へ HTTPS (443) でアクセス可能か確認

### メッセージが文字化けしている

- Chatwork メッセージフォーマット（`[info][title]...[/title]...[/info]`）を使用しているため、テキストのみの表示です
- 特殊文字が含まれる場合は、Zabbix の設定でエスケープしてください

### ユーザーが通知を受け取らない

1. ユーザーに Chatwork メディアが正しく設定されているか確認
2. アクションの条件を確認（特に **実行条件** のカスタム式）
3. **管理** → **メディアタイプ** で `enabled` が ON になっているか確認

## メッセージ形式

Chatwork では以下の形式で通知が送信されます。

### トリガーアラート（PROBLEM）
```
[info][title]Alert: {TRIGGER.NAME}[/title]
Severity: {TRIGGER.SEVERITY}
Host: {HOST.NAME}
Time: {EVENT.TIME}[/info]
```

### 回復（RECOVERY）
```
[info][title]Recovered: {TRIGGER.NAME}[/title]
Status: RECOVERED
Host: {HOST.NAME}
Time: {EVENT.TIME}[/info]
```

### 更新（UPDATE）
```
[info][title]Update: {TRIGGER.NAME}[/title]
Previous Severity: {EVENT.SEVERITY}
Current Severity: {EVENT.UPDATE.SEVERITY}
Host: {HOST.NAME}
Time: {EVENT.TIME}[/info]
```

## パラメータリファレンス

| パラメータ | 説明 | 必須 | デフォルト値 |
|-----------|------|------|------------|
| chatwork_token | Chatwork API トークン | ○ | - |
| chatwork_room_id | Chatwork ルームID | ○ | - |
| alert_subject | アラート件名 | - | {ALERT.SUBJECT} |
| alert_message | アラートメッセージ | - | {ALERT.MESSAGE} |
| event_source | イベントソース (0:Trigger, 1:Discovery, 2:Autoregistration, 3:Internal, 4:Service) | - | {EVENT.SOURCE} |
| event_value | イベント値 (0:OK, 1:PROBLEM) | - | {EVENT.VALUE} |
| event_severity | イベント重要度テキスト | - | {EVENT.SEVERITY} |
| event_nseverity | イベント重要度番号 | - | {EVENT.NSEVERITY} |
| event_tags | イベントタグ (JSON形式) | - | {EVENT.TAGSJSON} |

## セキュリティに関する注意

1. **API トークンの管理**:
   - API トークンは秘匿情報として扱ってください
   - Git リポジトリに含めないこと（`.gitignore` で除外）
   - 定期的にトークンをローテーションしてください

2. **ネットワークセキュリティ**:
   - Zabbix Server から Chatwork API への通信は HTTPS で暗号化されます
   - ファイアウォールで HTTPS (443) へのアウトバウンドアクセスを許可してください

3. **アクセス制御**:
   - Chatwork ルームへのアクセス権を適切に管理してください
   - 通知を受け取るべきユーザーのみをメディア設定に追加してください

## 参考資料

- [Chatwork API ドキュメント](https://developer.chatwork.com/docs)
- [Zabbix メディアタイプ設定](https://www.zabbix.com/documentation/current/manual/config/notifications/media)
- [Zabbix Webhook](https://www.zabbix.com/documentation/current/manual/config/notifications/media/webhook)

## ライセンス

MIT

## 作成者

Generated with Claude Code
