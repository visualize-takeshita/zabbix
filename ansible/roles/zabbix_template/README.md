# Zabbix Template Role

このロールは、Zabbix のテンプレートを自動作成・管理するための Ansible Role です。ファイルシステム監視のための LLD (Low-Level Discovery) と Item/Trigger Prototype を含むテンプレートを作成します。

## 機能

- Zabbix テンプレートの作成
- ユーザーマクロの定義
- テンプレートアイテムの作成（CPU、メモリ、ディスク など）
- 計算式アイテムの作成（メモリ使用率の自動計算）
- トリガーの自動作成
- ファイルシステム自動検出（LLD）の設定
- ファイルシステムフィルタの設定（特定のマウントポイントを除外）
- ディスク使用率監視アイテムの自動作成
- ディスク使用率アラートトリガーの自動作成

## 要件

- Ansible 2.9 以上
- `community.zabbix` collection
- Zabbix Server 6.0 以上（API トークン認証をサポートするバージョン）
- 環境変数:
  - `ZABBIX_URL`: Zabbix API の URL（例: http://zabbix/api_jsonrpc.php）
  - `ZABBIX_API_TOKEN`: Zabbix API 認証トークン

## ロール変数

### デフォルト変数 (defaults/main.yml)

```yaml
zabbix_template_name: "Linux minimal"
zabbix_template_group: "Templates/Operating systems"
```

### テンプレートで定義されるマクロ

| マクロ名 | デフォルト値 | 説明 |
|---------|------------|------|
| `{$DISK_USAGE_THRESHOLD}` | 90 | ディスク使用率アラートの閾値（%） |
| `{$CPU_LOAD_THRESHOLD}` | 10 | CPU 負荷アラートの閾値 |

これらのマクロは、ホスト個別またはテンプレートレベルで上書き可能です。

## ファイル構成

```
roles/zabbix_template/
├── README.md                    # このファイル
├── defaults/
│   └── main.yml                # デフォルト変数
└── tasks/
    ├── main.yml                # メインタスク（テンプレート作成と各タスクの import）
    ├── macros.yml              # Template Macros 作成・更新
    ├── items.yml               # Template Items 作成
    ├── triggers.yml            # Template Triggers 作成
    ├── discovery.yml           # Discovery Rule 作成とフィルタ設定
    ├── itemprototype.yml       # Item Prototype 作成
    └── triggerprototype.yml    # Trigger Prototype 作成
```

## 作成されるリソース

### 1. Template（テンプレート）
- **名前**: `Linux minimal`（変数で変更可能）
- **グループ**: `Templates/Operating systems`
- **マクロ**: `{$DISK_USAGE_THRESHOLD}` = 90

### 2. Discovery Rule（自動検出ルール）
- **名前**: `df`
- **Key**: `vfs.fs.discovery`
- **間隔**: 1時間
- **フィルタ条件**:
  - マクロ: `{#FSNAME}`
  - 値: `^/$|^/var/lib/mysql$|^/var/sy$|^/backup$`
  - 演算子: `NOT_MATCHES_REGEX`（正規表現に一致しない）
  - 評価タイプ: AND/OR expression

このフィルタにより、以下のマウントポイントは監視から除外されます：
- `/` (ルートパーティション)
- `/var/lib/mysql`
- `/var/sy`
- `/backup`

### 3. Template Items（テンプレートアイテム）

テンプレートレベルで定義される基本的な監視アイテム：

#### 基本アイテム
- **CPU Load 1min**: `system.cpu.load[all,avg1]` - 1分間の平均 CPU 負荷
- **Memory available %**: `vm.memory.size[pavailable]` - 利用可能なメモリ（%）、5分間隔
- **Root FS usage**: `vfs.fs.size[/,pused]` - ルートファイルシステムの使用率
- **Agent ping**: `agent.ping` - Zabbix Agent の応答確認
- **System uptime**: `system.uptime` - システムの稼働時間

#### 計算式アイテム
- **Memory usage %**: `memory.usage.percent`
  - **タイプ**: 計算式（Calculated）
  - **計算式**: `100 - last(/{HOST.HOST}/vm.memory.size[pavailable])`
  - **説明**: Memory available % を基に使用率を計算
  - **注意**: Memory available % アイテムが存在してデータを収集している必要があります

#### 実装例
`community.zabbix.zabbix_item` モジュールを使用：
```yaml
- name: メモリ使用率の計算アイテムを作成
  community.zabbix.zabbix_item:
    name: "Memory usage %"
    template_name: "{{ zabbix_template_name }}"
    state: present
    params:
      type: "calculated"
      key: "memory.usage.percent"
      value_type: "numeric_float"
      units: "%"
      interval: "1m"
      params: "100 - last(/{HOST.HOST}/vm.memory.size[pavailable])"
```

**重要**: 計算式は `params` ディクショナリ内の `params` キーに指定します。

### 4. Item Prototype（アイテムプロトタイプ）
- **名前**: `{#FSNAME}:Used space`
- **Key**: `vfs.fs.size[{#FSNAME},pused]`
- **タイプ**: Zabbix agent
- **値の型**: Numeric (unsigned)
- **更新間隔**: 5分

自動検出された各ファイルシステムに対して、使用率（%）を監視するアイテムが自動生成されます。

### 5. Trigger Prototype（トリガープロトタイプ）
- **名前**: `Disk usage is more than {$DISK_USAGE_THRESHOLD}% on volume {#FSNAME}`
- **式**: `last(/Linux minimal/vfs.fs.size[{#FSNAME},pused])>{$DISK_USAGE_THRESHOLD}`
- **深刻度**: Warning
- **説明**: ディスク使用率が閾値を超えた場合にアラートを発報

## 使用方法

### 基本的な使用方法

```yaml
---
- hosts: zabbix
  gather_facts: no
  roles:
    - zabbix_template
```

### カスタム変数を使用

```yaml
---
- hosts: zabbix
  gather_facts: no
  roles:
    - role: zabbix_template
      vars:
        zabbix_template_name: "Custom Linux Template"
        zabbix_template_group: "Templates/Custom"
```

### 実行例

```bash
# 環境変数を設定（direnv を使用する場合）
direnv allow

# Playbook を実行
ansible-playbook zabbix_template.yml
```

## 冪等性

このロールは冪等性を保つように設計されています：

- **Discovery Rule Filter**: 現在の設定を取得し、変更が必要な場合のみ更新します
- **Item Prototype**: 既に存在する場合はエラーを無視します
- **Trigger Prototype**: Zabbix モジュールが自動的に冪等性を保証します

## カスタマイズ

### ディスク使用率の閾値を変更

#### テンプレートレベルで変更
Zabbix UI で:
1. Configuration → Templates
2. 対象テンプレート → Macros
3. `{$DISK_USAGE_THRESHOLD}` の値を変更（例: 80）

#### ホストレベルで変更
Zabbix UI で:
1. Configuration → Hosts
2. 対象ホスト → Macros
3. `{$DISK_USAGE_THRESHOLD}` を追加して値を設定

### フィルタ条件の変更

`tasks/discovery.yml` の以下の部分を編集：

```yaml
filter:
  evaltype: 0
  conditions:
    - macro: "{{ '{#FSNAME}' }}"
      value: "^/$|^/var/lib/mysql$|^/var/sy$|^/backup$"
      operator: 8
```

`value` に除外したいマウントポイントの正規表現を指定します。

## トラブルシューティング

### 環境変数が読み込まれない
direnv を使用している場合は、以下を確認：
```bash
direnv allow
direnv exec . ansible-playbook zabbix_template.yml
```

### API トークンのエラー
- `ZABBIX_API_TOKEN` が正しく設定されているか確認
- トークンの有効期限が切れていないか確認

### Item Prototype が作成されない
- Discovery Rule が正しく作成されているか確認
- `discoveryrule_result.result[0].itemids[0]` のパスが正しいか確認（デバッグタスクを有効化）

## 参考資料

- [Zabbix API Documentation](https://www.zabbix.com/documentation/current/manual/api)
- [Low-Level Discovery](https://www.zabbix.com/documentation/current/manual/discovery/low_level_discovery)
- [community.zabbix Collection](https://docs.ansible.com/ansible/latest/collections/community/zabbix/)

## ライセンス

MIT

## 作成者

Generated with Claude Code
