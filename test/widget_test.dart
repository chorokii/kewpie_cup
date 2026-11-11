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

  testWidgets('Kewpie_cup title screen loads with 3 menu options and starts match',
      (WidgetTester tester) async {
    await ScoreManager.clearScore();
    await tester.pumpWidget(const KewpieCupApp());
    await tester.pump();

    // Verify Title Screen menu buttons
    expect(find.text('試合開始'), findsOneWidget);
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
    expect(find.textContaining('1P 剣士1'), findsOneWidget);
    expect(find.text('2P 剣士2 (CPU)'), findsOneWidget);
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

  group('ScoreManager persistent score tracking and clear tests', () {
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

  group('Pre-round start sequence and facing direction tests ("一本目" -> "はじめ！")', () {
    test('Round 1 displays 一本目 for 2.0s then はじめ！ for 0.8s', () async {
      final game = KendoGame();
      await game.onLoad();

      expect(game.isRoundStarting, isTrue);
      expect(game.overlayTextNotifier.value, equals('一本目'));

      // Advance 1.5s -> still "一本目"
      game.update(1.50);
      expect(game.isRoundStarting, isTrue);
      expect(game.overlayTextNotifier.value, equals('一本目'));

      // Advance 0.6s (total 2.1s) -> transitions to "はじめ！"
      game.update(0.60);
      expect(game.isRoundStarting, isTrue);
      expect(game.overlayTextNotifier.value, equals('はじめ！'));

      // Advance 0.8s (total 2.9s) -> pre-round sequence finishes, active fight begins!
      game.update(0.80);
      expect(game.isRoundStarting, isFalse);
      expect(game.overlayTextNotifier.value, equals(''));
    });

    test('Round title text changes to 二本目 for round 2 and 三本目 for round 3', () async {
      final game = KendoGame();
      await game.onLoad();

      // Round 1
      expect(game.currentRoundTitleText, equals('一本目'));

      // Set P1 winCount = 1 (Round 2)
      game.p1.winCount = 1;
      expect(game.currentRoundTitleText, equals('二本目'));

      // Set P2 winCount = 1 (Round 3)
      game.p2.winCount = 1;
      expect(game.currentRoundTitleText, equals('三本目'));
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

      // Immediately at the start of Round 2 ("二本目"), both fighters must face inward!
      expect(game.isRoundStarting, isTrue);
      expect(game.overlayTextNotifier.value, equals('二本目'));
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

    test('30-second time-out awards Ippon to CPU and displays 時間切れ', () async {
      final game = KendoGame();
      await game.onLoad();
      game.isRoundStarting = false;

      expect(game.roundTimerNotifier.value, equals(30));

      // Advance time by 30.1 seconds
      game.update(30.1);

      // CPU (p2) receives win from time-out with "時間切れ"
      expect(game.p2.winCount, equals(1));
      expect(game.gameStateNotifier.value, equals(KendoGameState.roundOver));
      expect(game.overlayTextNotifier.value, equals('時間切れ'));

      // 2nd time-out leads to matchOver displaying "時間切れ" for 2.0s then "あなたの負け"
      final game2 = KendoGame();
      await game2.onLoad();
      game2.isRoundStarting = false;
      game2.p2.winCount = 1;

      game2.update(30.1);
      expect(game2.p2.winCount, equals(2));
      expect(game2.gameStateNotifier.value, equals(KendoGameState.matchOver));
      expect(game2.isMatchOverResultPending, isTrue);
      expect(game2.overlayTextNotifier.value, equals('時間切れ'));

      game2.update(2.1);
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

      // Advance 0.80s (total 1.30s >= 1.29s needed) -> P2 reaches right edge (stageMaxX = 520.0)
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

      // Advance 0.80s (total 1.30s >= 1.29s needed) -> P2 reaches left edge (stageMinX = -520.0)
      game.update(0.80);
      expect(game.p2.isPushedBack, isFalse);
      expect(game.p2.position.x, equals(game.stageMinX));
    });

    test('2 wins displays Ippon call for 2.0s then transitions to あなたの勝ち or あなたの負け', () async {
      final game = KendoGame();
      await game.onLoad();
      game.isRoundStarting = false;

      // P1 (Player) wins 2nd round -> matchOver with Ippon call first, then "あなたの勝ち" after 2.0s
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

      // Clear hitStop (0.06s) + advance 1.5s -> Still displaying Ippon call
      game.update(0.06);
      game.update(1.50);
      expect(game.isMatchOverResultPending, isTrue);
      expect(
        ['面あり', '小手あり', '胴あり'].contains(game.overlayTextNotifier.value),
        isTrue,
      );

      // Advance another 0.6s (total > 2.0s) -> Transitions to "あなたの勝ち"
      game.update(0.60);
      expect(game.isMatchOverResultPending, isFalse);
      expect(game.overlayTextNotifier.value, equals('あなたの勝ち'));

      // P2 (CPU) wins -> matchOver with Ippon call first, then "あなたの負け" after 2.0s
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

      // Clear hitStop (0.06s) + advance 2.1s -> Transitions to "あなたの負け"
      game2.update(0.06);
      game2.update(2.10);
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

  group('Fighter customization tests', () {
    test('P1 and P2 have distinct Hakama and Do Band colors', () async {
      final game = KendoGame();
      await game.onLoad();

      // P1: Navy Hakama, Red Do Band
      expect(game.p1.hakamaColor, equals(const Color(0xFF1A237E)));
      expect(game.p1.doBandColor, equals(const Color(0xFFD32F2F)));

      // P2: Black Hakama, White Do Band
      expect(game.p2.hakamaColor, equals(const Color(0xFF212121)));
      expect(game.p2.doBandColor, equals(const Color(0xFFFAFAFA)));
    });
  });
}
