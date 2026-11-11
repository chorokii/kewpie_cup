# 開発報告書: deploy.ps1 へのアイコン自動生成ステップの組み込み

## 1. 概要
- `assets/images/icon/app_icon.png` を変更した際、`.\deploy.ps1` を実行するだけで自動的にアイコンが再生成されてからWebビルド・デプロイが行われるようスクリプトを更新しました。

---

## 2. 実施内容
- `deploy.ps1`:
  - `flutter build web` の実行前に、`assets/images/icon/app_icon.png` が存在する場合は `dart run flutter_launcher_icons` を自動実行する処理を追加。

---

## 3. 修正ファイル一覧
1. `deploy.ps1`

---

## 4. 検証結果

### flutter analyze の実行結果
```bash
Analyzing kewpie_cup...
No issues found! (ran in 1.5s)
```

### flutter test の実行結果
```bash
00:02 +31: All tests passed!
```
