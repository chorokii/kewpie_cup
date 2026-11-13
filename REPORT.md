# 開発報告書: iPhone (iOS Safari / PWA) におけるタッチ操作干渉防止設定（`web/index.html` の改善）

## 1. 概要
- iPhone（iOS Safariおよび「ホーム画面に追加」したPWA環境）において、素早いダブルタップや長押し・スワイプ操作を行った際にブラウザ標準のズーム・テキスト選択・バウンススクロールが干渉しないよう、`web/index.html` のスタイル設定を強化しました。

---

## 2. 実施内容
- `web/index.html`:
  - `html, body` に `touch-action: none`、`overscroll-behavior: none`、`-webkit-user-select: none`、`user-select: none`、`-webkit-touch-callout: none`、`-webkit-tap-highlight-color: transparent`、`position: fixed`、`width: 100%`、`height: 100%` を追加。
- `CURRENT_CONTEXT.md`:
  - モバイルWeb / iOS Safari 向けのタッチ操作干渉防止設定の仕様を追記。

---

## 3. 修正ファイル一覧
1. `web/index.html`
2. `CURRENT_CONTEXT.md`
3. `REPORT.md`

---

## 4. 検証結果

### flutter analyze の実行結果
```bash
Analyzing kewpie_cup...
No issues found! (ran in 4.4s)
```

### flutter test の実行結果
```bash
00:07 +35: All tests passed!
```
