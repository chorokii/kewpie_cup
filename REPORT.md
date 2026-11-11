# 開発報告書: HPゲージ（ヘルスバー）の減少方向を「外側から中央へ向かって減る」方式（スト2方式）へ修正

## 1. 概要
- 1P側のHPゲージが中央から外側に向かって減っていた不具合の原因（`Stack` 直下の `FractionallySizedBox` における `alignment` の仕様上の無効化）を特定し、1P・2Pともに画面外側から中央（タイマー側）に向かって減るストリートファイター2方式へ修正しました。

---

## 2. 実施内容
- `lib/widgets/fighting_hud.dart`:
  - `_buildHealthBar` において、`Positioned.fill` 内に `Align(alignment: healthAlignment)` を配置し、その子として `FractionallySizedBox(widthFactor: clampedRatio, heightFactor: 1.0)` を配置する構造へ修正。
  - 1P（`isFlipped: false`）は黄色バーが右端（中央タイマー側）に固定されて左端（外側）から減り、2P（`isFlipped: true`）は黄色バーが左端（中央タイマー側）に固定されて右端（外側）から減る動作を確立。
- `test/widget_test.dart`:
  - 1Pおよび2PのHPを50%にした際の描画矩形（`Rect`）を取得し、外側から減少していることを検証するウィジェットテストを追加。

---

## 3. 修正ファイル一覧
1. `lib/widgets/fighting_hud.dart`
2. `test/widget_test.dart`

---

## 4. 検証結果

### flutter analyze の実行結果
```bash
Analyzing kewpie_cup...
No issues found! (ran in 1.8s)
```

### flutter test の実行結果
```bash
00:03 +32: All tests passed!
```
