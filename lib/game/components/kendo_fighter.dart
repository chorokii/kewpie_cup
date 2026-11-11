import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../enums/facing_direction.dart';

class KendoFighter extends PositionComponent {
  KendoFighter({
    required this.name,
    required this.isPlayer,
    required double startX,
    required double groundY,
    required this.keikogiColor,
    required this.ribbonColor,
    this.hakamaColor = const Color(0xFF1A237E),
    this.doBandColor = const Color(0xFFD32F2F),
  }) {
    // 描画基準点(0, 0)が足元であるため、アンカーを Anchor.topCenter に設定
    // これにより position が直接足元のワールド座標と一致します
    size = Vector2(60, 100);
    anchor = Anchor.topCenter;
    position = Vector2(startX, groundY);
    scale = Vector2.all(3.0); // 3倍拡大
    facingDirection = startX < 0 ? FacingDirection.right : FacingDirection.left;
    priority = 10; // Foreground layer (in front of background stage)
  }

  final String name;
  final bool isPlayer;
  final Color keikogiColor;
  final Color ribbonColor;
  final Color hakamaColor;
  final Color doBandColor;

  FacingDirection facingDirection = FacingDirection.right;

  double velocityX = 0.0;
  bool isMoving = false;
  double walkAnimationTimer = 0.0;

  final double walkSpeed = 160.0;
  final double guardSpeedMultiplier = 0.3;

  // Combat stats
  double health = 100.0;
  final double maxHealth = 100.0;
  int winCount = 0;

  // Action states
  bool isGuarding = false;
  static double guardActiveDuration = 0.4; // 防御アクティブウィンドウ持続時間（デフォルト0.4秒、設定画面で0.2s～1.0s可変）
  static const double guardCooldownDuration = 0.2; // 防御クールダウン時間（0.2秒）
  double guardTimer = 0.0;
  double guardCooldownTimer = 0.0;

  bool isAttacking = false;
  double attackTimer = 0.0;
  static const double attackDuration = 0.45;
  bool hasDealtDamageThisAttack = false;

  // 1-step Far Advance (間合い外タップ時の1踏み込み前進)
  bool isFarAdvancing = false;
  double farAdvanceTimer = 0.0;
  static const double farAdvanceDuration = 0.35; // 1踏み込み前進の持続時間 (0.35秒)

  // CPU 3-Tier Attack Windup Flash Durations (短: 0.3s / 中: 0.5s / 長: 0.8s) & Fixed Hold Duration (0.5s)
  static const List<double> cpuBlinkDurations = [0.3, 0.5, 0.8];
  static const double postBlinkHoldDuration = 0.5; // 点滅終了後の固定タメ時間（0.5秒）
  double currentBlinkDuration = 0.5; // デフォルト中（0.5s）

  // CPU Vulnerable Window / Guard-Break Timer (1.5s 反撃チャンス)
  double cpuVulnerableTimer = 0.0;

  // Visual Effect Timers (Just Guard Spark & Hit Impact Shockwave)
  double justGuardEffectTimer = 0.0;
  double hitImpactEffectTimer = 0.0;

  // Tsubazeriai, Disengage & PushBack (突き飛ばし)
  bool isTsubazeriai = false;
  bool isDisengaging = false;
  double disengageTimer = 0.0;
  static const double disengageDuration = 0.25;
  static const double disengageSpeed = 320.0;

  bool isPushedBack = false;
  double pushBackTargetX = 0.0;
  static const double pushBackSpeed = disengageSpeed * 1.5; // 後退速度(320.0)の1.5倍 = 480.0

  // Pass-Through (すれ違い・駆け抜け) & Turnaround (振り返り)
  bool isPassingThrough = false;
  double passThroughTargetX = 0.0;
  bool isTurningAround = false;
  double turnaroundTimer = 0.0;
  static const double turnaroundDuration = 0.28;

  double hitStunTimer = 0.0;

  void move(double directionInput) {
    if (isDisengaging || isPushedBack || isAttacking || isPassingThrough || isTurningAround) return;

    isFarAdvancing = false;
    farAdvanceTimer = 0.0;

    // If in Tsubazeriai and moving backward, trigger disengage backstep
    final forwardDir = facingDirection == FacingDirection.right ? 1.0 : -1.0;
    final isMovingBackward = (directionInput * forwardDir) < 0;

    if (isTsubazeriai && isMovingBackward) {
      disengage();
      return;
    }

    final speed = isGuarding ? (walkSpeed * guardSpeedMultiplier) : walkSpeed;
    velocityX = directionInput * speed;
  }

  void startFarAdvance(double directionInput) {
    if (isAttacking || hitStunTimer > 0 || isDisengaging || isPushedBack || isPassingThrough || isTurningAround) return;
    isFarAdvancing = true;
    farAdvanceTimer = 0.0;
    final speed = isGuarding ? (walkSpeed * guardSpeedMultiplier) : walkSpeed;
    velocityX = directionInput * speed;
  }

  void stop() {
    if (!isDisengaging && !isPushedBack && !isAttacking && !isPassingThrough && !isTurningAround && !isFarAdvancing) {
      velocityX = 0.0;
    }
  }

  /// ラウンド終了・試合終了時に進行中の全移動・アクションを即座に停止する
  void stopAllActions() {
    velocityX = 0.0;
    isMoving = false;
    walkAnimationTimer = 0.0;
    isGuarding = false;
    guardTimer = 0.0;
    isAttacking = false;
    attackTimer = 0.0;
    isFarAdvancing = false;
    farAdvanceTimer = 0.0;
    isTsubazeriai = false;
    isDisengaging = false;
    disengageTimer = 0.0;
    isPushedBack = false;
    isPassingThrough = false;
    isTurningAround = false;
    turnaroundTimer = 0.0;
    cpuVulnerableTimer = 0.0;
  }

  void triggerJustGuardEffect() {
    justGuardEffectTimer = 0.25;
  }

  void startGuard() {
    if (isGuarding || guardCooldownTimer > 0 || isAttacking || isDisengaging || isPushedBack || isPassingThrough || isTurningAround || hitStunTimer > 0) {
      debugPrint('[Guard-Start BLOCKED] $name: isGuarding=$isGuarding, cooldown=${guardCooldownTimer.toStringAsFixed(2)}s, isAttacking=$isAttacking, isDisengaging=$isDisengaging, hitStun=${hitStunTimer.toStringAsFixed(2)}s');
      return;
    }

    isFarAdvancing = false;
    farAdvanceTimer = 0.0;
    isGuarding = true;
    guardTimer = guardActiveDuration;
    debugPrint('[Guard-Start SUCCESS] $name: Guard started for ${guardActiveDuration.toStringAsFixed(2)}s');
    if (velocityX != 0.0) {
      final dir = velocityX > 0 ? 1.0 : -1.0;
      velocityX = dir * walkSpeed * guardSpeedMultiplier;
    }
  }

  void stopGuard() {
    if (isGuarding) {
      debugPrint('[Guard-Stop RELEASED] $name: Guard cancelled on finger release. Active elapsed: ${(guardActiveDuration - guardTimer).toStringAsFixed(2)}s, Cooldown 0.2s started.');
      isGuarding = false;
      guardTimer = 0.0;
      guardCooldownTimer = guardCooldownDuration;
    }
  }

  void attack({double? blinkDuration}) {
    if (isAttacking || hitStunTimer > 0 || isDisengaging || isPushedBack || isPassingThrough || isTurningAround) return;

    isFarAdvancing = false;
    farAdvanceTimer = 0.0;

    if (!isPlayer && blinkDuration != null) {
      currentBlinkDuration = blinkDuration;
    }

    isAttacking = true;
    attackTimer = 0.0;
    hasDealtDamageThisAttack = false;
    isGuarding = false;
    guardTimer = 0.0;
  }

  void disengage() {
    if (isDisengaging || isPushedBack || hitStunTimer > 0 || isPassingThrough) return;
    isFarAdvancing = false;
    farAdvanceTimer = 0.0;
    isDisengaging = true;
    isTsubazeriai = false;
    isGuarding = false;
    guardTimer = 0.0;
    isAttacking = false;
    disengageTimer = 0.0;

    final backwardDir = facingDirection == FacingDirection.right ? -1.0 : 1.0;
    velocityX = backwardDir * disengageSpeed;
  }

  void startPushBack({required double targetX}) {
    isFarAdvancing = false;
    farAdvanceTimer = 0.0;
    isTsubazeriai = false;
    isDisengaging = false;
    disengageTimer = 0.0;
    isGuarding = false;
    guardTimer = 0.0;
    isAttacking = false;
    attackTimer = 0.0;
    isPassingThrough = false;
    isTurningAround = false;

    isPushedBack = true;
    pushBackTargetX = targetX;
    final dir = targetX >= position.x ? 1.0 : -1.0;
    velocityX = dir * pushBackSpeed;
  }

  void startPassThrough({required double targetX}) {
    isFarAdvancing = false;
    farAdvanceTimer = 0.0;
    isPushedBack = false;
    isPassingThrough = true;
    passThroughTargetX = targetX;
    isTsubazeriai = false;
    isDisengaging = false;
    isGuarding = false;
    guardTimer = 0.0;
  }

  void startTurnaround({required FacingDirection newFacing}) {
    isFarAdvancing = false;
    farAdvanceTimer = 0.0;
    isPushedBack = false;
    isPassingThrough = false;
    isTurningAround = true;
    turnaroundTimer = 0.0;
    facingDirection = newFacing;
    velocityX = 0.0;
    isMoving = false;
    isTsubazeriai = false;
    isGuarding = false;
    guardTimer = 0.0;
    isAttacking = false;
    attackTimer = 0.0;
  }

  void takeDamage(double amount) {
    health = (health - amount).clamp(0.0, maxHealth);
    hitStunTimer = 0.2;
    hitImpactEffectTimer = 0.25;
    isFarAdvancing = false;
    farAdvanceTimer = 0.0;
    isTsubazeriai = false;
    isAttacking = false;
    isDisengaging = false;
    isPushedBack = false;
    isPassingThrough = false;
    isTurningAround = false;
    isGuarding = false;
    guardTimer = 0.0;
    cpuVulnerableTimer = 0.0;
  }

  void resetRound({required double startX}) {
    health = maxHealth;
    position.x = startX;
    facingDirection = startX < 0 ? FacingDirection.right : FacingDirection.left;
    velocityX = 0.0;
    isMoving = false;
    walkAnimationTimer = 0.0;
    isGuarding = false;
    guardTimer = 0.0;
    guardCooldownTimer = guardCooldownDuration;
    isAttacking = false;
    isTsubazeriai = false;
    isDisengaging = false;
    disengageTimer = 0.0;
    isPushedBack = false;
    pushBackTargetX = 0.0;
    isPassingThrough = false;
    isTurningAround = false;
    turnaroundTimer = 0.0;
    isFarAdvancing = false;
    farAdvanceTimer = 0.0;
    attackTimer = 0.0;
    hasDealtDamageThisAttack = false;
    hitStunTimer = 0.0;
    cpuVulnerableTimer = 0.0;
    justGuardEffectTimer = 0.0;
    hitImpactEffectTimer = 0.0;
    currentBlinkDuration = 0.5;
  }

  void resetMatch({required double startX}) {
    winCount = 0;
    resetRound(startX: startX);
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (hitStunTimer > 0) {
      hitStunTimer -= dt;
      if (hitStunTimer < 0) hitStunTimer = 0;
    }

    if (cpuVulnerableTimer > 0) {
      cpuVulnerableTimer -= dt;
      if (cpuVulnerableTimer < 0) cpuVulnerableTimer = 0;
    }

    if (justGuardEffectTimer > 0) {
      justGuardEffectTimer -= dt;
      if (justGuardEffectTimer < 0) justGuardEffectTimer = 0;
    }

    if (hitImpactEffectTimer > 0) {
      hitImpactEffectTimer -= dt;
      if (hitImpactEffectTimer < 0) hitImpactEffectTimer = 0;
    }

    // Handle Push-Back movement (鍔迫り合い突き飛ばし時の連続移動: 後退速度の1.5倍 = 480.0px/s)
    if (isPushedBack) {
      final diff = pushBackTargetX - position.x;
      final step = pushBackSpeed * dt;
      if (diff.abs() <= step) {
        position.x = pushBackTargetX;
        velocityX = 0.0;
        isPushedBack = false;
        isMoving = false;
        walkAnimationTimer = 0.0;
      } else {
        final dir = diff > 0 ? 1.0 : -1.0;
        velocityX = dir * pushBackSpeed;
        isMoving = true;
        walkAnimationTimer += dt * 12.0;
        position.x += velocityX * dt;
      }
      return;
    }

    // Handle 1-step Far Advance (間合い外攻撃タップ時の1踏み込み前進と自動停止)
    if (isFarAdvancing) {
      farAdvanceTimer += dt;
      if (farAdvanceTimer >= farAdvanceDuration) {
        isFarAdvancing = false;
        farAdvanceTimer = 0.0;
        velocityX = 0.0;
      }
    }

    // Handle Guard Active Duration and Cooldown Timers
    if (isGuarding) {
      guardTimer -= dt;
      if (guardTimer <= 0.0) {
        debugPrint('[Guard-EXPIRED] $name: Guard active window (${guardActiveDuration.toStringAsFixed(2)}s) expired. Cooldown 0.2s started.');
        isGuarding = false;
        guardTimer = 0.0;
        guardCooldownTimer = guardCooldownDuration;
      }
    } else if (guardCooldownTimer > 0) {
      guardCooldownTimer -= dt;
      if (guardCooldownTimer < 0.0) {
        guardCooldownTimer = 0.0;
      }
    }

    // Handle Turnaround (振り返り・振りかぶり)
    if (isTurningAround) {
      turnaroundTimer += dt;
      velocityX = 0.0;
      if (turnaroundTimer >= turnaroundDuration) {
        isTurningAround = false;
        turnaroundTimer = 0.0;
      }
    }

    // Handle Pass-Through Run
    if (isPassingThrough) {
      final forwardDir = facingDirection == FacingDirection.right ? 1.0 : -1.0;
      velocityX = forwardDir * 280.0;

      final reachedTarget = facingDirection == FacingDirection.right
          ? position.x >= passThroughTargetX
          : position.x <= passThroughTargetX;

      if (reachedTarget) {
        velocityX = 0.0;
      }
    }

    // Handle Disengage Backstep
    if (isDisengaging) {
      disengageTimer += dt;
      final backwardDir = facingDirection == FacingDirection.right ? -1.0 : 1.0;
      velocityX = backwardDir * disengageSpeed;

      if (disengageTimer >= disengageDuration) {
        isDisengaging = false;
        disengageTimer = 0.0;
        velocityX = 0.0;
      }
    }

    // Handle Attack Logic: Player (0.45s 2-phase lunge) vs CPU (currentBlinkDuration + 0.5s hold + 0.3s Men strike)
    if (isAttacking && !isPassingThrough) {
      attackTimer += dt;
      final forwardDir = facingDirection == FacingDirection.right ? 1.0 : -1.0;

      if (isPlayer) {
        if (attackTimer < 0.18) {
          velocityX = forwardDir * 200.0;
        } else if (attackTimer < 0.38) {
          velocityX = forwardDir * 260.0;
        } else if (attackTimer < attackDuration) {
          velocityX = 0.0;
        } else {
          isAttacking = false;
          attackTimer = 0.0;
          velocityX = 0.0;
        }
      } else {
        // CPU Attack: Phase 1 Windup (0.0s to totalWindup), Phase 2 Men Strike (totalWindup to totalWindup + 0.3s)
        final totalWindup = currentBlinkDuration + postBlinkHoldDuration;
        if (attackTimer < totalWindup) {
          velocityX = 0.0;
        } else if (attackTimer < totalWindup + 0.30) {
          velocityX = forwardDir * 260.0;
        } else {
          isAttacking = false;
          attackTimer = 0.0;
          velocityX = 0.0;
        }
      }
    }

    if (velocityX != 0.0) {
      isMoving = true;
      walkAnimationTimer += dt * 8.0;
      position.x += velocityX * dt;
    } else {
      isMoving = false;
      walkAnimationTimer = 0.0;
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    canvas.save();

    if (facingDirection == FacingDirection.left) {
      canvas.scale(-1.0, 1.0);
    }

    _drawKendoFighter(canvas);

    canvas.restore();
  }

  void _drawUnflippedText(
    Canvas canvas, {
    required String text,
    required TextStyle style,
    required Offset position,
  }) {
    canvas.save();
    canvas.translate(position.dx, position.dy);
    if (facingDirection == FacingDirection.left) {
      canvas.scale(-1.0, 1.0);
    }
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: style,
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(-textPainter.width / 2, 0));
    canvas.restore();
  }

  void _drawKendoFighter(Canvas canvas) {
    // Stepping bounce: feet step upward (-2px max) during sliding walk, planted at Y = 0
    final stepBounce = isMoving ? -(math.sin(walkAnimationTimer).abs() * 2.0) : 0.0;

    double shinaiAngle = 0.0;
    if (isTurningAround) {
      if (turnaroundTimer < 0.16) {
        shinaiAngle = -1.2;
      } else {
        final progress = ((turnaroundTimer - 0.16) / (turnaroundDuration - 0.16)).clamp(0.0, 1.0);
        shinaiAngle = -1.2 * (1.0 - progress);
      }
    } else if (isTsubazeriai) {
      shinaiAngle = -0.65 + (math.sin(walkAnimationTimer * 12.0) * 0.03);
    } else if (isGuarding) {
      shinaiAngle = -0.85;
    } else if (isAttacking) {
      if (isPlayer) {
        if (attackTimer < 0.18) {
          final p1 = (attackTimer / 0.18).clamp(0.0, 1.0);
          shinaiAngle = -1.3 * p1;
        } else if (attackTimer < 0.38) {
          final p2 = ((attackTimer - 0.18) / 0.20).clamp(0.0, 1.0);
          shinaiAngle = -1.3 + (1.9 * p2);
        } else {
          shinaiAngle = 0.6;
        }
      } else {
        // CPU Attack Posture: Phase 1 Windup (High) -> Phase 2 Men Strike (Down)
        final totalWindup = currentBlinkDuration + postBlinkHoldDuration;
        if (attackTimer < totalWindup) {
          shinaiAngle = -1.3;
        } else {
          shinaiAngle = 0.6;
        }
      }
    } else if (isMoving) {
      shinaiAngle = math.sin(walkAnimationTimer * 0.8) * 0.05;
    }

    // Shadow (Flat oval centered at Y = 0 on ground surface)
    final shadowPaint = Paint()
      ..color = const Color(0x66000000)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(0, 0),
        width: 44,
        height: 8,
      ),
      shadowPaint,
    );

    // Tsubazeriai visual spark / badge
    if (isTsubazeriai) {
      final tsubaSparkPaint = Paint()
        ..color = const Color(0xFFFFD54F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(Offset(22, -60 + stepBounce), 12, tsubaSparkPaint);

      _drawUnflippedText(
        canvas,
        text: 'ゴゴゴ･･',
        style: const TextStyle(
          color: Colors.amberAccent,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(color: Colors.black, blurRadius: 3)],
        ),
        position: Offset(0, -112 + stepBounce),
      );
    }

    // Guard Aura & Just Guard Spark Effect (青い閃光・火花)
    if (isGuarding) {
      final guardArcPaint = Paint()
        ..color = const Color(0xAA64B5F6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(12, -50 + stepBounce), radius: 30),
        -math.pi / 3,
        2 * math.pi / 3,
        false,
        guardArcPaint,
      );
    }

    if (justGuardEffectTimer > 0) {
      final progress = (1.0 - (justGuardEffectTimer / 0.25)).clamp(0.0, 1.0);
      final burstRadius = 14.0 + (progress * 32.0);

      final sparkPaint = Paint()
        ..color = const Color(0xFF448AFF).withValues(alpha: (1.0 - progress) * 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5;
      canvas.drawCircle(Offset(14, -55 + stepBounce), burstRadius, sparkPaint);

      final corePaint = Paint()
        ..color = Colors.white.withValues(alpha: (1.0 - progress) * 0.95)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(14, -55 + stepBounce), 8.0 * (1.0 - progress), corePaint);

      final rayPaint = Paint()
        ..color = const Color(0xFF82B1FF).withValues(alpha: 1.0 - progress)
        ..strokeWidth = 2.0;
      final center = Offset(14, -55 + stepBounce);
      for (int i = 0; i < 6; i++) {
        final angle = i * math.pi / 3.0;
        final startDist = burstRadius * 0.4;
        final endDist = burstRadius * 1.1;
        canvas.drawLine(
          center + Offset(math.cos(angle) * startDist, math.sin(angle) * startDist),
          center + Offset(math.cos(angle) * endDist, math.sin(angle) * endDist),
          rayPaint,
        );
      }
    }

    // Hit Impact Shockwave Ring Effect (金の衝撃波・打撃エフェクト)
    if (hitImpactEffectTimer > 0) {
      final progress = (1.0 - (hitImpactEffectTimer / 0.25)).clamp(0.0, 1.0);
      final ringRadius = 12.0 + (progress * 40.0);

      final shockPaint = Paint()
        ..color = const Color(0xFFFFD54F).withValues(alpha: (1.0 - progress) * 0.95)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0;
      canvas.drawCircle(Offset(0, -70 + stepBounce), ringRadius, shockPaint);

      final innerShockPaint = Paint()
        ..color = const Color(0xFFFF1744).withValues(alpha: (1.0 - progress) * 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawCircle(Offset(0, -70 + stepBounce), ringRadius * 0.6, innerShockPaint);
    }

    // Attack Effects (Player vs CPU 2-phase attack)
    if (isAttacking) {
      if (isPlayer) {
        if (attackTimer >= 0.18 && attackTimer <= 0.36) {
          final slashPaint = Paint()
            ..color = const Color(0xDDFFD54F)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4.0;
          canvas.drawArc(
            Rect.fromCircle(center: Offset(30, -50 + stepBounce), radius: 38),
            -math.pi / 4,
            math.pi / 2,
            false,
            slashPaint,
          );
        }
      } else {
        // CPU 2-phase attack effects
        final totalWindup = currentBlinkDuration + postBlinkHoldDuration;
        if (attackTimer < totalWindup) {
          // Phase 1-A: Rapid Flashing White Windup (0.0s <= attackTimer < currentBlinkDuration)
          // Phase 1-B: Flash stops (currentBlinkDuration <= attackTimer < totalWindup) for 0.5s hold time
          if (attackTimer < currentBlinkDuration) {
            final isFlashVisible = (attackTimer * 20).floor() % 2 == 0;
            if (isFlashVisible) {
              final windupPaint = Paint()
                ..color = Colors.white.withValues(alpha: 0.85)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 4.0;
              canvas.drawArc(
                Rect.fromCircle(center: Offset(10, -70 + stepBounce), radius: 34),
                -math.pi * 0.8,
                math.pi * 0.6,
                false,
                windupPaint,
              );
              canvas.drawCircle(
                Offset(14, -85 + stepBounce),
                10,
                Paint()..color = Colors.white.withValues(alpha: 0.6),
              );
            }
          }
        } else {
          // Phase 2: Men Strike (Red Effect / 面打ち)
          final strikePaint = Paint()
            ..color = const Color(0xFFFF1744)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5.0;
          canvas.drawArc(
            Rect.fromCircle(center: Offset(30, -50 + stepBounce), radius: 40),
            -math.pi / 4,
            math.pi / 2,
            false,
            strikePaint,
          );
        }
      }
    }

    // Staggered / Vulnerable Window Badge (反撃チャンス) for CPU
    if (!isPlayer && cpuVulnerableTimer > 0) {
      final vulnCirclePaint = Paint()
        ..color = const Color(0xAAFFD54F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;
      canvas.drawCircle(Offset(0, -60 + stepBounce), 36, vulnCirclePaint);

      _drawUnflippedText(
        canvas,
        text: 'スキあり',
        style: const TextStyle(
          color: Colors.amberAccent,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(color: Colors.black, blurRadius: 4)],
        ),
        position: Offset(0, -114 + stepBounce),
      );
    }

    // Hit Stun
    if (hitStunTimer > 0) {
      final hitFlashPaint = Paint()
        ..color = const Color(0x66FF1744)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(0, -60 + stepBounce), 36, hitFlashPaint);
    }

    // 1. Hakama (1P: Navy, 2P: Black)
    final hakamaPaint = Paint()..color = hakamaColor;
    final hakamaPath = Path()
      ..moveTo(-18, -10 + stepBounce)
      ..lineTo(18, -10 + stepBounce)
      ..lineTo(22, -45 + stepBounce)
      ..lineTo(-22, -45 + stepBounce)
      ..close();
    canvas.drawPath(hakamaPath, hakamaPaint);

    // Bare feet / Tabi (Bottom edge reaches Y = 0 when stepBounce = 0)
    final footPaint = Paint()..color = const Color(0xFFFAFAFA);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-16, -10 + stepBounce, 12, 10),
        const Radius.circular(3),
      ),
      footPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(4, -10 + stepBounce, 12, 10),
        const Radius.circular(3),
      ),
      footPaint,
    );

    // 2. Tare
    final tarePaint = Paint()..color = const Color(0xFF212121);
    final tareOutline = Paint()
      ..color = const Color(0xFF757575)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final tareRect = Rect.fromLTWH(-16, -50 + stepBounce, 32, 22);
    canvas.drawRRect(
      RRect.fromRectAndRadius(tareRect, const Radius.circular(2)),
      tarePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(tareRect, const Radius.circular(2)),
      tareOutline,
    );

    // Name tag
    final zekkenRect = Rect.fromLTWH(-6, -46 + stepBounce, 12, 14);
    canvas.drawRect(zekkenRect, Paint()..color = const Color(0xFFFFFFFF));
    canvas.drawRect(
      zekkenRect,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // 3. Keikogi & Do
    final giPaint = Paint()..color = keikogiColor;
    canvas.drawRect(
      Rect.fromLTWH(-18, -75 + stepBounce, 36, 28),
      giPaint,
    );

    // Do (Lacquered Chest Armor & Accent Band - 1P: Red, 2P: White)
    final doPaint = Paint()..color = const Color(0xFF111111);
    final doHighlight = Paint()..color = doBandColor;
    final doRect = Rect.fromLTWH(-15, -70 + stepBounce, 30, 22);
    canvas.drawRRect(
      RRect.fromRectAndRadius(doRect, const Radius.circular(4)),
      doPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(-15, -62 + stepBounce, 30, 4),
      doHighlight,
    );

    // 4. Men
    final menBackPaint = Paint()..color = const Color(0xFF1A1A1A);
    final menHeadRect = Rect.fromCenter(
      center: Offset(0, -82 + stepBounce),
      width: 24,
      height: 26,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(menHeadRect, const Radius.circular(6)),
      menBackPaint,
    );

    // Mengane Grill
    final grillPaint = Paint()
      ..color = const Color(0xFFB0BEC5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (double y = -90; y <= -78; y += 3) {
      canvas.drawLine(
        Offset(2, y + stepBounce),
        Offset(12, y + stepBounce),
        grillPaint,
      );
    }

    // Ribbon
    final ribbonPaint = Paint()..color = ribbonColor;
    canvas.drawRect(
      Rect.fromLTWH(-12, -94 + stepBounce, 8, 4),
      ribbonPaint,
    );

    // 5. Shinai
    canvas.save();
    canvas.translate(8, -60 + stepBounce);
    canvas.rotate(shinaiAngle);

    // Hands
    final kotePaint = Paint()..color = const Color(0xFF37474F);
    canvas.drawCircle(const Offset(0, 0), 6, kotePaint);
    canvas.drawCircle(const Offset(10, -2), 5, kotePaint);

    // Tsuba
    final tsubaPaint = Paint()..color = const Color(0xFF424242);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(14, -3), width: 4, height: 12),
      tsubaPaint,
    );

    // Bamboo Blade
    final shinaiPaint = Paint()..color = const Color(0xFFFFE082);
    final shinaiTipPaint = Paint()..color = const Color(0xFFFAFAFA);

    final shinaiPath = Path()
      ..moveTo(16, -5)
      ..lineTo(65, -15)
      ..lineTo(65, -12)
      ..lineTo(16, -2)
      ..close();
    canvas.drawPath(shinaiPath, shinaiPaint);

    // Shinai Tip
    canvas.drawRect(
      Rect.fromLTWH(62, -16, 5, 5),
      shinaiTipPaint,
    );

    canvas.restore();
  }
}
