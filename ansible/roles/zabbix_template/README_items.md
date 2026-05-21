# Template Items 仕様書

このドキュメントでは、`zabbix_template` ロールで作成される Template Items の仕様を説明します。

## 概要

Template Items は、テンプレートに関連付けられた監視項目（アイテム）です。このロールでは、基本的なシステム監視項目を自動的に作成します。

## 実装方法

### JSON-RPC による直接作成

`community.zabbix.zabbix_item` モジュールでは Calculated item の `params` パラメータの扱いが複雑なため、Zabbix JSON-RPC API を直接使用して items を作成しています。

**ファイル**: `tasks/items.yml`

**メソッド**: `item.create`

**特徴**:
- Calculated item と Zabbix agent item を自動判別
- 冪等性対応（既に存在する場合はエラーを無視）
- Template ID を動的に取得して使用

## 作成される Items

### 1. CPU Load 1min
Linux システムの 1分間の平均 CPU 負荷を監視します。

| 項目 | 値 |
|------|-----|
| **名前** | CPU Load 1min |
| **Key** | `system.cpu.load[all,avg1]` |
| **Type** | Zabbix agent |
| **Value type** | Numeric (float) |
| **更新間隔** | 60s |

**説明**: システム全体の 1分間平均ロードアベレージを取得します。値が高い場合、CPU が過負荷状態にある可能性があります。

### 2. Memory usage %
メモリ使用率をパーセンテージで表示します（Calculated item）。

| 項目 | 値 |
|------|-----|
| **名前** | Memory usage % |
| **Key** | `memory.usage.percent` |
| **Type** | Calculated |
| **Value type** | Numeric (float) |
| **単位** | % |
| **計算式** | `100 - last(//vm.memory.size[pavailable])` |
| **更新間隔** | 60s |

**説明**:
- 利用可能なメモリのパーセンテージ（`vm.memory.size[pavailable]`）を取得し、100 から引くことで使用率を算出
- Zabbix agent の `vm.memory.utilization` は存在しないため、calculated item として実装
- リアルタイムでメモリ使用状況を把握できる

**計算式の詳細**:
- `vm.memory.size[pavailable]`: 利用可能なメモリの割合（%）
- `100 - pavailable`: 使用中のメモリの割合（%）

### 3. Root FS usage
ルートファイルシステム（/）のディスク使用率を監視します。

| 項目 | 値 |
|------|-----|
| **名前** | Root FS usage |
| **Key** | `vfs.fs.size[/,pused]` |
| **Type** | Zabbix agent |
| **Value type** | Numeric (float) |
| **更新間隔** | 300s (5分) |

**説明**: ルートパーティションのディスク使用率（%）を取得します。

**注意**:
- このアイテムはルートパーティション専用です
- その他のファイルシステムは LLD (Low-Level Discovery) で自動的に監視されます（README.md 参照）

### 4. Agent ping
Zabbix agent の可用性を確認します。

| 項目 | 値 |
|------|-----|
| **名前** | Agent ping |
| **Key** | `agent.ping` |
| **Type** | Zabbix agent |
| **Value type** | Numeric (unsigned) |
| **更新間隔** | 60s |

**説明**:
- Zabbix agent が応答しているかを確認
- 値: 1 = 正常, 0 = 応答なし

### 5. System uptime
システムの稼働時間を監視します。

| 項目 | 値 |
|------|-----|
| **名前** | System uptime |
| **Key** | `system.uptime` |
| **Type** | Zabbix agent |
| **Value type** | Numeric (unsigned) |
| **更新間隔** | 1h |

**説明**: システムが起動してからの経過時間（秒）を取得します。

## 変数定義

Items は `defaults/main.yml` で定義されています。

```yaml
zabbix_items:
  - name: CPU Load 1min
    key: system.cpu.load[all,avg1]
    value_type: numeric_float
    interval: 60s

  - name: Memory usage %
    type: calculated
    key: memory.usage.percent
    value_type: numeric_float
    units: '%'
    params: '100 - last(//vm.memory.size[pavailable])'
    interval: 60s

  - name: Root FS usage
    key: vfs.fs.size[/,pused]
    value_type: numeric_float
    interval: 300s

  - name: Agent ping
    key: agent.ping
    value_type: numeric_unsigned
    interval: 60s

  - name: System uptime
    key: system.uptime
    value_type: numeric_unsigned
    interval: 1h
```

### 変数パラメータ

| パラメータ | 必須 | 説明 | 例 |
|-----------|------|------|-----|
| `name` | ○ | アイテム名 | `CPU Load 1min` |
| `key` | ○ | Zabbix item key | `system.cpu.load[all,avg1]` |
| `value_type` | ○ | 値の型 | `numeric_float`, `numeric_unsigned` |
| `interval` | ○ | 更新間隔 | `60s`, `5m`, `1h` |
| `type` | - | アイテムタイプ | `calculated` (デフォルト: Zabbix agent) |
| `units` | - | 単位 | `%`, `B`, `bps` |
| `params` | - | Calculated item の計算式 | `100 - last(//vm.memory.size[pavailable])` |

### Zabbix API での値マッピング

JSON-RPC API では以下の数値を使用します：

**Type**:
- `0`: Zabbix agent
- `15`: Calculated

**Value type**:
- `0`: Numeric (float)
- `3`: Numeric (unsigned)

## カスタマイズ

### 既存アイテムの変更

`defaults/main.yml` の `zabbix_items` リストを編集：

```yaml
zabbix_items:
  - name: CPU Load 1min
    key: system.cpu.load[all,avg1]
    value_type: numeric_float
    interval: 30s  # 60s → 30s に変更
```

### 新しいアイテムの追加

#### Zabbix agent item の追加

```yaml
zabbix_items:
  # 既存アイテム...

  - name: Network traffic in eth0
    key: net.if.in[eth0]
    value_type: numeric_unsigned
    interval: 60s
    units: 'bps'
```

#### Calculated item の追加

```yaml
zabbix_items:
  # 既存アイテム...

  - name: Memory usage bytes
    type: calculated
    key: memory.usage.bytes
    value_type: numeric_unsigned
    units: 'B'
    params: 'last(//vm.memory.size[total]) - last(//vm.memory.size[available])'
    interval: 60s
```

### アイテムの削除

`zabbix_items` リストから該当するアイテムを削除してください。

**注意**: Playbook を実行しても、既存のアイテムは Zabbix から削除されません。手動で削除するか、`state: absent` を使った削除タスクを追加する必要があります。

## 実装の詳細

### JSON-RPC による作成処理

`tasks/items.yml` では以下の処理を行っています：

1. **Type の判別**:
   ```jinja2
   'type': 15 if item.type | default('') == 'calculated' else 0
   ```
   - `type: calculated` が定義されている場合は 15（Calculated）
   - それ以外は 0（Zabbix agent）

2. **Value type の変換**:
   ```jinja2
   'value_type': 0 if item.value_type == 'numeric_float' else 3
   ```
   - `numeric_float` → 0
   - `numeric_unsigned` → 3

3. **オプションパラメータの処理**:
   ```jinja2
   | combine({'units': item.units} if item.units is defined else {})
   | combine({'params': item.params} if item.params is defined else {})
   ```
   - `units` と `params` は定義されている場合のみ含める

4. **冪等性の確保**:
   ```yaml
   failed_when:
     - items_result.json.error is defined
     - items_result.json.error.data is not search("already exists")
   ```
   - "already exists" エラーは無視
   - 既に存在するアイテムは再作成しない

### Loop 処理

```yaml
loop: "{{ zabbix_items }}"
loop_control:
  extended: yes
```

- `zabbix_items` リストの各要素に対して item.create を実行
- `extended: yes` により `ansible_loop.index0` が利用可能
- 各リクエストに一意の ID (`10 + index`) を割り当て

## トラブルシューティング

### Calculated item が作成されない

**問題**: Calculated item のエラーが出る

**解決策**:
1. `params` の式が正しいか確認
2. 依存する item key が存在するか確認（例: `vm.memory.size[pavailable]`）
3. Zabbix agent がサポートしている key か確認

### Item が重複作成される

**問題**: 同じ item が複数回作成されようとする

**解決策**:
- Item の `key` が一意であることを確認
- 既存の item と key が重複していないか Zabbix UI で確認

### 更新間隔のフォーマットエラー

**問題**: `interval` の値が不正

**解決策**:
- Zabbix でサポートされている形式を使用:
  - 秒: `60s`, `300s`
  - 分: `5m`, `30m`
  - 時: `1h`, `24h`
  - 日: `1d`

## 関連ドキュメント

- [メインドキュメント](README.md): テンプレート全体の仕様
- [Zabbix Item Types](https://www.zabbix.com/documentation/current/manual/config/items/itemtypes): Zabbix の item type 一覧
- [Calculated Items](https://www.zabbix.com/documentation/current/manual/config/items/itemtypes/calculated): Calculated item の詳細
- [Zabbix API - item.create](https://www.zabbix.com/documentation/current/manual/api/reference/item/create): API リファレンス

## 参考: Zabbix Agent でサポートされる主な Key

### システム
- `system.cpu.load[<cpu>,<mode>]`: CPU 負荷
- `system.uptime`: 稼働時間
- `system.hostname`: ホスト名

### メモリ
- `vm.memory.size[<mode>]`: メモリサイズ
  - `total`: 総メモリ
  - `available`: 利用可能メモリ
  - `pavailable`: 利用可能メモリ（%）

### ディスク
- `vfs.fs.size[<fs>,<mode>]`: ファイルシステムサイズ
  - `total`: 総容量
  - `used`: 使用量
  - `pfree`: 空き容量（%）
  - `pused`: 使用量（%）

### ネットワーク
- `net.if.in[<if>,<mode>]`: 受信トラフィック
- `net.if.out[<if>,<mode>]`: 送信トラフィック

## ライセンス

MIT
