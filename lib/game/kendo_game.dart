import 'dart:math' as math;

import 'package:flame/camera.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'audio/sound_manager.dart';
import 'components/debug_grid.dart';
import 'components/dojo_stage.dart';
import 'components/kendo_fighter.dart';
import 'enums/facing_direction.dart';
import 'score/score_manager.dart';

enum KendoGameState {
  playing,
  roundOver,
  matchOver,
}

class KendoGame extends FlameGame with KeyboardEvents {
  static const double stageWidth = 1280.0; // 1280x720 16:9 full background resolution
  static const double stageGroundY = 0.0; // Stage floor world Y coordinate
  static const double fighterGroundY = 250.0; // Target position Y = 250.0
  static const double strikeDamage = 34.0; // 3回ヒットで1本 (100.0 -> 66.0 -> 32.0 -> 0.0)

  late final DojoStage stage;
  late final KendoFighter p1;
  late final KendoFighter p2;

  final math.Random _random = math.Random();

  final double minFighterDistance = 108.0; // Scaled 3x (36.0 -> 108.0)
  final double stageMinX = -520.0;
  final double stageMaxX = 520.0;

  // Attack double-tap detection for Tsubazeriai push-away
  int _lastAttackTapTimeMs = 0;
  static const int attackDoubleTapThresholdMs = 300;

  // Game lifecycle, HUD & Settings ValueNotifiers
  final gameStateNotifier = ValueNotifier<KendoGameState>(KendoGameState.playing);
  final p1HealthNotifier = ValueNotifier<double>(100.0);
  final p2HealthNotifier = ValueNotifier<double>(100.0);
  final p1WinsNotifier = ValueNotifier<int>(0);
  final p2WinsNotifier = ValueNotifier<int>(0);
  final overlayTextNotifier = ValueNotifier<String>('');
  final isPausedNotifier = ValueNotifier<bool>(false);
  final isDebugVisibleNotifier = ValueNotifier<bool>(false); // デバッグ座標表示（入/切）
  final isSoundEnabledNotifier = ValueNotifier<bool>(false); // 効果音（入/切、初期値: 切）
  final bgFlashNotifier = ValueNotifier<double>(0.0); // 全画面打撃直前200ms背景フラッシュ警告
  final isEnemyOnRightNotifier = ValueNotifier<bool>(true); // 敵が右側にいるか（左右動的判定・ボタン色反転用）

  // Pre-Round Start Banner Sequence (Round 1: "はじめ！", Round 2: "二本目！", Round 3: "勝負！" for 1.2s)
  bool isRoundStarting = false;
  double roundStartTimer = 0.0;
  static const double totalRoundStartDelay = 1.2; // 開始宣告の表示時間 (1.2秒)

  // Hit-Stop & Screen Shake Effect Timers
  double hitStopTimer = 0.0;
  double screenShakeTimer = 0.0;
  double screenShakeIntensity = 0.0;

  // Round Timer (30-second countdown)
  static const double roundDuration = 30.0;
  double roundTimer = roundDuration;
  final roundTimerNotifier = ValueNotifier<int>(30);

  // Round Over & Match Over announcement timers
  double roundOverTimer = 0.0;
  static const double roundOverDelay = 2.0;

  bool isMatchOverResultPending = false;
  double matchOverResultTimer = 0.0;
  static const double matchOverIpponPhaseDuration = 1.2; // 決まり手（「面あり」等）表示時間 (1.2秒)
  static const double matchOverShobuAriPhaseDuration = 1.0; // 「勝負あり！」表示時間 (1.0秒)
  static const double matchOverAnnouncementDelay =
      matchOverIpponPhaseDuration + matchOverShobuAriPhaseDuration; // 合計 2.2秒
  String pendingIpponCallText = '';
  String pendingMatchResultText = '';

  // CPU AI & Tsubazeriai State variables
  double cpuDecisionTimer = 0.0;
  double cpuGuardTimer = 0.0;
  double cpuTsubazeriaiTimer = 0.0;
  bool _hasStoppedChargeSound = false;

  /// 試合中（playing）かつラウンド開始演出中やポーズ中でない場合のみ操作を受け付ける
  bool get _canControlP1 =>
      !isPausedNotifier.value &&
      !isRoundStarting &&
      gameStateNotifier.value == KendoGameState.playing;

  /// 剣道審判規則に基づく各ラウンド開始時の宣告テキスト
  String get currentRoundTitleText {
    final totalWins = p1.winCount + p2.winCount;
    if (totalWins == 0) {
      return 'はじめ！';
    } else if (totalWins == 1) {
      return '二本目！';
    } else {
      return '勝負！';
    }
  }

  /// 決まり手テキストの抽選（面あり: 50%, 小手あり: 40%, 胴あり: 10%）
  String rollIpponCallText([double? randomValue]) {
    final r = randomValue ?? _random.nextDouble();
    if (r < 0.50) {
      return '面あり';
    } else if (r < 0.90) {
      return '小手あり';
    } else {
      return '胴あり';
    }
  }

  void triggerHitStop(double duration) {
    hitStopTimer = duration;
  }

  void triggerScreenShake({double duration = 0.15, double intensity = 12.0}) {
    screenShakeTimer = duration;
    screenShakeIntensity = intensity;
  }

  void _syncFacingDirections() {
    final isEnemyRight = p1.position.x < p2.position.x;
    isEnemyOnRightNotifier.value = isEnemyRight;

    final isPassingOrTurning = p1.isPassingThrough || p2.isPassingThrough ||
        p1.isTurningAround || p2.isTurningAround;

    if (!isPassingOrTurning) {
      if (isEnemyRight) {
        p1.facingDirection = FacingDirection.right;
        p2.facingDirection = FacingDirection.left;
      } else {
        p1.facingDirection = FacingDirection.left;
        p2.facingDirection = FacingDirection.right;
      }
    }
  }

  void startRoundSequence() {
    isRoundStarting = true;
    roundStartTimer = 0.0;
    overlayTextNotifier.value = currentRoundTitleText;
    p1.stopAllActions();
    p2.stopAllActions();
    _syncFacingDirections();
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // 0. Initialize Audio Sound Manager
    await SoundManager.init();

    // 1. Fixed Resolution Viewport & Camera Setup
    camera.viewport = FixedResolutionViewport(resolution: Vector2(1280, 720));
    camera.viewfinder.position = Vector2(0.0, 0.0);
    camera.viewfinder.zoom = 1.0;

    // 2. Stage Component (Anchored to stageGroundY = 0.0)
    stage = DojoStage(
      stageWidth: stageWidth,
      groundY: stageGroundY,
    );
    world.add(stage);

    // 3. Player 1 (Red Ribbon / White Keikogi / Navy Hakama / Red Do Band)
    p1 = KendoFighter(
      name: '剣士1',
      isPlayer: true,
      startX: -260.0,
      groundY: fighterGroundY,
      keikogiColor: const Color(0xFFFAFAFA),
      ribbonColor: const Color(0xFFD32F2F),
      hakamaColor: const Color(0xFF1A237E),
      doBandColor: const Color(0xFFD32F2F),
    );
    world.add(p1);

    // 4. Player 2 / CPU (White Ribbon / Navy Keikogi / Black Hakama / White Do Band)
    p2 = KendoFighter(
      name: '剣士2',
      isPlayer: false,
      startX: 440.0,
      groundY: fighterGroundY,
      keikogiColor: const Color(0xFF1A237E),
      ribbonColor: const Color(0xFFFFFFFF),
      hakamaColor: const Color(0xFF212121),
      doBandColor: const Color(0xFFFAFAFA),
    );
    world.add(p2);

    // 5. Debug Grid Component (with isDebugVisibleNotifier)
    world.add(DebugGrid(isDebugVisible: isDebugVisibleNotifier));

    // 6. Start Pre-Round Sequence ("はじめ！")
    startRoundSequence();
  }

  @override
  void onRemove() {
    SoundManager.dispose();
    super.onRemove();
  }

  void togglePause() {
    if (gameStateNotifier.value == KendoGameState.matchOver) return;

    if (isPausedNotifier.value) {
      resumeEngine();
      isPausedNotifier.value = false;
    } else {
      pauseEngine();
      isPausedNotifier.value = true;
    }
  }

  // Unified Screen Tap / Hotkey Input Handlers (左右入力・画面タップ・Q/Eキー共通ハンドラ)
  void handleLeftInputDown() {
    if (!_canControlP1) return;
    if (p1.position.x < p2.position.x) {
      guardP1Start();
    } else {
      attackP1();
    }
  }

  void handleLeftInputUp() {
    if (!_canControlP1) return;
  }

  void handleRightInputDown() {
    if (!_canControlP1) return;
    if (p1.position.x < p2.position.x) {
      attackP1();
    } else {
      guardP1Start();
    }
  }

  void handleRightInputUp() {
    if (!_canControlP1) return;
  }

  void moveP1Left() {
    if (!_canControlP1) return;
    p1.move(-1.0);
  }

  void moveP1Right() {
    if (!_canControlP1) return;
    p1.move(1.0);
  }

  void stopP1() {
    p1.stop();
  }

  void guardP1Start() {
    if (!_canControlP1) return;
    p1.startGuard();
  }

  void guardP1Stop() {
    p1.stopGuard();
  }

  void attackP1({bool? forceDoubleTap}) {
    if (!_canControlP1) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final isDoubleTap = forceDoubleTap ??
        ((now - _lastAttackTapTimeMs) <= attackDoubleTapThresholdMs);
    _lastAttackTapTimeMs = now;

    if (p1.isTsubazeriai) {
      // 鍔迫り合い（ゴゴゴ･･）時のルール:
      // [1] 自分が敵の左位置 (p1.x < p2.x) かつ 中央より左側 (p1.x < 0.0) でダブルタップ -> 相手を右端 (stageMaxX) まで後退の1.5倍速度で突き飛ばす
      if (isDoubleTap && p1.position.x < p2.position.x && p1.position.x < 0.0) {
        p1.isTsubazeriai = false;
        p2.startPushBack(targetX: stageMaxX);
        cpuTsubazeriaiTimer = 0.0;
        return;
      }

      // [2] 自分が敵の右位置 (p1.x > p2.x) かつ 中央より右側 (p1.x > 0.0) でダブルタップ -> 相手を左端 (stageMinX) まで後退の1.5倍速度で突き飛ばす
      if (isDoubleTap && p1.position.x > p2.position.x && p1.position.x > 0.0) {
        p1.isTsubazeriai = false;
        p2.startPushBack(targetX: stageMinX);
        cpuTsubazeriaiTimer = 0.0;
        return;
      }

      // 通常の鍔迫り合い押し合い判定：単発攻撃入力で相手を20.0px押し込む
      final pushDir = p1.position.x < p2.position.x ? 1.0 : -1.0;
      p2.position.x = (p2.position.x + pushDir * 20.0).clamp(stageMinX, stageMaxX);
      return;
    }

    final dist = (p1.position.x - p2.position.x).abs();
    const double attackRange = 255.0; // 一足一刀の間合い

    if (dist > attackRange) {
      // 敵から離れている状態（間合い外）で攻撃タップ：1攻撃ステップ分（0.35秒）だけ前進して自動停止
      final forwardDir = p1.position.x < p2.position.x ? 1.0 : -1.0;
      p1.startFarAdvance(forwardDir);
      return;
    }

    p1.attack();
  }

  void disengageP1() {
    if (!_canControlP1) return;
    p1.disengage();
  }

  void resetMatch() {
    if (isPausedNotifier.value) {
      resumeEngine();
      isPausedNotifier.value = false;
    }
    _hasStoppedChargeSound = true;
    SoundManager.stopCharge();
    hitStopTimer = 0.0;
    screenShakeTimer = 0.0;
    _lastAttackTapTimeMs = 0;
    isMatchOverResultPending = false;
    matchOverResultTimer = 0.0;
    pendingIpponCallText = '';
    pendingMatchResultText = '';
    p1.resetMatch(startX: -260.0);
    p2.resetMatch(startX: 440.0);
    gameStateNotifier.value = KendoGameState.playing;
    roundTimer = roundDuration;
    roundTimerNotifier.value = 30;
    roundOverTimer = 0.0;
    cpuTsubazeriaiTimer = 0.0;
    startRoundSequence();
  }

  @override
  void update(double dt) {
    super.update(dt);

    // 0. Handle Hit-Stop Effect (ヒットストップ時の一時停止処理)
    if (hitStopTimer > 0) {
      hitStopTimer -= dt;
      if (hitStopTimer < 0) hitStopTimer = 0;
      return;
    }

    final currentGameState = gameStateNotifier.value;

    // 1. Handle Round Over timer (2.0s display of "〇あり" or "やめ！" before starting next round)
    if (currentGameState == KendoGameState.roundOver) {
      roundOverTimer += dt;
      if (roundOverTimer >= roundOverDelay) {
        _hasStoppedChargeSound = true;
        SoundManager.stopCharge();
        p1.resetRound(startX: -260.0);
        p2.resetRound(startX: 440.0);
        roundTimer = roundDuration;
        roundTimerNotifier.value = 30;
        gameStateNotifier.value = KendoGameState.playing;
        cpuTsubazeriaiTimer = 0.0;
        startRoundSequence(); // Start pre-round sequence for next round ("二本目！" or "勝負！")
      }
    }

    // 1-B. Handle Match Over transition:
    // Phase 1 (0.0s .. 1.2s): 決まり手 ("面あり"/"小手あり"/"胴あり"/"やめ！")
    // Phase 2 (1.2s .. 2.2s): "勝負あり！"
    // Phase 3 (2.2s+): "あなたの勝ち" / "あなたの負け"
    if (currentGameState == KendoGameState.matchOver && isMatchOverResultPending) {
      matchOverResultTimer += dt;
      if (matchOverResultTimer < matchOverIpponPhaseDuration) {
        overlayTextNotifier.value = pendingIpponCallText;
      } else if (matchOverResultTimer < matchOverAnnouncementDelay) {
        overlayTextNotifier.value = '勝負あり！';
      } else {
        isMatchOverResultPending = false;
        matchOverResultTimer = 0.0;
        overlayTextNotifier.value = pendingMatchResultText;
      }
    }

    // 2. Handle Pre-Round Start Sequence ("はじめ！" / "二本目！" / "勝負！" for 1.2s)
    if (currentGameState == KendoGameState.playing && isRoundStarting) {
      roundStartTimer += dt;
      p1.stop();
      p2.stop();
      _syncFacingDirections();

      if (roundStartTimer < totalRoundStartDelay) {
        overlayTextNotifier.value = currentRoundTitleText;
      } else {
        isRoundStarting = false;
        roundStartTimer = 0.0;
        overlayTextNotifier.value = '';
      }
      return;
    }

    // 3. Active Round Countdown Timer
    if (currentGameState == KendoGameState.playing) {
      roundTimer -= dt;
      final displaySeconds = roundTimer.ceil().clamp(0, 30);
      roundTimerNotifier.value = displaySeconds;

      if (roundTimer <= 0.0) {
        // Time-Out! Referee calls "やめ！" and CPU (p2) scores Ippon
        roundTimer = 0.0;
        roundTimerNotifier.value = 0;
        _scoreIppon(attacker: p2, defender: p1, customCallText: 'やめ！');
      }
    }

    // Sync HUD ValueNotifiers
    p1HealthNotifier.value = p1.health;
    p2HealthNotifier.value = p2.health;
    p1WinsNotifier.value = p1.winCount;
    p2WinsNotifier.value = p2.winCount;

    // 4. Monitor CPU attack windup: Flash red at blinking end, attack 0.5s later (点滅終了時に赤フラッシュ、0.5秒後に打撃)
    if (p2.isAttacking && !p2.isPlayer) {
      final totalWindup = p2.currentBlinkDuration + KendoFighter.postBlinkHoldDuration;
      if (p2.attackTimer >= p2.currentBlinkDuration && p2.attackTimer < totalWindup) {
        final remainingSec = totalWindup - p2.attackTimer; // 0.50s -> 0.00s
        stage.flashAlpha = (remainingSec / KendoFighter.postBlinkHoldDuration).clamp(0.0, 1.0);
      } else {
        stage.flashAlpha = 0.0;
      }

      if (!_hasStoppedChargeSound && p2.attackTimer >= p2.currentBlinkDuration) {
        _hasStoppedChargeSound = true;
        SoundManager.stopCharge();
      }
    } else {
      stage.flashAlpha = 0.0;
    }
    bgFlashNotifier.value = stage.flashAlpha;

    // 5. Stage Boundary Collisions
    if (p1.position.x < stageMinX) {
      p1.position.x = stageMinX;
    } else if (p1.position.x > stageMaxX) {
      p1.position.x = stageMaxX;
    }

    if (p2.position.x < stageMinX) {
      p2.position.x = stageMinX;
    } else if (p2.position.x > stageMaxX) {
      p2.position.x = stageMaxX;
    }

    // 6. Body Pushing & Collision (Bypassed during Pass-Through, Turnaround, or Push-Back)
    final isPassingOrTurning = p1.isPassingThrough || p2.isPassingThrough ||
        p1.isTurningAround || p2.isTurningAround ||
        p1.isPushedBack || p2.isPushedBack;

    if (!isPassingOrTurning) {
      final diffX = p1.position.x - p2.position.x;
      final absDist = diffX.abs();

      if (absDist < minFighterDistance) {
        final pushAmount = (minFighterDistance - absDist) / 2.0;
        if (diffX < 0) {
          p1.position.x -= pushAmount;
          p2.position.x += pushAmount;
        } else {
          p1.position.x += pushAmount;
          p2.position.x -= pushAmount;
        }
      }
    }

    // 7. Auto-Facing Direction & Position Notifier
    _syncFacingDirections();

    // 8. Active Combat & Pass-Through logic
    if (currentGameState == KendoGameState.playing) {
      _updatePassThroughState();
      _updateTsubazeriai(dt);
      _updateCpu(dt);
      _checkAttack(attacker: p1, defender: p2);
      _checkAttack(attacker: p2, defender: p1);
    }

    // 9. Camera Position & Screen Shake Effect (画面揺れ演出)
    if (screenShakeTimer > 0) {
      screenShakeTimer -= dt;
      if (screenShakeTimer < 0) screenShakeTimer = 0;
      final offsetX = (_random.nextDouble() * 2.0 - 1.0) * screenShakeIntensity;
      final offsetY = (_random.nextDouble() * 2.0 - 1.0) * screenShakeIntensity;
      camera.viewfinder.position = Vector2(offsetX, offsetY);
    } else {
      camera.viewfinder.position = Vector2(0.0, 0.0);
    }
  }

  void _updatePassThroughState() {
    final p1Arrived = p1.isPassingThrough &&
        ((p1.facingDirection == FacingDirection.right && p1.position.x >= p1.passThroughTargetX) ||
         (p1.facingDirection == FacingDirection.left && p1.position.x <= p1.passThroughTargetX) ||
         p1.velocityX.abs() < 1.0);

    final p2Arrived = p2.isPassingThrough &&
        ((p2.facingDirection == FacingDirection.right && p2.position.x >= p2.passThroughTargetX) ||
         (p2.facingDirection == FacingDirection.left && p2.position.x <= p2.passThroughTargetX) ||
         p2.velocityX.abs() < 1.0);

    if (p1Arrived || p2Arrived) {
      p1.isPassingThrough = false;
      p2.isPassingThrough = false;

      // Calculate new facing directions so both turn and face each other!
      FacingDirection p1NewFacing;
      FacingDirection p2NewFacing;
      if (p1.position.x < p2.position.x) {
        p1NewFacing = FacingDirection.right;
        p2NewFacing = FacingDirection.left;
      } else {
        p1NewFacing = FacingDirection.left;
        p2NewFacing = FacingDirection.right;
      }

      // Trigger simultaneous turnaround and overhead posture (振り返り)
      p1.startTurnaround(newFacing: p1NewFacing);
      p2.startTurnaround(newFacing: p2NewFacing);
    }
  }

  bool _tryTriggerPassThrough({required KendoFighter attacker, required KendoFighter defender}) {
    if (attacker.isPassingThrough || defender.isPassingThrough) return false;
    if (attacker.isTurningAround || defender.isTurningAround) return false;

    final forwardDir = attacker.facingDirection == FacingDirection.right ? 1.0 : -1.0;

    // ステージ端（壁際）に追い込まれた場合でも確実にすれ違い（駆け抜け）を発動させ、
    // お互いの位置を交差させて壁際から脱出・間合いを確保する
    final targetX = forwardDir > 0
        ? (attacker.position.x + 380.0).clamp(stageMinX + 30.0, stageMaxX - 30.0)
        : (attacker.position.x - 380.0).clamp(stageMinX + 30.0, stageMaxX - 30.0);

    attacker.startPassThrough(targetX: targetX);
    return true;
  }

  void _updateTsubazeriai(double dt) {
    if (p1.isPassingThrough || p2.isPassingThrough ||
        p1.isTurningAround || p2.isTurningAround ||
        p1.isPushedBack || p2.isPushedBack) {
      p1.isTsubazeriai = false;
      p2.isTsubazeriai = false;
      cpuTsubazeriaiTimer = 0.0;
      return;
    }

    final dist = (p1.position.x - p2.position.x).abs();
    const double tsubazeriaiDist = 114.0; // Scaled 3x (38.0 -> 114.0)

    if (dist <= tsubazeriaiDist && !p1.isDisengaging && !p2.isDisengaging) {
      p1.isTsubazeriai = true;
      p2.isTsubazeriai = true;

      if (!p2.isPlayer) {
        cpuTsubazeriaiTimer += dt;
        if (cpuTsubazeriaiTimer >= 0.35) {
          final rand = _random.nextDouble();
          if (rand < 0.50) {
            p2.disengage();
          } else {
            // CPU pushes Player back during Tsubazeriai (押し合い判定)
            final pushDir = p2.position.x > p1.position.x ? -1.0 : 1.0;
            p1.position.x = (p1.position.x + pushDir * 18.0).clamp(stageMinX, stageMaxX);
          }
          cpuTsubazeriaiTimer = 0.0;
        }
      }
    } else {
      if (dist > 135.0) { // Scaled 3x (45.0 -> 135.0)
        p1.isTsubazeriai = false;
        p2.isTsubazeriai = false;
        cpuTsubazeriaiTimer = 0.0;
      }
    }
  }

  void _checkAttack({required KendoFighter attacker, required KendoFighter defender}) {
    if (!attacker.isAttacking || attacker.hasDealtDamageThisAttack) return;

    final dist = (attacker.position.x - defender.position.x).abs();
    const attackRange = 255.0; // 一足一刀の間合い

    if (attacker.isPlayer) {
      // -------------------------------------------------------------
      // PLAYER ATTACKING CPU
      // -------------------------------------------------------------
      if (attacker.attackTimer < 0.18 || attacker.attackTimer > 0.36) return;

      if (dist <= attackRange) {
        attacker.hasDealtDamageThisAttack = true;

        if (defender.cpuVulnerableTimer > 0) {
          // CPU is in Vulnerable Window (Counter Opportunity) -> Hit connects!
          _hasStoppedChargeSound = true;
          SoundManager.stopCharge();
          SoundManager.playHit();
          triggerHitStop(0.06); // 0.06s Hit-Stop!
          triggerScreenShake(duration: 0.15, intensity: 12.0); // 画面揺れ演出!
          final wasZeroHealth = defender.health <= 0;
          defender.takeDamage(strikeDamage);

          if (wasZeroHealth || defender.health <= 0) {
            _scoreIppon(attacker: attacker, defender: defender);
          } else {
            _tryTriggerPassThrough(attacker: attacker, defender: defender);
          }
        } else {
          // CPU is in Normal State -> CPU automatically blocks Player's attack!
          defender.hitStunTimer = 0.15;
          attacker.hitStunTimer = 0.25; // Player recoil on block
        }
      }
    } else {
      // -------------------------------------------------------------
      // CPU ATTACKING PLAYER
      // -------------------------------------------------------------
      // Hit window: Phase 2 Men Strike (totalWindup <= attackTimer <= totalWindup + 0.28s)
      final totalWindup = attacker.currentBlinkDuration + KendoFighter.postBlinkHoldDuration;
      if (attacker.attackTimer < totalWindup || attacker.attackTimer > totalWindup + 0.28) return;

      if (dist <= attackRange) {
        attacker.hasDealtDamageThisAttack = true;

        if (defender.isGuarding) {
          // Just Guard Success! (ジャスト防御成功・先守後攻)
          // Player blocked CPU's Men strike -> Stop Charge SE & Play Guard SE!
          _hasStoppedChargeSound = true;
          SoundManager.stopCharge();
          SoundManager.playGuard();
          defender.triggerJustGuardEffect(); // 青い閃光・火花演出!
          triggerHitStop(0.06); // 0.06s Hit-Stop!
          attacker.isAttacking = false;
          attacker.attackTimer = 0.0;
          attacker.hitStunTimer = 0.3;
          attacker.cpuVulnerableTimer = 1.5; // 1.5s Vulnerable Window!
          defender.hitStunTimer = 0.15;
        } else {
          // Player failed to guard -> Men strike hits Player! Stop Charge SE & Play Hit SE!
          _hasStoppedChargeSound = true;
          SoundManager.stopCharge();
          SoundManager.playHit();
          triggerHitStop(0.06); // 0.06s Hit-Stop!
          triggerScreenShake(duration: 0.15, intensity: 12.0); // 画面揺れ演出!
          final wasZeroHealth = defender.health <= 0;
          defender.takeDamage(strikeDamage);

          if (wasZeroHealth || defender.health <= 0) {
            _scoreIppon(attacker: attacker, defender: defender);
          } else {
            _tryTriggerPassThrough(attacker: attacker, defender: defender);
          }
        }
      }
    }
  }

  void _scoreIppon({
    required KendoFighter attacker,
    required KendoFighter defender,
    String? customCallText,
  }) {
    attacker.winCount++;
    final ipponCall = customCallText ?? rollIpponCallText();

    // Stop any ongoing movement or actions immediately upon Ippon
    p1.stopAllActions();
    p2.stopAllActions();

    if (attacker.winCount >= 2) {
      gameStateNotifier.value = KendoGameState.matchOver;
      pendingIpponCallText = ipponCall;
      overlayTextNotifier.value = ipponCall;
      isMatchOverResultPending = true;
      matchOverResultTimer = 0.0;

      if (attacker.isPlayer) {
        pendingMatchResultText = 'あなたの勝ち';
        ScoreManager.recordWin();
      } else {
        pendingMatchResultText = 'あなたの負け';
        ScoreManager.recordLoss();
      }
    } else {
      gameStateNotifier.value = KendoGameState.roundOver;
      roundOverTimer = 0.0;
      overlayTextNotifier.value = ipponCall;
    }
  }

  void _updateCpu(double dt) {
    if (p2.isPlayer) return;
    if (p2.isPushedBack) return;

    final dist = (p1.position.x - p2.position.x).abs();

    cpuDecisionTimer += dt;
    if (cpuDecisionTimer >= 0.25) {
      cpuDecisionTimer = 0.0;

      if (p2.cpuVulnerableTimer > 0) {
        // CPU is vulnerable / staggered -> cannot move or attack
        p2.stop();
        p2.stopGuard();
        return;
      }

      if (dist > 240.0) { // Scaled 3x (80.0 -> 240.0)
        // Approach player
        if (p2.position.x > p1.position.x) {
          p2.move(-1.0);
        } else {
          p2.move(1.0);
        }
        p2.stopGuard();
      } else {
        // Close / Strike range
        p2.stop();
        if (!p2.isGuarding && !p2.isTsubazeriai && !p2.isPassingThrough && !p2.isTurningAround && !p2.isAttacking) {
          final rand = _random.nextDouble();
          if (rand < 0.50) {
            // CPU initiates 2-phase attack with randomly chosen flash duration (0.3s Short / 0.5s Medium / 0.8s Long)
            final blinkDurations = KendoFighter.cpuBlinkDurations;
            final chosenBlink = blinkDurations[_random.nextInt(blinkDurations.length)];
            p2.attack(blinkDuration: chosenBlink);
            _hasStoppedChargeSound = false;
            SoundManager.playCharge(); // Play Charge SE on CPU attack windup start
          } else if (rand < 0.70) {
            p2.startGuard();
            cpuGuardTimer = 0.35;
          }
        }
      }
    }

    if (p2.isGuarding && cpuGuardTimer > 0) {
      cpuGuardTimer -= dt;
      if (cpuGuardTimer <= 0) {
        p2.stopGuard();
        cpuGuardTimer = 0.0;
      }
    }
  }

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    // 0. Toggle Pause Key (P)
    if (event.logicalKey == LogicalKeyboardKey.keyP) {
      if (event is KeyDownEvent) {
        togglePause();
      }
      return KeyEventResult.handled;
    }

    if (isPausedNotifier.value) {
      return KeyEventResult.ignored;
    }

    // 1. Q Key (Left Screen Tap Equivalent)
    if (event.logicalKey == LogicalKeyboardKey.keyQ) {
      if (event is KeyDownEvent) {
        handleLeftInputDown();
      } else if (event is KeyUpEvent) {
        handleLeftInputUp();
      }
      return KeyEventResult.handled;
    }

    // 2. E Key (Right Screen Tap Equivalent)
    if (event.logicalKey == LogicalKeyboardKey.keyE) {
      if (event is KeyDownEvent) {
        handleRightInputDown();
      } else if (event is KeyUpEvent) {
        handleRightInputUp();
      }
      return KeyEventResult.handled;
    }

    if (gameStateNotifier.value == KendoGameState.matchOver && !isMatchOverResultPending) {
      if (event is KeyDownEvent &&
          (event.logicalKey == LogicalKeyboardKey.keyR ||
           event.logicalKey == LogicalKeyboardKey.space ||
           event.logicalKey == LogicalKeyboardKey.enter)) {
        resetMatch();
        return KeyEventResult.handled;
      }
    }

    // 3. Guard Key (K)
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.keyK) {
      guardP1Start();
    }

    // 4. Attack Key (J or Space)
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.keyJ ||
         event.logicalKey == LogicalKeyboardKey.space)) {
      attackP1();
    }

    // 5. Disengage Key (S or ArrowDown)
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.keyS ||
         event.logicalKey == LogicalKeyboardKey.arrowDown)) {
      disengageP1();
      return KeyEventResult.handled;
    }

    // 6. Movement Keys (A / D / ArrowLeft / ArrowRight)
    final isLeftPressed = keysPressed.contains(LogicalKeyboardKey.arrowLeft) ||
        keysPressed.contains(LogicalKeyboardKey.keyA);
    final isRightPressed = keysPressed.contains(LogicalKeyboardKey.arrowRight) ||
        keysPressed.contains(LogicalKeyboardKey.keyD);

    if (isLeftPressed && !isRightPressed) {
      moveP1Left();
      return KeyEventResult.handled;
    } else if (isRightPressed && !isLeftPressed) {
      moveP1Right();
      return KeyEventResult.handled;
    } else {
      stopP1();
      return KeyEventResult.ignored;
    }
  }
}
