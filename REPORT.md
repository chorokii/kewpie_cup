# 開発報告書: 鍔迫り合い時の「突き飛ばし」アクションの連続移動化（後退速度の1.5倍）

## 1. 概要
- 鍔迫り合い中の攻撃ダブルタップによる「突き飛ばし」時に相手キャラクターがステージ端へワープして見える問題を修正しました。
- 通常の離脱（後退）速度（`320.0` px/s）の1.5倍（`480.0` px/s）の速度でステージ端まで連続的に移動・アニメーション描画されるように変更しました。

---

## 2. 実施内容
- `lib/game/components/kendo_fighter.dart`:
  - `isPushedBack`、`pushBackTargetX`、および `pushBackSpeed = disengageSpeed * 1.5`（`480.0`）を追加。
  - `startPushBack({required double targetX})` メソッドを実装し、`update(double dt)` 内で目標座標（ステージ端）に到達するまで毎フレーム移動・描画するよう修正。
- `lib/game/kendo_game.dart`:
  - `attackP1` 内の鍔迫り合いルール[1]・[2]にて、座標の直接代入を廃止し `p2.startPushBack(targetX: ...)` を呼び出すよう変更。
  - `_updateTsubazeriai` および `_updateCpu` にて `isPushedBack` 中の状態保護を追加。
- `test/widget_test.dart`:
  - 突き飛ばし発動直後にワープせず `480.0` px/s で移動を開始し、時間経過によって端へ到達・停止することを検証するテストへ更新。

---

## 3. 修正ファイル一覧
1. `lib/game/components/kendo_fighter.dart`
2. `lib/game/kendo_game.dart`
3. `test/widget_test.dart`

---

## 4. 検証結果

### flutter analyze の実行結果
```bash
Analyzing kewpie_cup...
No issues found! (ran in 1.6s)
```

### flutter test の実行結果
```bash
00:02 +29: All tests passed!
```
