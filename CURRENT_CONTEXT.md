# CURRENT_CONTEXT.md (プロジェクト開発コンテキスト Kewpie_cup)

## 0. プロジェクト前提条件
- **プロジェクト名**: `Kewpie_cup` (対CPU 剣道2D格闘バトルゲーム)
- **フレームワーク**: Flutter (Stable) + Flame 2D Game Engine (v1.x)
- **対象プラットフォーム**: Web (PWA対応), Android, Windows
- **画面の向き（オリエンテーション）規約**:
  - 横位置推奨オーバーレイ画面（旧 `LandscapeWrapper`）および `RotatedBox` による90度強制回転は行わない。
  - アプリ全体で `SystemChrome.setPreferredOrientations(DeviceOrientation.values)`（全方向許可）とし、タイトル画面（`TitleScreen`）・「選手登録」ダイアログ・対戦画面（`GamePage`）のすべてにおいて、縦持ち・横持ちのどちらでもそのままの画面の向きで表示・操作可能とする（縦持ちでの対戦時は `FixedResolutionViewport(1280, 720)` により画面幅に合わせて縮小表示される）。
- **コード品質管理**: `flutter_lints` 準拠、`flutter analyze` エラー・警告0件、`flutter test` 全件通過をコミット基準とする。
- **外部支援体制**: Android Studio内蔵エージェントによる実装を基本とし、複雑な課題・全体設計は外部サポート（アンちゃん）が客観的事実に基づき俯瞰して指示を行う。

---

## 1. 現在の設計仕様・実装ルール（事実ベース）

### A. 画面解像度・座標系・グラフィック規約
1. **固定解像度ビューポート**:
   - `KendoGame` は `FixedResolutionViewport(resolution: Vector2(1280, 720))`（16:9 横画面）で動作し、カメラ中心は `(0.0, 0.0)`、ズームは `1.0`。
2. **道場ステージ (`DojoStage`)**:
   - サイズ: `1280 x 720` (`Anchor.center`, `position = Vector2(0, 0)`, `priority = -10`)。
   - `assets/images/stage/dojo_background.png` が有効な場合はスプライト描画し、未配置または読み込み失敗時は Canvas API による道場へ安全にフォールバック描画する。
   - CPUの打突直前（点滅終了後の0.5秒間）には、背景全体を赤くフラッシュさせる警告オーバーレイ（`flashAlpha`）を描画する。
3. **剣士キャラクター (`KendoFighter`) と垂ネーム描画**:
   - ベースサイズ `60 x 100` を `scale = Vector2.all(3.0)` で3倍拡大表示（`priority = 10`）。
   - 描画基準点 `(0, 0)` を足元とし、`anchor = Anchor.topCenter` に設定することで、ワールド座標 `position`（`fighterGroundY = 250.0`）が直接足元の接地座標と一致する。
   - ステージ移動制限は `stageMinX = -520.0` から `stageMaxX = 520.0`、身体押し合い最小距離は `minFighterDistance = 108.0`。
   - 1P（プレイヤー）は白稽古着・赤目印・紺袴・赤胴帯（開始位置 `X = -260.0`）。2P（CPU）は紺稽古着・白目印・黒袴・白胴帯（開始位置 `X = 440.0`）。
   - **垂ネーム（名札・ゼッケン）**: 正面中央の垂ネーム枠は幅 `12.0`、縦 `21.0`（従来の14.0の1.5倍、胴の下端に隠れない描画順序）、背景色は紺色（`Color(0xFF102040)`）、文字色は白色（`Colors.white`）で2〜3文字の苗字を縦書き描画する（左向き時も鏡文字にならないよう反転補正を行う）。

### B. 戦闘システム（「先守後攻」ルール）
1. **CPUの2段階攻撃と予備動作**:
   - CPU（2P）は接近時、ランダムに選択された3段階の白点滅時間（`cpuBlinkDurations`: 短 `0.3s` / 中 `0.5s` / 長 `0.8s`）で予備動作を行い、点滅終了後に固定 `0.5s`（`postBlinkHoldDuration`）のタメ（この間ステージ背景が赤フラッシュ）を経て、面打ち（`0.3s`）を繰り出す。
2. **プレイヤーの防御とジャスト防御判定**:
   - 防御有効時間（`KendoFighter.guardActiveDuration`）は設定画面にて **`0.2秒〜1.0秒`（0.1秒刻み、初期値 `0.4秒`）** の範囲で変更可能。
   - 防御持続時間が満了するか中断すると、`0.2秒`（`guardCooldownDuration`）のクールダウンに入る。
   - CPUの打突判定時にプレイヤーが防御中（`isGuarding == true`）であれば「ジャスト防御成功」となり、青い閃光エフェクト・ヒットストップ（`0.06s`）・防御音（`guard.mp3`）が発生し、CPUが **`1.5秒間`の体勢崩れ（`cpuVulnerableTimer = 1.5`、「スキあり」表示）** となる。
3. **プレイヤーの打突と間合い管理**:
   - 一足一刀の間合い（`attackRange = 255.0`）より遠い状態で攻撃を入力した場合、1ステップ（`farAdvanceDuration = 0.35s`）だけ前進して自動停止する。
   - 間合い内で攻撃を入力した場合、2段階の踏み込み打突（`attackDuration = 0.45s`）を行う。
   - 平常時（`cpuVulnerableTimer <= 0`）のプレイヤー打突はCPUに自動防御される。**CPUが体勢崩れ（反撃チャンス）の間のみ打突がヒット**し、ダメージ **`34.0`（3回ヒットで1本: `100.0 -> 66.0 -> 32.0 -> 0.0`）**、衝撃波エフェクト、画面揺れ、打撃音（`hit.mp3`）、および背後へのすり抜け（Pass-Through）＋同時振り返り（Turnaround）が発生する。

### C. 鍔迫り合い・離脱・突き飛ばしルール
1. **鍔迫り合い (`isTsubazeriai`)**:
   - 両者の距離が `114.0px` 以下になると鍔迫り合い状態（「ゴゴゴ･･」表示）に移行し、`135.0px` を超えると解除される。
2. **離脱 (`disengage`)**:
   - 防御側エリアのダブルタップ（または `S` / `↓` キー）で後方へ高速バックステップ（`disengageSpeed = 320.0px/s`, 持続 `0.25s`）して間合いを離す。
3. **突き飛ばし (`startPushBack`)**:
   - 鍔迫り合い中、攻撃ボタンをダブルタップ（300ms以内）した際、以下の位置条件を満たすと相手を反対側のステージ端まで突き飛ばす（後退速度の1.5倍 `pushBackSpeed = 480.0px/s` で端まで連続移動アニメーション表示）：
     - **ルール[1]**: 自分が敵の左位置（`p1.x < p2.x`）かつ中央より左側（`p1.x < 0.0`）にいる場合、相手を右端（`stageMaxX = 520.0`）まで突き飛ばす。
     - **ルール[2]**: 自分が敵の右位置（`p1.x > p2.x`）かつ中央より右側（`p1.x > 0.0`）にいる場合、相手を左端（`stageMinX = -520.0`）まで突き飛ばす。
   - 上記以外の単発攻撃タップ時は、相手を `20.0px` 押し込む。

### D. 試合進行・剣道審判宣告・勝敗判定・連勝記録・選手登録
1. **ラウンド開始時の審判宣告（単一表示 `1.2秒`）**:
   - 1本目（合計0本時）: **「はじめ！」**
   - 2本目（合計1本時）: **「二本目！」**
   - 3本目（1対1時）: **「勝負！」**
2. **決まり手宣告と2本先取時の3段階遷移**:
   - 体力（`100.0`）が0になり1本獲得となった際、確率 **「面あり：50%、小手あり：40%、胴あり：10%」**（`rollIpponCallText`）で決まり手を決定する。
   - 制限時間 `30秒` が経過してタイムアウトとなった場合は、審判の停止宣告 **「やめ！」** を表示し、CPU（2P）の1本となる。
   - 1本目決着時（`KendoGameState.roundOver`）は、決まり手（または「やめ！」）を `2.0秒間` 表示した後に次ラウンドを開始する。
   - 2本先取して勝敗がついた場合（`KendoGameState.matchOver`）は、以下の3段階で表示を遷移させる：
     1. **「〇あり」（または「やめ！」）** を `1.2秒間` 表示。
     2. **「勝負あり！」** を `1.0秒間` 表示。
     3. 合計 `2.2秒` 経過後に **「あなたの勝ち」** または **「あなたの負け」** および「再戦 (R)」「タイトルへ」ボタンを表示。
3. **通算成績・連勝表記・設定および選手登録の永続化 (`ScoreManager`)**:
   - 勝敗数・連勝数・防御有効時間・効果音（入/切）・デバッグ座標表示（入/切）・自分の名前（1種）・相手の名前（最大10種）は `SharedPreferences` で永続化され、ゲーム終了後も保持される。
   - 相手の名前は試合開始時・再戦時にランダムで選択され、複数名登録されている場合は**連続して同じ名前を選択しない**。
   - 連勝表示は「1連勝中」を表示せず、**最小で「2連勝中」（`streak >= 2`）から** タイトル画面および対戦HUDに表示する。

### E. UI / HUD・操作系・音響 (`SoundManager`)
1. **タイトル画面 (`TitleScreen`)**:
   - 横画面時はメニューボタン（「試合開始」「選手登録」「心得」「設定」）を `Wrap` で横並びに配置し、縦画面時は `Column` で縦並びに配置する（横位置推奨画面は出さず、どちらの向きでも直接操作可能）。
   - ※ `lib/screens/title_screen.dart` 内の「心得」テキストはユーザーが手動管理しているため、自動上書きを行わないこと。
2. **対戦HUD (`FightingHudOverlay`)**:
   - 1P・2PのHPゲージはストリートファイター2方式（画面外側から中央タイマー側へ向かって減る：`Align` + `FractionallySizedBox`）で描画される。
   - 画面左右下の半透明円インジケータ（赤円＝攻撃、青円＝防御）が敵との左右位置関係（`isEnemyOnRightNotifier`）に応じて自動で入れ替わる。
   - タップ操作は `LayoutBuilder` のローカル幅（`constraints.maxWidth`）と `event.localPosition.dx` に基づいて画面の左右半分を判定する。
3. **効果音 (`SoundManager`)**:
   - 初期値は `isEnabled = false`（切）。設定画面での変更内容は `ScoreManager.setSoundEnabled` を通じて `SharedPreferences` に保存され、次回起動時にも保持される。
   - `assets/audio/sfx/guard.mp3`（防御音）および `assets/audio/sfx/hit.mp3`（打撃音）を `audioplayers` の `AssetSource` で再生する（チャージ音は無効化維持）。
   - ※ `.repomixignore` により `*.mp3` はRepomix出力から除外されているが、実ファイルは `assets/audio/sfx/` に存在する。
```

---

Now let's run `flutter analyze` via `run_shell_command`!

Now let's run `flutter analyze` via `run_shell_command`!5. **`REPORT.md` の出力**:
   - 作業完了後、実施内容・修正ファイル・検証結果（`flutter analyze` および `flutter test`）を `REPORT.md` に上書き記録する。

---

## 3. 具体的なファイル修正内容

### 3.1 `lib/main.dart`
`lib/main.dart` を以下の内容に完全置換してください（省略なし）。

```dart
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/kendo_game.dart';
import 'screens/title_screen.dart';
import 'widgets/fighting_hud.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 縦持ち・横持ちのどちらでもそのままの向きで操作・プレイできるよう全方向を許可する
  await SystemChrome.setPreferredOrientations(DeviceOrientation.values);

  runApp(const KewpieCupApp());
}

class KewpieCupApp extends StatelessWidget {
  const KewpieCupApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kewpie_cup',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D0D11),
      ),
      home: const TitleScreen(),
    );
  }
}

class GamePage extends StatefulWidget {
  const GamePage({
    super.key,
    this.isDebugEnabled = false,
  });

  final bool isDebugEnabled;

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late final KendoGame game;

  @override
  void initState() {
    super.initState();
    game = KendoGame();
    game.isDebugVisibleNotifier.value = widget.isDebugEnabled;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D11),
      body: GameWidget<KendoGame>(
        game: game,
        overlayBuilderMap: {
          'HudOverlay': (context, game) => FightingHudOverlay(game: game),
        },
        initialActiveOverlays: const ['HudOverlay'],
      ),
    );
  }
}
```

### 3.2 `test/widget_test.dart`
`test/widget_test.dart` を以下の内容に完全置換してください（省略なし）。

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kewpie_cup/game/audio/sound_manager.dart';
import 'package:kewpie_cup/game/components/dojo_stage.dart';
import 'package:kewpie_cup/game/components/kendo_fighter.dart';
import 'package:kewpie_cup/game/enums/facing_direction.dart';
import 'package:kewpie_cup/game/kendo_game.dart';
import 'package:kewpie_cup/game/score/score_manager.dart';
import 'package:kewpie_cup/main.dart';
import 'package:kewpie_cup/widgets/fighting_hud.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    // Disable sound playback for headless unit testing environment
    SoundManager.isEnabled = false;
  });

  testWidgets('Kewpie_cup title screen loads with menu options including 選手登録 and starts match',
      (WidgetTester tester) async {
    await ScoreManager.clearScore();
    await ScoreManager.setPlayerName('剣士');
    await ScoreManager.setCpuNames(['佐藤', '鈴木']);
    await tester.pumpWidget(const KewpieCupApp());
    await tester.pump();

    // Verify Title Screen menu buttons
    expect(find.text('試合開始'), findsOneWidget);
    expect(find.text('選手登録'), findsOneWidget);
    expect(find.text('心得'), findsOneWidget);
    expect(find.text('設定'), findsOneWidget);

    // 1 win should NOT display "1連勝中"
    await ScoreManager.recordWin();
    await tester.pump();
    expect(find.textContaining('1連勝中'), findsNothing);

    // 2 wins SHOULD display "2連勝中"
    await ScoreManager.recordWin();
    await tester.pump();
    expect(find.textContaining('2連勝中'), findsOneWidget);

    await ScoreManager.clearScore();
    await tester.pump();

    // Tap '試合開始' to enter GamePage
    await tester.tap(find.text('試合開始'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify Game HUD text and action buttons are rendered
    expect(find.textContaining('1P 剣士'), findsOneWidget);
    expect(find.textContaining('(CPU)'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
  });

  testWidgets('Portrait screen does NOT show landscape warning overlay and allows playing directly in portrait without RotatedBox',
      (WidgetTester tester) async {
    // Simulate portrait smartphone screen (width 400 < height 800)
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await ScoreManager.setPlayerName('剣士');
    await tester.pumpWidget(const KewpieCupApp());
    await tester.pump();

    // Verify the old landscape recommendation overlay is abolished
    expect(find.text('画面を横向きにしてください'), findsNothing);
    expect(find.text('選手登録'), findsOneWidget);

    // Start match directly from portrait screen
    await tester.tap(find.text('試合開始'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify GamePage is rendered directly in portrait without RotatedBox
    expect(find.byKey(const ValueKey('auto_landscape_rotated_box')), findsNothing);
    expect(find.byType(RotatedBox), findsNothing);
    expect(find.textContaining('1P 剣士'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
  });

  testWidgets('Health bars deplete from outer edges toward center (Street Fighter II style)',
      (WidgetTester tester) async {
    final game = KendoGame();
    await game.onLoad();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FightingHudOverlay(game: game),
        ),
      ),
    );
    await tester.pump();

    // Set both P1 and P2 health to 50%
    game.p1HealthNotifier.value = 50.0;
    game.p2HealthNotifier.value = 50.0;
    await tester.pump();

    final p1BarRect = tester.getRect(find.byKey(const ValueKey('p1_health_bar')));
    final p1FillRect = tester.getRect(find.byKey(const ValueKey('p1_health_fill')));

    final p2BarRect = tester.getRect(find.byKey(const ValueKey('p2_health_bar')));
    final p2FillRect = tester.getRect(find.byKey(const ValueKey('p2_health_fill')));

    // P1 (Left side): Yellow remaining health must be anchored to the RIGHT (center timer side),
    // so the LEFT (outer edge) is depleted!
    expect(p1FillRect.right, closeTo(p1BarRect.right - 2.0, 0.5));
    expect(p1FillRect.left, greaterThan(p1BarRect.left + 10.0));

    // P2 (Right side): Yellow remaining health must be anchored to the LEFT (center timer side),
    // so the RIGHT (outer edge) is depleted!
    expect(p2FillRect.left, closeTo(p2BarRect.left + 2.0, 0.5));
    expect(p2FillRect.right, lessThan(p2BarRect.right - 10.0));
  });

  group('ScoreManager persistent score tracking, player registration and clear tests', () {
    test('setPlayerName and setCpuNames persist up to 10 names (2-3 chars) and prevent consecutive duplicate selection', () async {
      await ScoreManager.setPlayerName('佐々木');
      expect(ScoreManager.playerNameNotifier.value, equals('佐々木'));

      final tenNames = [
        '佐藤', '鈴木', '高橋', '田中', '渡辺',
        '伊藤', '山本', '中村', '小林', '加藤',
        '吉田', // 11th item -> should be capped at 10
      ];
      await ScoreManager.setCpuNames(tenNames);
      expect(ScoreManager.cpuNamesNotifier.value.length, equals(10));
      expect(ScoreManager.cpuNamesNotifier.value.contains('吉田'), isFalse);

      // Verify persistence across loadScore()
      ScoreManager.playerNameNotifier.value = '初期';
      ScoreManager.cpuNamesNotifier.value = ['初期'];
      await ScoreManager.loadScore();
      expect(ScoreManager.playerNameNotifier.value, equals('佐々木'));
      expect(ScoreManager.cpuNamesNotifier.value.length, equals(10));

      // Verify non-repeating random selection when multiple CPU names are registered
      await ScoreManager.setCpuNames(['佐藤', '鈴木', '高橋']);
      ScoreManager.resetLastSelectedCpuName();
      String previous = ScoreManager.pickRandomCpuName();
      for (int i = 0; i < 30; i++) {
        final next = ScoreManager.pickRandomCpuName();
        expect(next, isNot(equals(previous)));
        previous = next;
      }

      // Restore defaults
      await ScoreManager.setPlayerName(ScoreManager.defaultPlayerName);
      await ScoreManager.setCpuNames(ScoreManager.defaultCpuNames);
    });

    test('setSoundEnabled and setDebugEnabled persist settings across loadScore calls', () async {
      // Save settings directly in SharedPreferences for testing persistence
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('kewpie_sound_enabled', true);
      await prefs.setBool('kewpie_debug_enabled', true);

      // Reset in-memory values
      ScoreManager.soundEnabledNotifier.value = false;
      ScoreManager.debugEnabledNotifier.value = false;

      // Verify SharedPreferences values are loaded
      final savedSound = prefs.getBool('kewpie_sound_enabled') ?? false;
      ScoreManager.soundEnabledNotifier.value = savedSound;

      final savedDebug = prefs.getBool('kewpie_debug_enabled') ?? false;
      ScoreManager.debugEnabledNotifier.value = savedDebug;

      expect(ScoreManager.soundEnabledNotifier.value, isTrue);
      expect(ScoreManager.debugEnabledNotifier.value, isTrue);

      // Restore defaults
      await prefs.setBool('kewpie_sound_enabled', false);
      await prefs.setBool('kewpie_debug_enabled', false);
      ScoreManager.soundEnabledNotifier.value = false;
      SoundManager.isEnabled = false;
      ScoreManager.debugEnabledNotifier.value = false;
    });

    test('setGuardDuration updates KendoFighter.guardActiveDuration within 0.2..1.0 and persists setting', () async {
      await ScoreManager.setGuardDuration(0.8);
      expect(KendoFighter.guardActiveDuration, equals(0.8));

      final fighter = KendoFighter(
        name: 'TestFighter',
        isPlayer: true,
        startX: -100.0,
        groundY: 0.0,
        keikogiColor: Colors.white,
        ribbonColor: Colors.red,
      );

      fighter.startGuard();
      expect(fighter.isGuarding, isTrue);

      // Advance 0.6s (out of 0.8s active duration) -> still guarding!
      fighter.update(0.60);
      expect(fighter.isGuarding, isTrue);

      // Advance another 0.3s (total 0.9s) -> guard expires
      fighter.update(0.30);
      expect(fighter.isGuarding, isFalse);

      // Reset back to default 0.4s
      await ScoreManager.setGuardDuration(0.4);
      expect(KendoFighter.guardActiveDuration, equals(0.4));
    });

    test('recordWin increments wins and streak, recordLoss increments losses and resets streak', () async {
      await ScoreManager.clearScore();
      expect(ScoreManager.winsNotifier.value, equals(0));
      expect(ScoreManager.lossesNotifier.value, equals(0));
      expect(ScoreManager.streakNotifier.value, equals(0));

      await ScoreManager.recordWin();
      expect(ScoreManager.winsNotifier.value, equals(1));
      expect(ScoreManager.streakNotifier.value, equals(1));

      await ScoreManager.recordWin();
      expect(ScoreManager.winsNotifier.value, equals(2));
      expect(ScoreManager.streakNotifier.value, equals(2));

      await ScoreManager.recordLoss();
      expect(ScoreManager.winsNotifier.value, equals(2));
      expect(ScoreManager.lossesNotifier.value, equals(1));
      expect(ScoreManager.streakNotifier.value, equals(0));

      await ScoreManager.clearScore();
      expect(ScoreManager.winsNotifier.value, equals(0));
      expect(ScoreManager.lossesNotifier.value, equals(0));
      expect(ScoreManager.streakNotifier.value, equals(0));
    });
  });

  group('Pre-round start sequence and facing direction tests ("はじめ！" / "二本目！" / "勝負！")', () {
    test('Round 1 displays はじめ！ only for 1.2s then starts fight', () async {
      final game = KendoGame();
      await game.onLoad();

      expect(game.isRoundStarting, isTrue);
      expect(game.overlayTextNotifier.value, equals('はじめ！'));

      // Advance 0.8s -> still "はじめ！"
      game.update(0.80);
      expect(game.isRoundStarting, isTrue);
      expect(game.overlayTextNotifier.value, equals('はじめ！'));

      // Advance 0.5s (total 1.3s > 1.2s) -> pre-round sequence finishes, active fight begins!
      game.update(0.50);
      expect(game.isRoundStarting, isFalse);
      expect(game.overlayTextNotifier.value, equals(''));
    });

    test('Round title text is はじめ！ for round 1, 二本目！ for round 2, and 勝負！ for round 3', () async {
      final game = KendoGame();
      await game.onLoad();

      // Round 1 (0 wins)
      expect(game.currentRoundTitleText, equals('はじめ！'));

      // Set P1 winCount = 1 (Round 2)
      game.p1.winCount = 1;
      expect(game.currentRoundTitleText, equals('二本目！'));

      // Set P2 winCount = 1 (Round 3: 1-1 tie)
      game.p2.winCount = 1;
      expect(game.currentRoundTitleText, equals('勝負！'));
    });

    test('Fighters face inward (each other) immediately when Round 2 starts even if swapped in Round 1', () async {
      final game = KendoGame();
      await game.onLoad();
      game.isRoundStarting = false;

      // Simulate swapped positions & outward facing directions at the end of Round 1
      game.p1.position.x = 200.0;
      game.p2.position.x = 100.0;
      game.p1.facingDirection = FacingDirection.left;
      game.p2.facingDirection = FacingDirection.right;
      game.p2.health = 34.0;
      game.p2.cpuVulnerableTimer = 1.5;

      // P1 scores Ippon to end Round 1
      game.p1.attack();
      game.p1.update(0.20);
      game.update(0.01);

      expect(game.gameStateNotifier.value, equals(KendoGameState.roundOver));

      // Clear hitStop (0.06s) + advance roundOverDelay (2.0s) to trigger Round 2 start
      game.update(0.06);
      game.update(2.05);

      // Immediately at the start of Round 2 ("二本目！"), both fighters must face inward!
      expect(game.isRoundStarting, isTrue);
      expect(game.overlayTextNotifier.value, equals('二本目！'));
      expect(game.p1.position.x, equals(-260.0));
      expect(game.p2.position.x, equals(440.0));
      expect(game.p1.facingDirection, equals(FacingDirection.right));
      expect(game.p2.facingDirection, equals(FacingDirection.left));
    });
  });

  group('KendoFighter logic and 2-phase attack tests', () {
    test('startGuard reduces movement speed and sets isGuarding flag', () {
      final fighter = KendoFighter(
        name: 'TestFighter',
        isPlayer: true,
        startX: -100.0,
        groundY: 0.0,
        keikogiColor: Colors.white,
        ribbonColor: Colors.red,
      );

      fighter.move(1.0);
      expect(fighter.velocityX, equals(fighter.walkSpeed));

      fighter.startGuard();
      expect(fighter.isGuarding, isTrue);
      expect(
          fighter.velocityX, equals(fighter.walkSpeed * fighter.guardSpeedMultiplier));

      fighter.stopGuard();
      expect(fighter.isGuarding, isFalse);
    });

    test('startGuard active duration (0.4s) auto-expires and enters 0.2s cooldown', () {
      final fighter = KendoFighter(
        name: 'TestFighter',
        isPlayer: true,
        startX: -100.0,
        groundY: 0.0,
        keikogiColor: Colors.white,
        ribbonColor: Colors.red,
      );

      fighter.startGuard();
      expect(fighter.isGuarding, isTrue);

      // Active guard duration (0.2s elapsed out of 0.4s)
      fighter.update(0.20);
      expect(fighter.isGuarding, isTrue);

      // Total 0.45s elapsed -> Guard automatically expires!
      fighter.update(0.25);
      expect(fighter.isGuarding, isFalse);
      expect(fighter.guardCooldownTimer, greaterThan(0.0));

      // Attempting to guard during cooldown fails
      fighter.startGuard();
      expect(fighter.isGuarding, isFalse);

      // Cooldown expires (0.25s)
      fighter.update(0.25);
      expect(fighter.guardCooldownTimer, equals(0.0));

      // Guard can be triggered again after cooldown
      fighter.startGuard();
      expect(fighter.isGuarding, isTrue);
    });

    test('2-phase lunge attack provides forward velocity and clears guard', () {
      final fighter = KendoFighter(
        name: 'TestFighter',
        isPlayer: true,
        startX: -100.0,
        groundY: 0.0,
        keikogiColor: Colors.white,
        ribbonColor: Colors.red,
      );

      fighter.startGuard();
      fighter.attack();
      expect(fighter.isAttacking, isTrue);
      expect(fighter.isGuarding, isFalse);

      // Phase 1 (0.00s - 0.18s): Forward windup lunge
      fighter.update(0.10);
      expect(fighter.velocityX, greaterThan(0));

      // Phase 2 (0.18s - 0.38s): Forward strike lunge
      fighter.update(0.10); // total 0.20s
      expect(fighter.velocityX, greaterThan(0));
    });

    test('disengage triggers rapid backward backstep velocity', () {
      final fighter = KendoFighter(
        name: 'TestFighter',
        isPlayer: true,
        startX: -100.0,
        groundY: 0.0,
        keikogiColor: Colors.white,
        ribbonColor: Colors.red,
      );

      fighter.disengage();
      expect(fighter.isDisengaging, isTrue);

      // Facing right -> backward direction is left (-velocityX)
      fighter.update(0.10);
      expect(fighter.velocityX, equals(-KendoFighter.disengageSpeed));

      // Complete disengage duration (0.25s)
      fighter.update(0.20);
      expect(fighter.isDisengaging, isFalse);
    });
  });

  group('Unified input handlers and Q/E hotkey tests', () {
    test('Far range attack input (dist > 255) advances 1 step (0.35s) and automatically stops', () async {
      final game = KendoGame();
      await game.onLoad();
      game.isRoundStarting = false;

      game.p1.position.x = -260.0;
      game.p2.position.x = 440.0; // Distance = 700px > 255px

      game.attackP1();
      expect(game.p1.isAttacking, isFalse);
      expect(game.p1.isFarAdvancing, isTrue);
      expect(game.p1.velocityX, greaterThan(0));

      // Advance 0.36s (past 0.35s 1-step duration) -> Automatically stops!
      game.p1.update(0.36);
      expect(game.p1.isFarAdvancing, isFalse);
      expect(game.p1.velocityX, equals(0.0));
    });

    test('Enemy on right: Left input (Q) guards, Right input (E) attacks', () async {
      final game = KendoGame();
      await game.onLoad();
      game.isRoundStarting = false;

      game.p1.position.x = -80.0;
      game.p2.position.x = 80.0; // Close strike range

      // Left input -> Guard start
      game.handleLeftInputDown();
      expect(game.p1.isGuarding, isTrue);

      // Guard stays active for guardActiveDuration (0.4s) without premature cancel on release
      game.p1.update(0.45);
      expect(game.p1.isGuarding, isFalse);

      // Right input -> Attack
      game.handleRightInputDown();
      expect(game.p1.isAttacking, isTrue);
    });

    test('Enemy on left: Left input (Q) attacks, Right input (E) guards', () async {
      final game = KendoGame();
      await game.onLoad();
      game.isRoundStarting = false;

      game.p1.position.x = 80.0;
      game.p2.position.x = -80.0; // Close strike range

      // Left input -> Attack
      game.handleLeftInputDown();
      expect(game.p1.isAttacking, isTrue);

      game.p1.isAttacking = false;

      // Right input -> Guard start
      game.handleRightInputDown();
      expect(game.p1.isGuarding, isTrue);

      // Guard stays active for guardActiveDuration (0.4s)
      game.p1.update(0.45);
      expect(game.p1.isGuarding, isFalse);
    });

    test('Inputs are ignored during roundOver and matchOver states', () async {
      final game = KendoGame();
      await game.onLoad();
      game.isRoundStarting = false;

      // Test during roundOver
      game.gameStateNotifier.value = KendoGameState.roundOver;
      game.attackP1();
      game.guardP1Start();
      game.disengageP1();
      game.moveP1Right();
      expect(game.p1.isAttacking, isFalse);
      expect(game.p1.isFarAdvancing, isFalse);
      expect(game.p1.isGuarding, isFalse);
      expect(game.p1.isDisengaging, isFalse);
      expect(game.p1.velocityX, equals(0.0));

      // Test during matchOver
      game.gameStateNotifier.value = KendoGameState.matchOver;
      game.handleLeftInputDown();
      game.handleRightInputDown();
      game.disengageP1();
      game.moveP1Left();
      expect(game.p1.isAttacking, isFalse);
      expect(game.p1.isFarAdvancing, isFalse);
      expect(game.p1.isGuarding, isFalse);
      expect(game.p1.isDisengaging, isFalse);
      expect(game.p1.velocityX, equals(0.0));
    });
  });

  group('CPU 2-phase attack and Sen-no-sen (先守後攻) combat tests', () {
    test('CPU attack flashes red background at blinking end and attacks 0.5s later', () async {
      final game = KendoGame();
      await game.onLoad();
      game.isRoundStarting = false;

      // Initiate CPU attack with 0.5s blink (total windup = 0.5s blink + 0.5s hold = 1.0s)
      game.p2.attack(blinkDuration: 0.5);

      // Advance to 0.40s (during white blinking) -> flashAlpha == 0
      game.p2.update(0.40);
      game.update(0.01);
      expect(game.stage.flashAlpha, equals(0.0));

      // Advance to 0.55s (just after blinking ends at 0.50s) -> flashAlpha > 0 (Red flash triggered!)
      game.p2.update(0.15);
      game.update(0.01);
      expect(game.stage.flashAlpha, greaterThan(0.0));

      // Advance to 1.05s (0.5s after blinking ends / strike connected) -> flashAlpha == 0
      game.p2.update(0.50);
      game.update(0.01);
      expect(game.stage.flashAlpha, equals(0.0));
    });

    test('CPU 3-tier attack windup durations (0.3s Short, 0.5s Medium, 0.8s Long) hit after 0.5s hold time', () async {
      final game = KendoGame();
      await game.onLoad();
      game.isRoundStarting = false;

      // Short (0.3s flash + 0.5s hold = 0.8s total windup)
      game.p2.attack(blinkDuration: 0.3);
      expect(game.p2.currentBlinkDuration, equals(0.3));
      game.p2.update(0.79);
      expect(game.p2.attackTimer, lessThan(0.80));
      game.p2.update(0.02); // total 0.81s
      expect(game.p2.attackTimer, greaterThanOrEqualTo(0.80));

      // Reset P2 attack
      game.p2.isAttacking = false;
      game.p2.attackTimer = 0.0;

      // Long (0.8s flash + 0.5s hold = 1.3s total windup)
      game.p2.attack(blinkDuration: 0.8);
      expect(game.p2.currentBlinkDuration, equals(0.8));
      game.p2.update(1.29);
      expect(game.p2.attackTimer, lessThan(1.30));
      game.p2.update(0.02); // total 1.31s
      expect(game.p2.attackTimer, greaterThanOrEqualTo(1.30));
    });

    test('CPU attack has 1.0s windup phase followed by Men strike phase', () async {
      final game = KendoGame();
      await game.onLoad();
      game.isRoundStarting = false;

      game.p2.attack(blinkDuration: 0.5);
      expect(game.p2.isAttacking, isTrue);

      // Phase 1 Windup (0.0s - 1.0s)
      game.p2.update(0.50);
      expect(game.p2.attackTimer, equals(0.50));
      expect(game.p2.attackTimer, lessThan(1.0));

      // Phase 2 Men Strike (1.0s - 1.3s)
      game.p2.update(0.55); // total 1.05s
      expect(game.p2.attackTimer, greaterThanOrEqualTo(1.0));
    });

    test('Normal state: Player attack is automatically blocked by CPU (0 damage)', () async {
      final game = KendoGame();
      await game.onLoad();
      game.isRoundStarting = false;

      game.p1.position.x = -80.0;
      game.p2.position.x = 80.0;
      game.p2.cpuVulnerableTimer = 0.0; // Normal state

      game.p1.attack();
      game.p1.update(0.20); // Strike window

      game.update(0.01);

      expect(game.p2.health, equals(100.0)); // Auto-blocked by CPU!
      expect(game.p1.winCount, equals(0));
    });

    test('Guarded defender blocks incoming 2-phase lunge attack and triggers Counter Opportunity', () async {
      final game = KendoGame();
      await game.onLoad();
      game.isRoundStarting = false;

      game.p1.position.x = -80.0;
      game.p2.position.x = 80.0;

      game.p1.startGuard(); // Player guards
      game.p2.attack(blinkDuration: 0.5);
      game.p2.update(1.05); // Advance to Men strike phase (1.0s+)

      game.update(0.01);

      expect(game.p1.health, equals(100.0)); // Player blocked CPU strike!
      expect(game.p2.cpuVulnerableTimer, greaterThan(0.0)); // CPU enters Counter Opportunity!
    });

    test('Counter Opportunity: 3 hits (34.0 damage each) reduce health from 100.0 to 0.0 and score Ippon', () async {
      final game = KendoGame();
      await game.onLoad();
      game.isRoundStarting = false;

      // Hit 1: 100.0 -> 66.0
      game.p1.position.x = -80.0;
      game.p2.position.x = 80.0;
      game.p2.cpuVulnerableTimer = 1.5;
      game.p1.attack();
      game.p1.update(0.20);
      game.update(0.01);
      expect(game.p2.health, equals(66.0));
      expect(game.p1.winCount, equals(0));

      // Clear hitStop & passThrough for Hit 2: 66.0 -> 32.0
      game.hitStopTimer = 0.0;
      game.p1.stopAllActions();
      game.p2.stopAllActions();
      game.p1.hitStunTimer = 0.0;
      game.p2.hitStunTimer = 0.0;
      game.p1.position.x = -80.0;
      game.p2.position.x = 80.0;
      game.p2.cpuVulnerableTimer = 1.5;
      game.p1.attack();
      game.p1.update(0.20);
      game.update(0.01);
      expect(game.p2.health, equals(32.0));
      expect(game.p1.winCount, equals(0));

      // Clear hitStop & passThrough for Hit 3: 32.0 -> 0.0 (Ippon!)
      game.hitStopTimer = 0.0;
      game.p1.stopAllActions();
      game.p2.stopAllActions();
      game.p1.hitStunTimer = 0.0;
      game.p2.hitStunTimer = 0.0;
      game.p1.position.x = -80.0;
      game.p2.position.x = 80.0;
      game.p2.cpuVulnerableTimer = 1.5;
      game.p1.attack();
      game.p1.update(0.20);
      game.update(0.01);

      expect(game.p2.health, equals(0.0)); // 3rd counter hit scores Ippon!
      expect(game.p1.winCount, equals(1));
      expect(game.gameStateNotifier.value, equals(KendoGameState.roundOver));
      expect(
        ['面あり', '小手あり', '胴あり'].contains(game.overlayTextNotifier.value),
        isTrue,
      );
    });
  });

  group('KendoGame pause function tests', () {
    test('togglePause toggles isPausedNotifier and suppresses movement', () async {
      final game = KendoGame();
      await game.onLoad();
      game.isRoundStarting = false;

      expect(game.isPausedNotifier.value, isFalse);

      // Pause
      game.togglePause();
      expect(game.isPausedNotifier.value, isTrue);

      // Movement should be ignored during pause
      game.moveP1Right();
      expect(game.p1.velocityX, equals(0.0));

      // Resume
      game.togglePause();
      expect(game.isPausedNotifier.value, isFalse);

      game.moveP1Right();
      expect(game.p1.velocityX, equals(game.p1.walkSpeed));
    });
  });

  group('KendoGame combat, Tsubazeriai and match rules tests', () {
    test('rollIpponCallText returns 面あり (50%), 小手あり (40%), 胴あり (10%) according to probability', () async {
      final game = KendoGame();
      await game.onLoad();

      expect(game.rollIpponCallText(0.00), equals('面あり'));
      expect(game.rollIpponCallText(0.49), equals('面あり'));
      expect(game.rollIpponCallText(0.50), equals('小手あり'));
      expect(game.rollIpponCallText(0.89), equals('小手あり'));
      expect(game.rollIpponCallText(0.90), equals('胴あり'));
      expect(game.rollIpponCallText(0.99), equals('胴あり'));
    });

    test('30-second time-out awards Ippon to CPU and displays やめ！ then 勝負あり！ on 2nd win', () async {
      final game = KendoGame();
      await game.onLoad();
      game.isRoundStarting = false;

      expect(game.roundTimerNotifier.value, equals(30));

      // Advance time by 30.1 seconds
      game.update(30.1);

      // CPU (p2) receives win from time-out with "やめ！"
      expect(game.p2.winCount, equals(1));
      expect(game.gameStateNotifier.value, equals(KendoGameState.roundOver));
      expect(game.overlayTextNotifier.value, equals('やめ！'));

      // 2nd time-out leads to matchOver displaying "やめ！" (1.2s) -> "勝負あり！" (1.0s) -> "あなたの負け"
      final game2 = KendoGame();
      await game2.onLoad();
      game2.isRoundStarting = false;
      game2.p2.winCount = 1;

      game2.update(30.1);
      expect(game2.p2.winCount, equals(2));
      expect(game2.gameStateNotifier.value, equals(KendoGameState.matchOver));
      expect(game2.isMatchOverResultPending, isTrue);
      expect(game2.overlayTextNotifier.value, equals('やめ！'));

      // Advance 1.3s (into Phase 2: 1.2s..2.2s) -> Displays "勝負あり！"
      game2.update(1.3);
      expect(game2.isMatchOverResultPending, isTrue);
      expect(game2.overlayTextNotifier.value, equals('勝負あり！'));

      // Advance another 1.0s (total 2.3s > 2.2s) -> Transitions to "あなたの負け"
      game2.update(1.0);
      expect(game2.isMatchOverResultPending, isFalse);
      expect(game2.overlayTextNotifier.value, equals('あなたの負け'));
    });

    test('Close contact distance triggers Tsubazeriai state', () async {
      final game = KendoGame();
      await game.onLoad();
      game.isRoundStarting = false;

      // Position fighters within Tsubazeriai distance (<= 114.0px)
      game.p1.position.x = -40.0;
      game.p2.position.x = 40.0; // distance 80.0px

      game.update(0.01);

      expect(game.p1.isTsubazeriai, isTrue);
      expect(game.p2.isTsubazeriai, isTrue);
    });

    test('Tsubazeriai Rule [1]: P1 on left of P2 and left of center (< 0), double-tap attack smoothly pushes P2 to right edge at 1.5x disengage speed', () async {
      final game = KendoGame();
      await game.onLoad();
      game.isRoundStarting = false;

      // P1 is left of P2 (-200 < -100) and left of center (-200 < 0)
      game.p1.position.x = -200.0;
      game.p2.position.x = -100.0;
      game.p1.isTsubazeriai = true;
      game.p2.isTsubazeriai = true;

      // Double-tap attack starts continuous push-back at 1.5x disengage speed (480.0 px/s)
      game.attackP1(forceDoubleTap: true);

      expect(game.p1.isTsubazeriai, isFalse);
      expect(game.p2.isTsubazeriai, isFalse);
      expect(game.p2.isPushedBack, isTrue);
      expect(game.p2.velocityX, equals(KendoFighter.disengageSpeed * 1.5));
      expect(game.p2.position.x, equals(-100.0)); // Does NOT warp immediately

      // Advance 0.5s -> P2 moves halfway (+240px to 140.0) while still visible & moving
      game.update(0.50);
      expect(game.p2.isPushedBack, isTrue);
      expect(game.p2.position.x, closeTo(140.0, 1.0));

      // Advance 0.80s (total 1.30s >= 1.29s needed) -> P2 reaches right edge (stageMaxX = 520.0) and stops
      game.update(0.80);
      expect(game.p2.isPushedBack, isFalse);
      expect(game.p2.position.x, equals(game.stageMaxX));
    });

    test('Tsubazeriai Rule [2]: P1 on right of P2 and right of center (> 0), double-tap attack smoothly pushes P2 to left edge at 1.5x disengage speed', () async {
      final game = KendoGame();
      await game.onLoad();
      game.isRoundStarting = false;

      // P1 is right of P2 (200 > 100) and right of center (200 > 0)
      game.p1.position.x = 200.0;
      game.p2.position.x = 100.0;
      game.p1.isTsubazeriai = true;
      game.p2.isTsubazeriai = true;

      // Double-tap attack starts continuous push-back at -1.5x disengage speed (-480.0 px/s)
      game.attackP1(forceDoubleTap: true);

      expect(game.p1.isTsubazeriai, isFalse);
      expect(game.p2.isTsubazeriai, isFalse);
      expect(game.p2.isPushedBack, isTrue);
      expect(game.p2.velocityX, equals(-KendoFighter.disengageSpeed * 1.5));
      expect(game.p2.position.x, equals(100.0)); // Does NOT warp immediately

      // Advance 0.5s -> P2 moves halfway (-240px to -140.0) while still visible & moving
      game.update(0.50);
      expect(game.p2.isPushedBack, isTrue);
      expect(game.p2.position.x, closeTo(-140.0, 1.0));

      // Advance 0.80s (total 1.30s >= 1.29s needed) -> P2 reaches left edge (stageMinX = -520.0) and stops
      game.update(0.80);
      expect(game.p2.isPushedBack, isFalse);
      expect(game.p2.position.x, equals(game.stageMinX));
    });

    test('2 wins displays Ippon call (1.2s) -> 勝負あり！ (1.0s) -> あなたの勝ち or あなたの負け', () async {
      final game = KendoGame();
      await game.onLoad();
      game.isRoundStarting = false;

      // P1 (Player) wins 2nd round -> matchOver with Ippon call (1.2s) -> "勝負あり！" (1.0s) -> "あなたの勝ち"
      game.p1.winCount = 1;
      game.p1.position.x = -80.0;
      game.p2.position.x = 80.0;
      game.p2.health = 0.0;
      game.p2.cpuVulnerableTimer = 1.5;

      game.p1.attack();
      game.p1.update(0.20);

      game.update(0.01); // Triggers 0.06s hitStop and Ippon call

      expect(game.p1.winCount, equals(2));
      expect(game.gameStateNotifier.value, equals(KendoGameState.matchOver));
      expect(game.isMatchOverResultPending, isTrue);
      expect(
        ['面あり', '小手あり', '胴あり'].contains(game.overlayTextNotifier.value),
        isTrue,
      );

      // Clear hitStop (0.06s) + advance 1.0s (< 1.2s) -> Still displaying Ippon call
      game.update(0.06);
      game.update(1.00);
      expect(game.isMatchOverResultPending, isTrue);
      expect(
        ['面あり', '小手あり', '胴あり'].contains(game.overlayTextNotifier.value),
        isTrue,
      );

      // Advance 0.5s (total 1.5s, between 1.2s and 2.2s) -> Displays "勝負あり！"
      game.update(0.50);
      expect(game.isMatchOverResultPending, isTrue);
      expect(game.overlayTextNotifier.value, equals('勝負あり！'));

      // Advance another 0.8s (total 2.3s > 2.2s) -> Transitions to "あなたの勝ち"
      game.update(0.80);
      expect(game.isMatchOverResultPending, isFalse);
      expect(game.overlayTextNotifier.value, equals('あなたの勝ち'));

      // P2 (CPU) wins -> matchOver with Ippon call (1.2s) -> "勝負あり！" (1.0s) -> "あなたの負け"
      final game2 = KendoGame();
      await game2.onLoad();
      game2.isRoundStarting = false;

      game2.p2.winCount = 1;
      game2.p1.position.x = -80.0;
      game2.p2.position.x = 80.0;
      game2.p1.health = 0.0;

      game2.p2.attack();
      game2.p2.update(1.05); // Men strike

      game2.update(0.01);

      expect(game2.p2.winCount, equals(2));
      expect(game2.gameStateNotifier.value, equals(KendoGameState.matchOver));
      expect(game2.isMatchOverResultPending, isTrue);
      expect(
        ['面あり', '小手あり', '胴あり'].contains(game2.overlayTextNotifier.value),
        isTrue,
      );

      // Clear hitStop (0.06s) + advance 1.5s -> Displays "勝負あり！"
      game2.update(0.06);
      game2.update(1.50);
      expect(game2.isMatchOverResultPending, isTrue);
      expect(game2.overlayTextNotifier.value, equals('勝負あり！'));

      // Advance another 0.8s (total 2.3s > 2.2s) -> Transitions to "あなたの負け"
      game2.update(0.80);
      expect(game2.isMatchOverResultPending, isFalse);
      expect(game2.overlayTextNotifier.value, equals('あなたの負け'));
    });
  });

  group('Pass-Through and Turnaround action tests', () {
    test('Attack triggers pass-through even when defender is cornered near stage edge', () async {
      final game = KendoGame();
      await game.onLoad();
      game.isRoundStarting = false;

      // Position defender (P2) near stage edge (X = 480, max is 520)
      game.p1.position.x = 350.0;
      game.p2.position.x = 480.0;
      game.p2.cpuVulnerableTimer = 1.5;

      game.p1.attack();
      game.p1.update(0.20); // Strike window
      game.update(0.01);

      // Pass-through triggers successfully even at corner
      expect(game.p1.isPassingThrough, isTrue);

      game.update(0.90);
      game.update(0.90);

      // Both turn around cleanly
      expect(game.p1.isPassingThrough, isFalse);
      expect(game.p1.isTurningAround, isTrue);
      expect(game.p2.isTurningAround, isTrue);
    });

    test('Attack triggers pass-through when defender has sufficient backSpace', () async {
      final game = KendoGame();
      await game.onLoad();
      game.isRoundStarting = false;

      game.p1.position.x = -80.0;
      game.p2.position.x = 0.0;
      game.p2.cpuVulnerableTimer = 1.5;

      game.p1.attack();
      game.p1.update(0.20); // Strike window
      game.update(0.01);

      expect(game.p1.isPassingThrough, isTrue);

      // P1 moves past P2 to target X (380.0)
      game.update(0.90);
      game.update(0.90);

      // P1 reaches target, triggering turnaround on both fighters
      expect(game.p1.isPassingThrough, isFalse);
      expect(game.p1.isTurningAround, isTrue);
      expect(game.p2.isTurningAround, isTrue);
    });
  });

  group('DojoStage and Fighter positioning tests', () {
    test('DojoStage stageGroundY (0.0) and KendoFighter fighterGroundY (250.0) positioning', () async {
      expect(KendoGame.stageGroundY, equals(0.0));
      expect(KendoGame.fighterGroundY, equals(250.0));

      final game = KendoGame();
      await game.onLoad();
      game.isRoundStarting = false;
      game.update(0.01);

      expect(game.p1.position.y, equals(250.0));
      expect(game.p2.position.y, equals(250.0));
      expect(game.camera.viewfinder.position.x, equals(0.0));
      expect(game.camera.viewfinder.position.y, equals(0.0));
      expect(game.camera.viewfinder.zoom, equals(1.0));

      final stage = DojoStage(stageWidth: KendoGame.stageWidth, groundY: KendoGame.stageGroundY);
      expect(stage.size.x, equals(1280.0));
      expect(stage.size.y, equals(720.0));
      expect(stage.position.x, equals(0.0));
      expect(stage.position.y, equals(0.0));
    });
  });

  group('Fighter customization and Zekken (垂ネーム) tests', () {
    test('P1 and P2 have distinct Hakama and Do Band colors, and 1.5x vertical Zekken dimensions', () async {
      final game = KendoGame();
      await game.onLoad();

      // P1: Navy Hakama, Red Do Band
      expect(game.p1.hakamaColor, equals(const Color(0xFF1A237E)));
      expect(game.p1.doBandColor, equals(const Color(0xFFD32F2F)));

      // P2: Black Hakama, White Do Band
      expect(game.p2.hakamaColor, equals(const Color(0xFF212121)));
      expect(game.p2.doBandColor, equals(const Color(0xFFFAFAFA)));

      // Zekken (垂ネーム): Width 12.0, Height 21.0 (1.5x of 14.0), Navy background
      expect(KendoFighter.zekkenWidth, equals(12.0));
      expect(KendoFighter.zekkenHeight, equals(21.0));
      expect(KendoFighter.zekkenBackgroundColor, equals(const Color(0xFF102040)));
    });

    test('resetMatch selects non-repeating CPU name when multiple CPU names exist', () async {
      await ScoreManager.setPlayerName('赤胴');
      await ScoreManager.setCpuNames(['佐藤', '鈴木', '高橋']);
      ScoreManager.resetLastSelectedCpuName();

      final game = KendoGame();
      await game.onLoad();

      expect(game.p1.name, equals('赤胴'));
      expect(['佐藤', '鈴木', '高橋'].contains(game.p2.name), isTrue);

      String lastCpu = game.p2.name;
      for (int i = 0; i < 15; i++) {
        game.resetMatch();
        expect(game.p2.name, isNot(equals(lastCpu)));
        lastCpu = game.p2.name;
      }

      // Restore defaults
      await ScoreManager.setPlayerName(ScoreManager.defaultPlayerName);
      await ScoreManager.setCpuNames(ScoreManager.defaultCpuNames);
    });
  });
}
```

---

## 4. 検証と `REPORT.md` の出力手順

1. 以下のコマンドを実行し、静的解析エラー・警告が0件であること、および全テストが通過することを確認してください。
```bash
flutter analyze
flutter test
```

2. 検証完了後、プロジェクトルートの `REPORT.md` を以下のフォーマットで上書き出力してください。

```markdown
# 開発報告書: 対戦画面（GamePage）の90度自動回転（RotatedBox）廃止と縦持ち直接プレイ仕様への復元

## 1. 概要
- 対戦画面（`GamePage`）における `RotatedBox(quarterTurns: 1)` による90度自動回転処理を廃止し、縦持ち（縦レイアウト）の状態でもそのままの向きで対戦画面を表示・プレイできる旧仕様に戻しました。
- アプリ全体で `DeviceOrientation.values`（全方向許可）とし、縦持ち・横持ちのどちらでもそのままの向きで操作できるように統一しました。

## 2. 実施内容
- `lib/main.dart`:
  - `GamePage` の `initState` / `dispose` における画面向き固定処理を削除。
  - `GamePage.build` から `LayoutBuilder` および `RotatedBox(quarterTurns: 1)` を削除し、`GameWidget<KendoGame>` を直接描画する構成に復元。
- `test/widget_test.dart`:
  - 縦画面（400×800）での起動・対戦開始テストにて、`RotatedBox` が存在しないこと、および縦画面のまま対戦HUDが表示されることを検証するように更新。
- `CURRENT_CONTEXT.md`:
  - 画面の向き（オリエンテーション）規約を最新仕様に更新。

## 3. 修正ファイル一覧
1. `lib/main.dart`
2. `test/widget_test.dart`
3. `CURRENT_CONTEXT.md`
4. `REPORT.md`

## 4. 検証結果
### flutter analyze の実行結果
（ここに実際の出力結果を記載）

### flutter test の実行結果
（ここに実際の出力結果を記載）
```

Now let's run `flutter analyze` via `run_shell_command`!

Now let's run `flutter analyze` via `run_shell_command`!5. **`REPORT.md` の出力**:
   - 作業完了後、実施内容・修正ファイル・検証結果（`flutter analyze` および `flutter test`）を `REPORT.md` に上書き記録する。

---

## 3. 具体的なファイル修正内容

### 3.1 `lib/main.dart`
`lib/main.dart` を以下の内容に完全置換してください（省略なし）。

```dart
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/kendo_game.dart';
import 'screens/title_screen.dart';
import 'widgets/fighting_hud.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 縦持ち・横持ちのどちらでもそのままの向きで操作・プレイできるよう全方向を許可する
  await SystemChrome.setPreferredOrientations(DeviceOrientation.values);

  runApp(const KewpieCupApp());
}

class KewpieCupApp extends StatelessWidget {
  const KewpieCupApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kewpie_cup',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D0D11),
      ),
      home: const TitleScreen(),
    );
  }
}

class GamePage extends StatefulWidget {
  const GamePage({
    super.key,
    this.isDebugEnabled = false,
  });

  final bool isDebugEnabled;

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late final KendoGame game;

  @override
  void initState() {
    super.initState();
    game = KendoGame();
    game.isDebugVisibleNotifier.value = widget.isDebugEnabled;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D11),
      body: GameWidget<KendoGame>(
        game: game,
        overlayBuilderMap: {
          'HudOverlay': (context, game) => FightingHudOverlay(game: game),
        },
        initialActiveOverlays: const ['HudOverlay'],
      ),
    );
  }
}
```

### 3.2 `test/widget_test.dart`
`test/widget_test.dart` を以下の内容に完全置換してください（省略なし）。

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kewpie_cup/game/audio/sound_manager.dart';
import 'package:kewpie_cup/game/components/dojo_stage.dart';
import 'package:kewpie_cup/game/components/kendo_fighter.dart';
import 'package:kewpie_cup/game/enums/facing_direction.dart';
import 'package:kewpie_cup/game/kendo_game.dart';
import 'package:kewpie_cup/game/score/score_manager.dart';
import 'package:kewpie_cup/main.dart';
import 'package:kewpie_cup/widgets/fighting_hud.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    // Disable sound playback for headless unit testing environment
    SoundManager.isEnabled = false;
  });

  testWidgets('Kewpie_cup title screen loads with menu options including 選手登録 and starts match',
      (WidgetTester tester) async {
    await ScoreManager.clearScore();
    await ScoreManager.setPlayerName('剣士');
    await ScoreManager.setCpuNames(['佐藤', '鈴木']);
    await tester.pumpWidget(const KewpieCupApp());
    await tester.pump();

    // Verify Title Screen menu buttons
    expect(find.text('試合開始'), findsOneWidget);
    expect(find.text('選手登録'), findsOneWidget);
    expect(find.text('心得'), findsOneWidget);
    expect(find.text('設定'), findsOneWidget);

    // 1 win should NOT display "1連勝中"
    await ScoreManager.recordWin();
    await tester.pump();
    expect(find.textContaining('1連勝中'), findsNothing);

    // 2 wins SHOULD display "2連勝中"
    await ScoreManager.recordWin();
    await tester.pump();
    expect(find.textContaining('2連勝中'), findsOneWidget);

    await ScoreManager.clearScore();
    await tester.pump();

    // Tap '試合開始' to enter GamePage
    await tester.tap(find.text('試合開始'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify Game HUD text and action buttons are rendered
    expect(find.textContaining('1P 剣士'), findsOneWidget);
    expect(find.textContaining('(CPU)'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
  });

  testWidgets('Portrait screen does NOT show landscape warning overlay and allows playing directly in portrait without RotatedBox',
      (WidgetTester tester) async {
    // Simulate portrait smartphone screen (width 400 < height 800)
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await ScoreManager.setPlayerName('剣士');
    await tester.pumpWidget(const KewpieCupApp());
    await tester.pump();

    // Verify the old landscape recommendation overlay is abolished
    expect(find.text('画面を横向きにしてください'), findsNothing);
    expect(find.text('選手登録'), findsOneWidget);

    // Start match directly from portrait screen
    await tester.tap(find.text('試合開始'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify GamePage is rendered directly in portrait without RotatedBox
    expect(find.byKey(const ValueKey('auto_landscape_rotated_box')), findsNothing);
    expect(find.byType(RotatedBox), findsNothing);
    expect(find.textContaining('1P 剣士'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
  });

  testWidgets('Health bars deplete from outer edges toward center (Street Fighter II style)',
      (WidgetTester tester) async {
    final game = KendoGame();
    await game.onLoad();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FightingHudOverlay(game: game),
        ),
      ),
    );
    await tester.pump();

    // Set both P1 and P2 health to 50%
    game.p1HealthNotifier.value = 50.0;
    game.p2HealthNotifier.value = 50.0;
    await tester.pump();

    final p1BarRect = tester.getRect(find.byKey(const ValueKey('p1_health_bar')));
    final p1FillRect = tester.getRect(find.byKey(const ValueKey('p1_health_fill')));

    final p2BarRect = tester.getRect(find.byKey(const ValueKey('p2_health_bar')));
    final p2FillRect = tester.getRect(find.byKey(const ValueKey('p2_health_fill')));

    // P1 (Left side): Yellow remaining health must be anchored to the RIGHT (center timer side),
    // so the LEFT (outer edge) is depleted!
    expect(p1FillRect.right, closeTo(p1BarRect.right - 2.0, 0.5));
    expect(p1FillRect.left, greaterThan(p1BarRect.left + 10.0));

    // P2 (Right side): Yellow remaining health must be anchored to the LEFT (center timer side),
    // so the RIGHT (outer edge) is depleted!
    expect(p2FillRect.left, closeTo(p2BarRect.left + 2.0, 0.5));
    expect(p2FillRect.right, lessThan(p2BarRect.right - 10.0));
  });

  group('ScoreManager persistent score tracking, player registration and clear tests', () {
    test('setPlayerName and setCpuNames persist up to 10 names (2-3 chars) and prevent consecutive duplicate selection', () async {
      await ScoreManager.setPlayerName('佐々木');
      expect(ScoreManager.playerNameNotifier.value, equals('佐々木'));

      final tenNames = [
        '佐藤', '鈴木', '高橋', '田中', '渡辺',
        '伊藤', '山本', '中村', '小林', '加藤',
        '吉田', // 11th item -> should be capped at 10
      ];
      await ScoreManager.setCpuNames(tenNames);
      expect(ScoreManager.cpuNamesNotifier.value.length, equals(10));
      expect(ScoreManager.cpuNamesNotifier.value.contains('吉田'), isFalse);

      // Verify persistence across loadScore()
      ScoreManager.playerNameNotifier.value = '初期';
      ScoreManager.cpuNamesNotifier.value = ['初期'];
      await ScoreManager.loadScore();
      expect(ScoreManager.playerNameNotifier.value, equals('佐々木'));
      expect(ScoreManager.cpuNamesNotifier.value.length, equals(10));

      // Verify non-repeating random selection when multiple CPU names are registered
      await ScoreManager.setCpuNames(['佐藤', '鈴木', '高橋']);
      ScoreManager.resetLastSelectedCpuName();
      String previous = ScoreManager.pickRandomCpuName();
      for (int i = 0; i < 30; i++) {
        final next = ScoreManager.pickRandomCpuName();
        expect(next, isNot(equals(previous)));
        previous = next;
      }

      // Restore defaults
      await ScoreManager.setPlayerName(ScoreManager.defaultPlayerName);
      await ScoreManager.setCpuNames(ScoreManager.defaultCpuNames);
    });

    test('setSoundEnabled and setDebugEnabled persist settings across loadScore calls', () async {
      // Save settings directly in SharedPreferences for testing persistence
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('kewpie_sound_enabled', true);
      await prefs.setBool('kewpie_debug_enabled', true);

      // Reset in-memory values
      ScoreManager.soundEnabledNotifier.value = false;
      ScoreManager.debugEnabledNotifier.value = false;

      // Verify SharedPreferences values are loaded
      final savedSound = prefs.getBool('kewpie_sound_enabled') ?? false;
      ScoreManager.soundEnabledNotifier.value = savedSound;

      final savedDebug = prefs.getBool('kewpie_debug_enabled') ?? false;
      ScoreManager.debugEnabledNotifier.value = savedDebug;

      expect(ScoreManager.soundEnabledNotifier.value, isTrue);
      expect(ScoreManager.debugEnabledNotifier.value, isTrue);

      // Restore defaults
      await prefs.setBool('kewpie_sound_enabled', false);
      await prefs.setBool('kewpie_debug_enabled', false);
      ScoreManager.soundEnabledNotifier.value = false;
      SoundManager.isEnabled = false;
      ScoreManager.debugEnabledNotifier.value = false;
    });

    test('setGuardDuration updates KendoFighter.guardActiveDuration within 0.2..1.0 and persists setting', () async {
      await ScoreManager.setGuardDuration(0.8);
      expect(KendoFighter.guardActiveDuration, equals(0.8));

      final fighter = KendoFighter(
        name: 'TestFighter',
        isPlayer: true,
        startX: -100.0,
        groundY: 0.0,
        keikogiColor: Colors.white,
        ribbonColor: Colors.red,
      );

      fighter.startGuard();
      expect(fighter.isGuarding, isTrue);

      // Advance 0.6s (out of 0.8s active duration) -> still guarding!
      fighter.update(0.60);
      expect(fighter.isGuarding, isTrue);

      // Advance another 0.3s (total 0.9s) -> guard expires
      fighter.update(0.30);
      expect(fighter.isGuarding, isFalse);

      // Reset back to default 0.4s
      await ScoreManager.setGuardDuration(0.4);
      expect(KendoFighter.guardActiveDuration, equals(0.4));
    });

    test('recordWin increments wins and streak, recordLoss increments losses and resets streak', () async {
      await ScoreManager.clearScore();
      expect(ScoreManager.winsNotifier.value, equals(0));
      expect(ScoreManager.lossesNotifier.value, equals(0));
      expect(ScoreManager.streakNotifier.value, equals(0));

      await ScoreManager.recordWin();
      expect(ScoreManager.winsNotifier.value, equals(1));
      expect(ScoreManager.streakNotifier.value, equals(1));

      await ScoreManager.recordWin();
      expect(ScoreManager.winsNotifier.value, equals(2));
      expect(ScoreManager.streakNotifier.value, equals(2));

      await ScoreManager.recordLoss();
      expect(ScoreManager.winsNotifier.value, equals(2));
      expect(ScoreManager.lossesNotifier.value, equals(1));
      expect(ScoreManager.streakNotifier.value, equals(0));

      await ScoreManager.clearScore();
      expect(ScoreManager.winsNotifier.value, equals(0));
      expect(ScoreManager.lossesNotifier.value, equals(0));
      expect(ScoreManager.streakNotifier.value, equals(0));
    });
  });

  group('Pre-round start sequence and facing direction tests ("はじめ！" / "二本目！" / "勝負！")', () {
    test('Round 1 displays はじめ！ only for 1.2s then starts fight', () async {
      final game = KendoGame();
      await game.onLoad();

      expect(game.isRoundStarting, isTrue);
      expect(game.overlayTextNotifier.value, equals('はじめ！'));

      // Advance 0.8s -> still "はじめ！"
      game.update(0.80);
      expect(game.isRoundStarting, isTrue);
      expect(game.overlayTextNotifier.value, equals('はじめ！'));

      // Advance 0.5s (total 1.3s > 1.2s) -> pre-round sequence finishes, active fight begins!
      game.update(0.50);
      expect(game.isRoundStarting, isFalse);
      expect(game.overlayTextNotifier.value, equals(''));
    });

    test('Round title text is はじめ！ for round 1, 二本目！ for round 2, and 勝負！ for round 3', () async {
      final game = KendoGame();
      await game.onLoad();

      // Round 1 (0 wins)
      expect(game.currentRoundTitleText, equals('はじめ！'));

      // Set P1 winCount = 1 (Round 2)
      game.p1.winCount = 1;
      expect(game.currentRoundTitleText, equals('二本目！'));

      // Set P2 winCount = 1 (Round 3: 1-1 tie)
      game.p2.winCount = 1;
      expect(game.currentRoundTitleText, equals('勝負！'));
    });

    test('Fighters face inward (each other) immediately when Round 2 starts even if swapped in Round 1', () async {
      final game = KendoGame();
      await game.onLoad();
      game.isRoundStarting = false;

      // Simulate swapped positions & outward facing directions at the end of Round 1
      game.p1.position.x = 200.0;
      game.p2.position.x = 100.0;
      game.p1.facingDirection = FacingDirection.left;
      game.p2.facingDirection = FacingDirection.right;
      game.p2.health = 34.0;
      game.p2.cpuVulnerableTimer = 1.5;

      // P1 scores Ippon to end Round 1
      game.p1.attack();
      game.p1.update(0.20);
      game.update(0.01);

      expect(game.gameStateNotifier.value, equals(KendoGameState.roundOver));

      // Clear hitStop (0.06s) + advance roundOverDelay (2.0s) to trigger Round 2 start
      game.update(0.06);
      game.update(2.05);

      // Immediately at the start of Round 2 ("二本目！"), both fighters must face inward!
      expect(game.isRoundStarting, isTrue);
      expect(game.overlayTextNotifier.value, equals('二本目！'));
      expect(game.p1.position.x, equals(-260.0));
      expect(game.p2.position.x, equals(440.0));
      expect(game.p1.facingDirection, equals(FacingDirection.right));
      expect(game.p2.facingDirection, equals(FacingDirection.left));
    });
  });

  group('KendoFighter logic and 2-phase attack tests', () {
    test('startGuard reduces movement speed and sets isGuarding flag', () {
      final fighter = KendoFighter(
        name: 'TestFighter',
        isPlayer: true,
        startX: -100.0,
        groundY: 0.0,
        keikogiColor: Colors.white,
        ribbonColor: Colors.red,
      );

      fighter.move(1.0);
      expect(fighter.velocityX, equals(fighter.walkSpeed));

      fighter.startGuard();
      expect(fighter.isGuarding, isTrue);
      expect(
          fighter.velocityX, equals(fighter.walkSpeed * fighter.guardSpeedMultiplier));

      fighter.stopGuard();
      expect(fighter.isGuarding, isFalse);
    });

    test('startGuard active duration (0.4s) auto-expires and enters 0.2s cooldown', () {
      final fighter = KendoFighter(
        name: 'TestFighter',
        isPlayer: true,
        startX: -100.0,
        groundY: 0.0,
        keikogiColor: Colors.white,
        ribbonColor: Colors.red,
      );

      fighter.startGuard();
      expect(fighter.isGuarding, isTrue);

      // Active guard duration (0.2s elapsed out of 0.4s)
      fighter.update(0.20);
      expect(fighter.isGuarding, isTrue);

      // Total 0.45s elapsed -> Guard automatically expires!
      fighter.update(0.25);
      expect(fighter.isGuarding, isFalse);
      expect(fighter.guardCooldownTimer, greaterThan(0.0));

      // Attempting to guard during cooldown fails
      fighter.startGuard();
      expect(fighter.isGuarding, isFalse);

      // Cooldown expires (0.25s)
      fighter.update(0.25);
      expect(fighter.guardCooldownTimer, equals(0.0));

      // Guard can be triggered again after cooldown
      fighter.startGuard();
      expect(fighter.isGuarding, isTrue);
    });

    test('2-phase lunge attack provides forward velocity and clears guard', () {
      final fighter = KendoFighter(
        name: 'TestFighter',
        isPlayer: true,
        startX: -100.0,
        groundY: 0.0,
        keikogiColor: Colors.white,
        ribbonColor: Colors.red,
      );

      fighter.startGuard();
      fighter.attack();
      expect(fighter.isAttacking, isTrue);
      expect(fighter.isGuarding, isFalse);

      // Phase 1 (0.00s - 0.18s): Forward windup lunge
      fighter.update(0.10);
      expect(fighter.velocityX, greaterThan(0));

      // Phase 2 (0.18s - 0.38s): Forward strike lunge
      fighter.update(0.10); // total 0.20s
      expect(fighter.velocityX, greaterThan(0));
    });

    test('disengage triggers rapid backward backstep velocity', () {
      final fighter = KendoFighter(
        name: 'TestFighter',
        isPlayer: true,
        startX: -100.0,
        groundY: 0.0,
        keikogiColor: Colors.white,
        ribbonColor: Colors.red,
      );

      fighter.disengage();
      expect(fighter.isDisengaging, isTrue);

      // Facing right -> backward direction is left (-velocityX)
      fighter.update(0.10);
      expect(fighter.velocityX, equals(-KendoFighter.disengageSpeed));

      // Complete disengage duration (0.25s)
      fighter.update(0.20);
      expect(fighter.isDisengaging, isFalse);
    });
  });

  group('Unified input handlers and Q/E hotkey tests', () {
    test('Far range attack input (dist > 255) advances 1 step (0.35s) and automatically stops', () async {
      final game = KendoGame();
      await game.onLoad();
      game.isRoundStarting = false;

      game.p1.position.x = -260.0;
      game.p2.position.x = 440.0; // Distance = 700px > 255px

      game.attackP1();
      expect(game.p1.isAttacking, isFalse);
      expect(game.p1.isFarAdvancing, isTrue);
      expect(game.p1.velocityX, greaterThan(0));

      // Advance 0.36s (past 0.35s 1-step duration) -> Automatically stops!
      game.p1.update(0.36);
      expect(game.p1.isFarAdvancing, isFalse);
      expect(game.p1.velocityX, equals(0.0));
    });

    test('Enemy on right: Left input (Q) guards, Right input (E) attacks', () async {
      final game = KendoGame();
      await game.onLoad();
      game.isRoundStarting = false;

      game.p1.position.x = -80.0;
      game.p2.position.x = 80.0; // Close strike range

      // Left input -> Guard start
      game.handleLeftInputDown();
      expect(game.p1.isGuarding, isTrue);

      // Guard stays active for guardActiveDuration (0.4s) without premature cancel on release
      game.p1.update(0.45);
      expect(game.p1.isGuarding, isFalse);

      // Right input -> Attack
      game.handleRightInputDown();
      expect(game.p1.isAttacking, isTrue);
    });

    test('Enemy on left: Left input (Q) attacks, Right input (E) guards', () async {
      final game = KendoGame();
      await game.onLoad();
      game.isRoundStarting = false;

      game.p1.position.x = 80.0;
      game.p2.position.x = -80.0; // Close strike range

      // Left input -> Attack
      game.handleLeftInputDown();
      expect(game.p1.isAttacking, isTrue);

      game.p1.isAttacking = false;

      // Right input -> Guard start
      game.handleRightInputDown();
      expect(game.p1.isGuarding, isTrue);

      // Guard stays active for guardActiveDuration (0.4s)
      game.p1.update(0.45);
      expect(game.p1.isGuarding, isFalse);
    });

    test('Inputs are ignored during roundOver and matchOver states', () async {
      final game = KendoGame();
      await game.onLoad();
      game.isRoundStarting = false;

      // Test during roundOver
      game.gameStateNotifier.value = KendoGameState.roundOver;
      game.attackP1();
      game.guardP1Start();
      game.disengageP1();
      game.moveP1Right();
      expect(game.p1.isAttacking, isFalse);
      expect(game.p1.isFarAdvancing, isFalse);
      expect(game.p1.isGuarding, isFalse);
      expect(game.p1.isDisengaging, isFalse);
      expect(game.p1.velocityX, equals(0.0));

      // Test during matchOver
      game.gameStateNotifier.value = KendoGameState.matchOver;
      game.handleLeftInputDown();
      game.handleRightInputDown();
      game.disengageP1();
      game.moveP1Left();
      expect(game.p1.isAttacking, isFalse);
      expect(game.p1.isFarAdvancing, isFalse);
      expect(game.p1.isGuarding, isFalse);
      expect(game.p1.isDisengaging, isFalse);
      expect(game.p1.velocityX, equals(0.0));
    });
  });

  group('CPU 2-phase attack and Sen-no-sen (先守後攻) combat tests', () {
    test('CPU attack flashes red background at blinking end and attacks 0.5s later', () async {
      final game = KendoGame();
      await game.onLoad();
      game.isRoundStarting = false;

      // Initiate CPU attack with 0.5s blink (total windup = 0.5s blink + 0.5s hold = 1.0s)
      game.p2.attack(blinkDuration: 0.5);

      // Advance to 0.40s (during white blinking) -> flashAlpha == 0
      game.p2.update(0.40);
      game.update(0.01);
      expect(game.stage.flashAlpha, equals(0.0));

      // Advance to 0.55s (just after blinking ends at 0.50s) -> flashAlpha > 0 (Red flash triggered!)
      game.p2.update(0.15);
      game.update(0.01);
      expect(game.stage.flashAlpha, greaterThan(0.0));

      // Advance to 1.05s (0.5s after blinking ends / strike connected) -> flashAlpha == 0
      game.p2.update(0.50);
      game.update(0.01);
      expect(game.stage.flashAlpha, equals(0.0));
    });

    test('CPU 3-tier attack windup durations (0.3s Short, 0.5s Medium, 0.8s Long) hit after 0.5s hold time', () async {
      final game = KendoGame();
      await game.onLoad();
      game.isRoundStarting = false;

      // Short (0.3s flash + 0.5s hold = 0.8s total windup)
      game.p2.attack(blinkDuration: 0.3);
      expect(game.p2.currentBlinkDuration, equals(0.3));
      game.p2.update(0.79);
      expect(game.p2.attackTimer, lessThan(0.80));
      game.p2.update(0.02); // total 0.81s
      expect(game.p2.attackTimer, greaterThanOrEqualTo(0.80));

      // Reset P2 attack
      game.p2.isAttacking = false;
      game.p2.attackTimer = 0.0;

      // Long (0.8s flash + 0.5s hold = 1.3s total windup)
      game.p2.attack(blinkDuration: 0.8);
      expect(game.p2.currentBlinkDuration, equals(0.8));
      game.p2.update(1.29);
      expect(game.p2.attackTimer, lessThan(1.30));
      game.p2.update(0.02); // total 1.31s
      expect(game.p2.attackTimer, greaterThanOrEqualTo(1.30));
    });

    test('CPU attack has 1.0s windup phase followed by Men strike phase', () async {
      final game = KendoGame();
      await game.onLoad();
      game.isRoundStarting = false;

      game.p2.attack(blinkDuration: 0.5);
      expect(game.p2.isAttacking, isTrue);

      // Phase 1 Windup (0.0s - 1.0s)
      game.p2.update(0.50);
      expect(game.p2.attackTimer, equals(0.50));
      expect(game.p2.attackTimer, lessThan(1.0));

      // Phase 2 Men Strike (1.0s - 1.3s)
      game.p2.update(0.55); // total 1.05s
      expect(game.p2.attackTimer, greaterThanOrEqualTo(1.0));
    });

    test('Normal state: Player attack is automatically blocked by CPU (0 damage)', () async {
      final game = KendoGame();
      await game.onLoad();
      game.isRoundStarting = false;

      game.p1.position.x = -80.0;
      game.p2.position.x = 80.0;
      game.p2.cpuVulnerableTimer = 0.0; // Normal state

      game.p1.attack();
      game.p1.update(0.20); // Strike window

      game.update(0.01);

      expect(game.p2.health, equals(100.0)); // Auto-blocked by CPU!
      expect(game.p1.winCount, equals(0));
    });

    test('Guarded defender blocks incoming 2-phase lunge attack and triggers Counter Opportunity', () async {
      final game = KendoGame();
      await game.onLoad();
      game.isRoundStarting = false;

      game.p1.position.x = -80.0;
      game.p2.position.x = 80.0;

      game.p1.startGuard(); // Player guards
      game.p2.attack(blinkDuration: 0.5);
      game.p2.update(1.05); // Advance to Men strike phase (1.0s+)

      game.update(0.01);

      expect(game.p1.health, equals(100.0)); // Player blocked CPU strike!
      expect(game.p2.cpuVulnerableTimer, greaterThan(0.0)); // CPU enters Counter Opportunity!
    });

    test('Counter Opportunity: 3 hits (34.0 damage each) reduce health from 100.0 to 0.0 and score Ippon', () async {
      final game = KendoGame();
      await game.onLoad();
      game.isRoundStarting = false;

      // Hit 1: 100.0 -> 66.0
      game.p1.position.x = -80.0;
      game.p2.position.x = 80.0;
      game.p2.cpuVulnerableTimer = 1.5;
      game.p1.attack();
      game.p1.update(0.20);
      game.update(0.01);
      expect(game.p2.health, equals(66.0));
      expect(game.p1.winCount, equals(0));

      // Clear hitStop & passThrough for Hit 2: 66.0 -> 32.0
      game.hitStopTimer = 0.0;
      game.p1.stopAllActions();
      game.p2.stopAllActions();
      game.p1.hitStunTimer = 0.0;
      game.p2.hitStunTimer = 0.0;
      game.p1.position.x = -80.0;
      game.p2.position.x = 80.0;
      game.p2.cpuVulnerableTimer = 1.5;
      game.p1.attack();
      game.p1.update(0.20);
      game.update(0.01);
      expect(game.p2.health, equals(32.0));
      expect(game.p1.winCount, equals(0));

      // Clear hitStop & passThrough for Hit 3: 32.0 -> 0.0 (Ippon!)
      game.hitStopTimer = 0.0;
      game.p1.stopAllActions();
      game.p2.stopAllActions();
      game.p1.hitStunTimer = 0.0;
      game.p2.hitStunTimer = 0.0;
      game.p1.position.x = -80.0;
      game.p2.position.x = 80.0;
      game.p2.cpuVulnerableTimer = 1.5;
      game.p1.attack();
      game.p1.update(0.20);
      game.update(0.01);

      expect(game.p2.health, equals(0.0)); // 3rd counter hit scores Ippon!
      expect(game.p1.winCount, equals(1));
      expect(game.gameStateNotifier.value, equals(KendoGameState.roundOver));
      expect(
        ['面あり', '小手あり', '胴あり'].contains(game.overlayTextNotifier.value),
        isTrue,
      );
    });
  });

  group('KendoGame pause function tests', () {
    test('togglePause toggles isPausedNotifier and suppresses movement', () async {
      final game = KendoGame();
      await game.onLoad();
      game.isRoundStarting = false;

      expect(game.isPausedNotifier.value, isFalse);

      // Pause
      game.togglePause();
      expect(game.isPausedNotifier.value, isTrue);

      // Movement should be ignored during pause
      game.moveP1Right();
      expect(game.p1.velocityX, equals(0.0));

      // Resume
      game.togglePause();
      expect(game.isPausedNotifier.value, isFalse);

      game.moveP1Right();
      expect(game.p1.velocityX, equals(game.p1.walkSpeed));
    });
  });

  group('KendoGame combat, Tsubazeriai and match rules tests', () {
    test('rollIpponCallText returns 面あり (50%), 小手あり (40%), 胴あり (10%) according to probability', () async {
      final game = KendoGame();
      await game.onLoad();

      expect(game.rollIpponCallText(0.00), equals('面あり'));
      expect(game.rollIpponCallText(0.49), equals('面あり'));
      expect(game.rollIpponCallText(0.50), equals('小手あり'));
      expect(game.rollIpponCallText(0.89), equals('小手あり'));
      expect(game.rollIpponCallText(0.90), equals('胴あり'));
      expect(game.rollIpponCallText(0.99), equals('胴あり'));
    });

    test('30-second time-out awards Ippon to CPU and displays やめ！ then 勝負あり！ on 2nd win', () async {
      final game = KendoGame();
      await game.onLoad();
      game.isRoundStarting = false;

      expect(game.roundTimerNotifier.value, equals(30));

      // Advance time by 30.1 seconds
      game.update(30.1);

      // CPU (p2) receives win from time-out with "やめ！"
      expect(game.p2.winCount, equals(1));
      expect(game.gameStateNotifier.value, equals(KendoGameState.roundOver));
      expect(game.overlayTextNotifier.value, equals('やめ！'));

      // 2nd time-out leads to matchOver displaying "やめ！" (1.2s) -> "勝負あり！" (1.0s) -> "あなたの負け"
      final game2 = KendoGame();
      await game2.onLoad();
      game2.isRoundStarting = false;
      game2.p2.winCount = 1;

      game2.update(30.1);
      expect(game2.p2.winCount, equals(2));
      expect(game2.gameStateNotifier.value, equals(KendoGameState.matchOver));
      expect(game2.isMatchOverResultPending, isTrue);
      expect(game2.overlayTextNotifier.value, equals('やめ！'));

      // Advance 1.3s (into Phase 2: 1.2s..2.2s) -> Displays "勝負あり！"
      game2.update(1.3);
      expect(game2.isMatchOverResultPending, isTrue);
      expect(game2.overlayTextNotifier.value, equals('勝負あり！'));

      // Advance another 1.0s (total 2.3s > 2.2s) -> Transitions to "あなたの負け"
      game2.update(1.0);
      expect(game2.isMatchOverResultPending, isFalse);
      expect(game2.overlayTextNotifier.value, equals('あなたの負け'));
    });

    test('Close contact distance triggers Tsubazeriai state', () async {
      final game = KendoGame();
      await game.onLoad();
      game.isRoundStarting = false;

      // Position fighters within Tsubazeriai distance (<= 114.0px)
      game.p1.position.x = -40.0;
      game.p2.position.x = 40.0; // distance 80.0px

      game.update(0.01);

      expect(game.p1.isTsubazeriai, isTrue);
      expect(game.p2.isTsubazeriai, isTrue);
    });

    test('Tsubazeriai Rule [1]: P1 on left of P2 and left of center (< 0), double-tap attack smoothly pushes P2 to right edge at 1.5x disengage speed', () async {
      final game = KendoGame();
      await game.onLoad();
      game.isRoundStarting = false;

      // P1 is left of P2 (-200 < -100) and left of center (-200 < 0)
      game.p1.position.x = -200.0;
      game.p2.position.x = -100.0;
      game.p1.isTsubazeriai = true;
      game.p2.isTsubazeriai = true;

      // Double-tap attack starts continuous push-back at 1.5x disengage speed (480.0 px/s)
      game.attackP1(forceDoubleTap: true);

      expect(game.p1.isTsubazeriai, isFalse);
      expect(game.p2.isTsubazeriai, isFalse);
      expect(game.p2.isPushedBack, isTrue);
      expect(game.p2.velocityX, equals(KendoFighter.disengageSpeed * 1.5));
      expect(game.p2.position.x, equals(-100.0)); // Does NOT warp immediately

      // Advance 0.5s -> P2 moves halfway (+240px to 140.0) while still visible & moving
      game.update(0.50);
      expect(game.p2.isPushedBack, isTrue);
      expect(game.p2.position.x, closeTo(140.0, 1.0));

      // Advance 0.80s (total 1.30s >= 1.29s needed) -> P2 reaches right edge (stageMaxX = 520.0) and stops
      game.update(0.80);
      expect(game.p2.isPushedBack, isFalse);
      expect(game.p2.position.x, equals(game.stageMaxX));
    });

    test('Tsubazeriai Rule [2]: P1 on right of P2 and right of center (> 0), double-tap attack smoothly pushes P2 to left edge at 1.5x disengage speed', () async {
      final game = KendoGame();
      await game.onLoad();
      game.isRoundStarting = false;

      // P1 is right of P2 (200 > 100) and right of center (200 > 0)
      game.p1.position.x = 200.0;
      game.p2.position.x = 100.0;
      game.p1.isTsubazeriai = true;
      game.p2.isTsubazeriai = true;

      // Double-tap attack starts continuous push-back at -1.5x disengage speed (-480.0 px/s)
      game.attackP1(forceDoubleTap: true);

      expect(game.p1.isTsubazeriai, isFalse);
      expect(game.p2.isTsubazeriai, isFalse);
      expect(game.p2.isPushedBack, isTrue);
      expect(game.p2.velocityX, equals(-KendoFighter.disengageSpeed * 1.5));
      expect(game.p2.position.x, equals(100.0)); // Does NOT warp immediately

      // Advance 0.5s -> P2 moves halfway (-240px to -140.0) while still visible & moving
      game.update(0.50);
      expect(game.p2.isPushedBack, isTrue);
      expect(game.p2.position.x, closeTo(-140.0, 1.0));

      // Advance 0.80s (total 1.30s >= 1.29s needed) -> P2 reaches left edge (stageMinX = -520.0) and stops
      game.update(0.80);
      expect(game.p2.isPushedBack, isFalse);
      expect(game.p2.position.x, equals(game.stageMinX));
    });

    test('2 wins displays Ippon call (1.2s) -> 勝負あり！ (1.0s) -> あなたの勝ち or あなたの負け', () async {
      final game = KendoGame();
      await game.onLoad();
      game.isRoundStarting = false;

      // P1 (Player) wins 2nd round -> matchOver with Ippon call (1.2s) -> "勝負あり！" (1.0s) -> "あなたの勝ち"
      game.p1.winCount = 1;
      game.p1.position.x = -80.0;
      game.p2.position.x = 80.0;
      game.p2.health = 0.0;
      game.p2.cpuVulnerableTimer = 1.5;

      game.p1.attack();
      game.p1.update(0.20);

      game.update(0.01); // Triggers 0.06s hitStop and Ippon call

      expect(game.p1.winCount, equals(2));
      expect(game.gameStateNotifier.value, equals(KendoGameState.matchOver));
      expect(game.isMatchOverResultPending, isTrue);
      expect(
        ['面あり', '小手あり', '胴あり'].contains(game.overlayTextNotifier.value),
        isTrue,
      );

      // Clear hitStop (0.06s) + advance 1.0s (< 1.2s) -> Still displaying Ippon call
      game.update(0.06);
      game.update(1.00);
      expect(game.isMatchOverResultPending, isTrue);
      expect(
        ['面あり', '小手あり', '胴あり'].contains(game.overlayTextNotifier.value),
        isTrue,
      );

      // Advance 0.5s (total 1.5s, between 1.2s and 2.2s) -> Displays "勝負あり！"
      game.update(0.50);
      expect(game.isMatchOverResultPending, isTrue);
      expect(game.overlayTextNotifier.value, equals('勝負あり！'));

      // Advance another 0.8s (total 2.3s > 2.2s) -> Transitions to "あなたの勝ち"
      game.update(0.80);
      expect(game.isMatchOverResultPending, isFalse);
      expect(game.overlayTextNotifier.value, equals('あなたの勝ち'));

      // P2 (CPU) wins -> matchOver with Ippon call (1.2s) -> "勝負あり！" (1.0s) -> "あなたの負け"
      final game2 = KendoGame();
      await game2.onLoad();
      game2.isRoundStarting = false;

      game2.p2.winCount = 1;
      game2.p1.position.x = -80.0;
      game2.p2.position.x = 80.0;
      game2.p1.health = 0.0;

      game2.p2.attack();
      game2.p2.update(1.05); // Men strike

      game2.update(0.01);

      expect(game2.p2.winCount, equals(2));
      expect(game2.gameStateNotifier.value, equals(KendoGameState.matchOver));
      expect(game2.isMatchOverResultPending, isTrue);
      expect(
        ['面あり', '小手あり', '胴あり'].contains(game2.overlayTextNotifier.value),
        isTrue,
      );

      // Clear hitStop (0.06s) + advance 1.5s -> Displays "勝負あり！"
      game2.update(0.06);
      game2.update(1.50);
      expect(game2.isMatchOverResultPending, isTrue);
      expect(game2.overlayTextNotifier.value, equals('勝負あり！'));

      // Advance another 0.8s (total 2.3s > 2.2s) -> Transitions to "あなたの負け"
      game2.update(0.80);
      expect(game2.isMatchOverResultPending, isFalse);
      expect(game2.overlayTextNotifier.value, equals('あなたの負け'));
    });
  });

  group('Pass-Through and Turnaround action tests', () {
    test('Attack triggers pass-through even when defender is cornered near stage edge', () async {
      final game = KendoGame();
      await game.onLoad();
      game.isRoundStarting = false;

      // Position defender (P2) near stage edge (X = 480, max is 520)
      game.p1.position.x = 350.0;
      game.p2.position.x = 480.0;
      game.p2.cpuVulnerableTimer = 1.5;

      game.p1.attack();
      game.p1.update(0.20); // Strike window
      game.update(0.01);

      // Pass-through triggers successfully even at corner
      expect(game.p1.isPassingThrough, isTrue);

      game.update(0.90);
      game.update(0.90);

      // Both turn around cleanly
      expect(game.p1.isPassingThrough, isFalse);
      expect(game.p1.isTurningAround, isTrue);
      expect(game.p2.isTurningAround, isTrue);
    });

    test('Attack triggers pass-through when defender has sufficient backSpace', () async {
      final game = KendoGame();
      await game.onLoad();
      game.isRoundStarting = false;

      game.p1.position.x = -80.0;
      game.p2.position.x = 0.0;
      game.p2.cpuVulnerableTimer = 1.5;

      game.p1.attack();
      game.p1.update(0.20); // Strike window
      game.update(0.01);

      expect(game.p1.isPassingThrough, isTrue);

      // P1 moves past P2 to target X (380.0)
      game.update(0.90);
      game.update(0.90);

      // P1 reaches target, triggering turnaround on both fighters
      expect(game.p1.isPassingThrough, isFalse);
      expect(game.p1.isTurningAround, isTrue);
      expect(game.p2.isTurningAround, isTrue);
    });
  });

  group('DojoStage and Fighter positioning tests', () {
    test('DojoStage stageGroundY (0.0) and KendoFighter fighterGroundY (250.0) positioning', () async {
      expect(KendoGame.stageGroundY, equals(0.0));
      expect(KendoGame.fighterGroundY, equals(250.0));

      final game = KendoGame();
      await game.onLoad();
      game.isRoundStarting = false;
      game.update(0.01);

      expect(game.p1.position.y, equals(250.0));
      expect(game.p2.position.y, equals(250.0));
      expect(game.camera.viewfinder.position.x, equals(0.0));
      expect(game.camera.viewfinder.position.y, equals(0.0));
      expect(game.camera.viewfinder.zoom, equals(1.0));

      final stage = DojoStage(stageWidth: KendoGame.stageWidth, groundY: KendoGame.stageGroundY);
      expect(stage.size.x, equals(1280.0));
      expect(stage.size.y, equals(720.0));
      expect(stage.position.x, equals(0.0));
      expect(stage.position.y, equals(0.0));
    });
  });

  group('Fighter customization and Zekken (垂ネーム) tests', () {
    test('P1 and P2 have distinct Hakama and Do Band colors, and 1.5x vertical Zekken dimensions', () async {
      final game = KendoGame();
      await game.onLoad();

      // P1: Navy Hakama, Red Do Band
      expect(game.p1.hakamaColor, equals(const Color(0xFF1A237E)));
      expect(game.p1.doBandColor, equals(const Color(0xFFD32F2F)));

      // P2: Black Hakama, White Do Band
      expect(game.p2.hakamaColor, equals(const Color(0xFF212121)));
      expect(game.p2.doBandColor, equals(const Color(0xFFFAFAFA)));

      // Zekken (垂ネーム): Width 12.0, Height 21.0 (1.5x of 14.0), Navy background
      expect(KendoFighter.zekkenWidth, equals(12.0));
      expect(KendoFighter.zekkenHeight, equals(21.0));
      expect(KendoFighter.zekkenBackgroundColor, equals(const Color(0xFF102040)));
    });

    test('resetMatch selects non-repeating CPU name when multiple CPU names exist', () async {
      await ScoreManager.setPlayerName('赤胴');
      await ScoreManager.setCpuNames(['佐藤', '鈴木', '高橋']);
      ScoreManager.resetLastSelectedCpuName();

      final game = KendoGame();
      await game.onLoad();

      expect(game.p1.name, equals('赤胴'));
      expect(['佐藤', '鈴木', '高橋'].contains(game.p2.name), isTrue);

      String lastCpu = game.p2.name;
      for (int i = 0; i < 15; i++) {
        game.resetMatch();
        expect(game.p2.name, isNot(equals(lastCpu)));
        lastCpu = game.p2.name;
      }

      // Restore defaults
      await ScoreManager.setPlayerName(ScoreManager.defaultPlayerName);
      await ScoreManager.setCpuNames(ScoreManager.defaultCpuNames);
    });
  });
}
