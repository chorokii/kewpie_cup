# 開発報告書: 設定画面の「効果音」および「デバッグ（座標表示）」の永続化対応

## 1. 概要
- 設定画面においてゲーム終了後にリセットされていた「効果音（入/切）」および「デバッグ（座標表示）（入/切）」の2項目について、`ScoreManager`（`SharedPreferences`）による永続化処理を実装しました。
- これにより、設定画面の全項目（効果音・デバッグ表示・防御有効時間・通算スコア）がゲーム終了後も保持されるようになりました。

---

## 2. 実施内容
- `lib/game/score/score_manager.dart`:
  - `soundEnabledNotifier` および `debugEnabledNotifier` を追加。
  - `loadScore()` にて `kewpie_sound_enabled` と `kewpie_debug_enabled` を読み込み、`SoundManager.isEnabled` の更新および必要に応じた `SoundManager.init()` を実行するように変更。
  - `setSoundEnabled(bool)` および `setDebugEnabled(bool)` を追加し、設定変更時に即座に `SharedPreferences` へ保存するように実装。
- `lib/screens/title_screen.dart`:
  - `_TitleScreenState` のローカル静的変数を廃止し、`ScoreManager` の設定値を参照・更新するように変更（「心得」ダイアログのコード・テキストは変更なし）。
- `CURRENT_CONTEXT.md`:
  - `ScoreManager` および `SoundManager` の永続化仕様を追記。
- `test/widget_test.dart`:
  - `setSoundEnabled` と `setDebugEnabled` の保存・再読み込み検証テストを追加。

---

## 3. 修正ファイル一覧
1. `lib/game/score/score_manager.dart`
2. `lib/screens/title_screen.dart`
3. `CURRENT_CONTEXT.md`
4. `test/widget_test.dart`

---

## 4. 検証結果

### flutter analyze の実行結果
```bash
Analyzing kewpie_cup...
No issues found! (ran in 3.0s)
```

### flutter test の実行結果
```bash
00:05 +33: All tests passed!
```
