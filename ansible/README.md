# Zabbix Ansible Playbooks

Zabbix 監視インフラを自動化するための Ansible Playbook コレクションです。Zabbix HTTP API を使用して、テンプレート、ユーザー、プロキシ、ホストグループ、自動化アクションなどのリソースを作成・管理します。

## 概要

このプロジェクトは、`community.zabbix` collection を使用して Zabbix を Infrastructure as Code で管理するための Playbook 群です。SSH 接続ではなく、HTTP API (httpapi connection) を使用して Zabbix Server と通信します。

## アーキテクチャ

### 接続モデル
- **httpapi 接続**: SSH ではなく、Zabbix HTTP API 経由で接続
- **トークンベース認証**: API トークンを使用した認証
- **環境変数管理**: 認証情報は環境変数で管理（direnv 推奨）

### プロジェクト構成

```
zabbix/ansible/
├── README.md                    # このファイル
├── CLAUDE.md                    # Claude Code 向けガイド
├── ansible.cfg                  # Ansible 設定
├── hosts                        # インベントリファイル
├── .envrc                       # direnv 設定（環境変数管理）
├── roles/                       # Ansible ロール
│   ├── zabbix_template/        # テンプレート管理
│   ├── zabbix_user/            # ユーザー管理
│   ├── zabbix_action/          # 自動化アクション管理
│   ├── zabbix_proxy/           # プロキシ管理
│   └── zabbix_hostgroup/       # ホストグループ管理
└── *.yml                        # Playbook ファイル

```

## 前提条件

### 必要なソフトウェア
- **Ansible**: 2.9 以上
- **Python**: 3.8 以上
- **community.zabbix collection**: インストール済み
- **direnv**: （推奨）環境変数管理用

### Zabbix 要件
- Zabbix Server 6.0 以上
- API トークン認証が有効化されていること

## セットアップ

### 1. direnv のセットアップ

```bash
# プロジェクトディレクトリに移動
cd /path/to/zabbix/ansible

# direnv を許可
direnv allow
```

### 2. 環境変数の設定

`.envrc` ファイルに以下の環境変数を設定：

```bash
export ZABBIX_HOST="zabbix.example.com"
export ZABBIX_PORT="80"
export ZABBIX_API_TOKEN="your-api-token-here"
export ZABBIX_URL="http://zabbix.example.com/api_jsonrpc.php"
```

### 3. 依存関係のインストール

```bash
# community.zabbix collection のインストール
ansible-galaxy collection install community.zabbix

# Python 依存関係のインストール（direnv が自動的に処理）
```

## 利用可能な Playbook

### zabbix_template.yml
Zabbix テンプレートを作成・管理します。

**機能:**
- テンプレート作成
- ユーザーマクロ定義
- LLD（Low-Level Discovery）ルール作成
- Item Prototype および Trigger Prototype の作成
- ファイルシステム自動監視の設定

**実行例:**
```bash
direnv exec . ansible-playbook zabbix_template.yml
```

詳細: [roles/zabbix_template/README.md](roles/zabbix_template/README.md)

### zabbix_user.yml
Zabbix ユーザーとロールを管理します。

**機能:**
- デフォルトユーザー（Admin/Guest）の無効化
- Zabbix Server ホスト設定の更新

**実行例:**
```bash
direnv exec . ansible-playbook zabbix_user.yml
```

### zabbix_action.yml
自動化アクションを作成します。

**機能:**
- 自動登録アクション
- メタデータベースのホスト登録
- テンプレート/グループの自動割り当て

**実行例:**
```bash
direnv exec . ansible-playbook zabbix_action.yml
```

## 共通コマンド

### Playbook の実行

```bash
# 基本実行
direnv exec . ansible-playbook <playbook>.yml

# 構文チェック
ansible-playbook --syntax-check <playbook>.yml

# ドライラン（変更なし）
ansible-playbook -C <playbook>.yml

# 詳細出力
ansible-playbook -vv <playbook>.yml
```

### インベントリの確認

```bash
# ホスト一覧
ansible-inventory --list

# 特定ホストの変数確認
ansible-inventory --host zabbix
```

## 開発

### 新しいロールの追加

1. ロールディレクトリを作成:
   ```bash
   mkdir -p roles/zabbix_<resource>/tasks
   mkdir -p roles/zabbix_<resource>/defaults
   ```

2. `roles/zabbix_<resource>/tasks/main.yml` を作成

3. オプションで `roles/zabbix_<resource>/defaults/main.yml` に変数を定義

4. リポジトリルートに Playbook を作成:
   ```yaml
   ---
   - hosts: zabbix
     gather_facts: no
     roles:
       - zabbix_<resource>
   ```

### 重要なパターン

- **Fact gathering なし**: すべての Playbook で `gather_facts: no`（httpapi 接続のため）
- **環境変数の参照**: `{{ lookup('env', 'VARIABLE_NAME') }}`
- **冪等性**: 変更前の状態を確認してから更新
- **JSON-RPC 直接呼び出し**: モジュールでサポートされていない機能は `uri` モジュールで API 直接呼び出し

## トラブルシューティング

### 環境変数が読み込まれない

```bash
# direnv のステータス確認
direnv status

# 再読み込み
direnv allow
```

### API 接続エラー

```bash
# Zabbix URL の確認
echo $ZABBIX_URL

# トークンの確認（一部をマスク）
echo $ZABBIX_API_TOKEN | cut -c1-10

# 接続テスト
curl -X POST "$ZABBIX_URL" \
  -H "Content-Type: application/json-rpc" \
  -H "Authorization: Bearer $ZABBIX_API_TOKEN" \
  -d '{"jsonrpc":"2.0","method":"apiinfo.version","params":{},"id":1}'
```

### Playbook が失敗する

```bash
# 詳細ログで実行
ansible-playbook -vvv <playbook>.yml

# 特定タスクから実行
ansible-playbook <playbook>.yml --start-at-task="task name"

# タグを使用して特定タスクのみ実行（タグが設定されている場合）
ansible-playbook <playbook>.yml --tags "tag_name"
```

## ベストプラクティス

1. **環境変数の管理**: direnv を使用して認証情報を管理
2. **冪等性の確保**: 同じ Playbook を複数回実行しても同じ結果になるように設計
3. **変更前の確認**: `-C` オプションでドライランを実行
4. **バージョン管理**: 重要な変更前に git commit
5. **ドキュメント**: 各ロールに README.md を作成

## 参考資料

- [Zabbix API Documentation](https://www.zabbix.com/documentation/current/manual/api)
- [Ansible httpapi Connection Plugin](https://docs.ansible.com/ansible/latest/plugins/connection/httpapi.html)
- [community.zabbix Collection](https://docs.ansible.com/ansible/latest/collections/community/zabbix/)
- [direnv Documentation](https://direnv.net/)

## ライセンス

MIT

## 貢献

Issue や Pull Request を歓迎します。

## 作成者

Generated with Claude Code
