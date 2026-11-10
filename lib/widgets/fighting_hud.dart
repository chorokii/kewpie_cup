import 'package:flutter/material.dart';

import '../game/kendo_game.dart';
import '../game/score/score_manager.dart';

class FightingHudOverlay extends StatefulWidget {
  const FightingHudOverlay({
    super.key,
    required this.game,
  });

  final KendoGame game;

  @override
  State<FightingHudOverlay> createState() => _FightingHudOverlayState();
}

class _FightingHudOverlayState extends State<FightingHudOverlay> {
  int _lastGuardTapTime = 0;
  static const int _doubleTapThresholdMs = 300;

  void _handleGuardSideInputDown() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final timeDiff = now - _lastGuardTapTime;
    _lastGuardTapTime = now;

    if (timeDiff <= _doubleTapThresholdMs) {
      debugPrint('[HUD-Input] Double-tap detected (${timeDiff}ms) -> Triggering Disengage');
      widget.game.disengageP1();
    } else {
      debugPrint('[HUD-Input] Single-tap detected (${timeDiff}ms) -> Triggering Guard Start');
      widget.game.guardP1Start();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          // 0. Full-Screen Left/Right Tap Control Gesture Area (スマホ向け画面左右タップ＆ダブルタップ離脱操作)
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (event) {
                final screenWidth = MediaQuery.of(context).size.width;
                final isTouchOnLeft = event.position.dx < screenWidth / 2;
                final isEnemyOnRight = widget.game.p1.position.x < widget.game.p2.position.x;

                if (isEnemyOnRight) {
                  // 敵が右側にいる場合: 左＝防御（ダブルタップで離脱）、右＝攻撃
                  if (isTouchOnLeft) {
                    _handleGuardSideInputDown();
                  } else {
                    widget.game.attackP1();
                  }
                } else {
                  // 敵が左側にいる場合: 左＝攻撃、右＝防御（ダブルタップで離脱）
                  if (isTouchOnLeft) {
                    widget.game.attackP1();
                  } else {
                    _handleGuardSideInputDown();
                  }
                }
              },
              onPointerUp: (_) {},
              onPointerCancel: (_) {},
              child: const SizedBox.expand(),
            ),
          ),

          // 0-B. 200ms Pre-Strike Full-Screen Warning Flash Overlay (全画面打撃直前背景フラッシュ警告)
          ValueListenableBuilder<double>(
            valueListenable: widget.game.bgFlashNotifier,
            builder: (context, flashAlpha, _) {
              if (flashAlpha <= 0.0) return const SizedBox.shrink();

              return Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    color: const Color(0xFFFF3D00).withValues(
                      alpha: (flashAlpha * 0.45).clamp(0.0, 0.45),
                    ),
                  ),
                ),
              );
            },
          ),

          // 1. Street Fighter II Style Top HUD
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // P1 Health Bar, Win Count & Name
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ValueListenableBuilder<int>(
                            valueListenable: ScoreManager.streakNotifier,
                            builder: (context, streak, _) {
                              final streakText = streak > 0 ? ' ($streak連勝中)' : '';
                              return ValueListenableBuilder<int>(
                                valueListenable: ScoreManager.winsNotifier,
                                builder: (context, totalWins, _) {
                                  return ValueListenableBuilder<int>(
                                    valueListenable: ScoreManager.lossesNotifier,
                                    builder: (context, totalLosses, _) {
                                      return Text(
                                        '1P 剣士1 [$totalWins勝$totalLosses敗$streakText]',
                                        style: const TextStyle(
                                          color: Colors.yellowAccent,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                                        ),
                                      );
                                    },
                                  );
                                },
                              );
                            },
                          ),
                          ValueListenableBuilder<int>(
                            valueListenable: widget.game.p1WinsNotifier,
                            builder: (context, wins, _) => _buildWinIndicators(wins),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ValueListenableBuilder<double>(
                        valueListenable: widget.game.p1HealthNotifier,
                        builder: (context, health, _) => _buildHealthBar(
                          healthRatio: health / 100.0,
                          isFlipped: false,
                        ),
                      ),
                    ],
                  ),
                ),

                // Center Timer / VS Emblem (30-second countdown)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.shade900,
                    border: Border.all(color: Colors.amber, width: 2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: ValueListenableBuilder<int>(
                    valueListenable: widget.game.roundTimerNotifier,
                    builder: (context, seconds, _) {
                      return Text(
                        seconds.toString().padLeft(2, '0'),
                        style: const TextStyle(
                          color: Colors.amberAccent,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      );
                    },
                  ),
                ),

                // P2 Health Bar, Win Count & Name
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ValueListenableBuilder<int>(
                            valueListenable: widget.game.p2WinsNotifier,
                            builder: (context, wins, _) => _buildWinIndicators(wins),
                          ),
                          const Text(
                            '2P 剣士2 (CPU)',
                            style: TextStyle(
                              color: Colors.cyanAccent,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ValueListenableBuilder<double>(
                        valueListenable: widget.game.p2HealthNotifier,
                        builder: (context, health, _) => _buildHealthBar(
                          healthRatio: health / 100.0,
                          isFlipped: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. Center Banner Overlay (Pre-Round Start Text & Victory/Loss Result Text)
          Center(
            child: ValueListenableBuilder<String>(
              valueListenable: widget.game.overlayTextNotifier,
              builder: (context, overlayText, _) {
                if (overlayText.isEmpty) return const SizedBox.shrink();

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.85),
                        border: Border.all(color: Colors.amberAccent, width: 3),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black87,
                            blurRadius: 10,
                            spreadRadius: 2,
                          )
                        ],
                      ),
                      child: Text(
                        overlayText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.amberAccent,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 3,
                          shadows: [
                            Shadow(color: Colors.red, blurRadius: 8),
                          ],
                        ),
                      ),
                    ),
                    ValueListenableBuilder<KendoGameState>(
                      valueListenable: widget.game.gameStateNotifier,
                      builder: (context, gameState, _) {
                        if (gameState != KendoGameState.matchOver) {
                          return const SizedBox.shrink();
                        }

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 12),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red.shade900,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                    side: const BorderSide(color: Colors.amber, width: 2),
                                  ),
                                  onPressed: widget.game.resetMatch,
                                  icon: const Icon(Icons.replay),
                                  label: const Text(
                                    '再戦 (R)',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                if (Navigator.of(context).canPop()) ...[
                                  const SizedBox(width: 12),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blueGrey.shade900,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                      side: const BorderSide(color: Colors.amber, width: 2),
                                    ),
                                    onPressed: () => Navigator.of(context).pop(),
                                    icon: const Icon(Icons.home),
                                    label: const Text(
                                      'タイトルへ',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),

          // 3. Pause Overlay Modal
          ValueListenableBuilder<bool>(
            valueListenable: widget.game.isPausedNotifier,
            builder: (context, isPaused, _) {
              if (!isPaused) return const SizedBox.shrink();

              return Positioned.fill(
                child: Container(
                  color: Colors.black54,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.9),
                        border: Border.all(color: Colors.amber, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            '一時停止中 (PAUSE)',
                            style: TextStyle(
                              color: Colors.amberAccent,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber.shade800,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                ),
                                onPressed: widget.game.togglePause,
                                icon: const Icon(Icons.play_arrow),
                                label: const Text(
                                  '再開する (P)',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ),
                              if (Navigator.of(context).canPop()) ...[
                                const SizedBox(width: 12),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blueGrey.shade900,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                    side: const BorderSide(color: Colors.amber, width: 1.5),
                                  ),
                                  onPressed: () {
                                    widget.game.togglePause();
                                    Navigator.of(context).pop();
                                  },
                                  icon: const Icon(Icons.home),
                                  label: const Text(
                                    'タイトルへ',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // 4. Bottom-Left & Bottom-Right 3x Simple Semi-Transparent Control Area Indicator Circles (文字なし・シンプルな3倍大きい半透明の円)
          ValueListenableBuilder<KendoGameState>(
            valueListenable: widget.game.gameStateNotifier,
            builder: (context, gameState, _) {
              if (gameState == KendoGameState.matchOver) return const SizedBox.shrink();

              return ValueListenableBuilder<bool>(
                valueListenable: widget.game.isEnemyOnRightNotifier,
                builder: (context, isEnemyOnRight, _) {
                  // 赤＝攻撃、青＝防御
                  // 敵が右側にいる場合: 左下＝青円（防御）、右下＝赤円（攻撃）
                  // 敵が左側にいる場合: 左下＝赤円（攻撃）、右下＝青円（防御）
                  const redColor = Color(0x66FF1744); // 赤半透明（攻撃）
                  const redBorder = Color(0xAAFF5252);

                  const blueColor = Color(0x660288D1); // 青半透明（防御）
                  const blueBorder = Color(0xAA40C4FF);

                  final leftColor = isEnemyOnRight ? blueColor : redColor;
                  final leftBorder = isEnemyOnRight ? blueBorder : redBorder;

                  final rightColor = isEnemyOnRight ? redColor : blueColor;
                  final rightBorder = isEnemyOnRight ? redBorder : blueBorder;

                  return IgnorePointer(
                    child: Stack(
                      children: [
                        // Bottom-Left 3x Simple Circle (左下操作円)
                        Positioned(
                          bottom: -20,
                          left: -20,
                          child: _buildSimpleControlCircle(
                            color: leftColor,
                            borderColor: leftBorder,
                          ),
                        ),

                        // Bottom-Right 3x Simple Circle (右下操作円)
                        Positioned(
                          bottom: -20,
                          right: -20,
                          child: _buildSimpleControlCircle(
                            color: rightColor,
                            borderColor: rightBorder,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleControlCircle({
    required Color color,
    required Color borderColor,
  }) {
    return Container(
      width: 190,
      height: 190,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: borderColor, width: 3.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
    );
  }

  Widget _buildWinIndicators(int wins) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(2, (index) {
        final isWon = index < wins;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isWon ? Colors.amberAccent : Colors.grey.shade900,
            border: Border.all(color: Colors.amber, width: 1.5),
          ),
        );
      }),
    );
  }

  Widget _buildHealthBar({
    required double healthRatio,
    required bool isFlipped,
  }) {
    final clampedRatio = healthRatio.clamp(0.0, 1.0);
    const remainingHealthColor = Color(0xFFFFD54F); // 残り体力（黄色）
    const damageColor = Color(0xFFD32F2F); // 受けたダメージ（赤色）

    // 減少アライメント:
    // 画面端側から画面中央側（タイマー側）に向けて体力が残り、端側から赤色が露出する。
    // 1P（画面左側 / isFlipped: false）: 黄色は右揃え（Alignment.centerRight）にし、左端側から削れる。
    // 2P（画面右側 / isFlipped: true） : 黄色は左揃え（Alignment.centerLeft）にし、右端側から削れる。
    final healthAlignment = isFlipped ? Alignment.centerLeft : Alignment.centerRight;

    return Container(
      height: 18,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white, width: 2), // 固定サイズの白枠
        borderRadius: BorderRadius.circular(3),
      ),
      clipBehavior: Clip.hardEdge, // 枠外への描画はみ出しを防止
      child: Stack(
        children: [
          // 1. 背景層：受けたダメージを示す赤色ベタ塗り（常時全面に敷く）
          Positioned.fill(
            child: Container(
              color: damageColor,
            ),
          ),
          // 2. 前面層：残り体力を示す黄色バー（割合に応じて伸縮）
          FractionallySizedBox(
            alignment: healthAlignment,
            widthFactor: clampedRatio,
            child: Container(
              color: remainingHealthColor,
            ),
          ),
        ],
      ),
    );
  }
}
