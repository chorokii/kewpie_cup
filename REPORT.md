# 開発報告書: 1本獲得に必要なヒット数を4回から3回へ変更（打突ダメージ34.0）

## 1. 概要
- 試合のテンポを最適化するため、1本を獲得するために必要な有効打の回数を4回（1撃25.0ダメージ）から3回（1撃34.0ダメージ）へ変更しました。

---

## 2. 実施内容
- `lib/game/kendo_game.dart`:
  - `static const double strikeDamage = 34.0;` を追加し、`_checkAttack` におけるプレイヤーおよびCPUの打突ダメージを `25.0` から `34.0`（`100.0 -> 66.0 -> 32.0 -> 0.0`）に変更。
- `CURRENT_CONTEXT.md`:
  - 打突ダメージに関する記載を `34.0`（3回ヒットで1本）に更新。
- `test/widget_test.dart`:
  - 3回のヒットで体力が0になり1本判定となることを検証するユニットテストへ更新。

---

## 3. 修正ファイル一覧
1. `lib/game/kendo_game.dart`
2. `CURRENT_CONTEXT.md`
3. `test/widget_test.dart`

---

## 4. 検証結果

### flutter analyze の実行結果
```bash
Analyzing kewpie_cup...
No issues found! (ran in 2.1s)
```

### flutter test の実行結果
```bash
00:03 +31: All tests passed!
```
