# 2026-05-29: Template Items 実装検討ログ

## 質問
`ansible/roles/zabbix_template/tasks/items.yml` で `community.zabbix.zabbix_item` を使っていない理由は何か？

## 第一次検証（間違い）
初期仮説：モジュールがパラメータをサポートしていない。
結果：不正確。モジュールは `params` ディクショナリ内にパラメータをサポートしている。

## 第二次検証（正しい理由）

### community.zabbix.zabbix_item の params 構造
モジュールのドキュメントより：
```yaml
params:
  type: zabbix_agent          # モジュール用の値
  key: agent.ping
  value_type: numeric_unsigned
  interval: 1m
  interface:
    main: true
```

### 計算式アイテムの問題
**計算式アイテム（calculated type）での失敗：**

実装時にエラーが発生：
```
'Invalid parameter "/1": unexpected parameter "formula".'
```

理由：
- Zabbix API では、計算式アイテムの場合、パラメータを `params` フィールドに直接指定
- community.zabbix.zabbix_item では、params ディクショナリ内で計算式をどのキーで指定するかが不明確
- `formula`, `params`, その他のキー名の仕様が不明確

### 値タイプの型変換
- `value_type: numeric_float` → モジュール用の適切な値に変換が必要か不明確
- JSON-RPC では明確に数値（0, 3 など）を使用

## なぜ JSON-RPC を使うのか

**理由１：計算式アイテムの仕様が不明確**
- community.zabbix.zabbix_item で計算式アイテムのパラメータ指定方法が明確でない
- Zabbix API JSON-RPC ではパラメータが明確に定義されている

**理由２：型変換の確実性**
- JSON-RPC では Zabbix API が要求する正確な型（数値など）を直接指定可能
- モジュール経由では型変換が不透明

**理由３：既存の動作実績**
- JSON-RPC 実装は既に動作確認済み
- すべてのアイテムタイプ（agent, calculated など）に対応

## テスト結果
- JSON-RPC での実装：✅ 正常に動作
- community.zabbix.zabbix_item：❌ 計算式アイテムでエラー

## 結論

**JSON-RPC 直接呼び出しが最適な選択**

理由：
1. 計算式アイテムの仕様が community.zabbix.zabbix_item で不明確
2. Zabbix API の型・パラメータ指定が明確で確実
3. 既に動作実績がある

CLAUDE.md の「3. JSON-RPC Direct Calls」パターンの妥当性が確認できた。
