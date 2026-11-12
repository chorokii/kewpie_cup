import 'package:flutter/material.dart';

import '../game/components/kendo_fighter.dart';
import '../game/score/score_manager.dart';
import '../main.dart';

class TitleScreen extends StatefulWidget {
  const TitleScreen({super.key});

  @override
  State<TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends State<TitleScreen> {
  @override
  void initState() {
    super.initState();
    _initSettingsAndScore();
  }

  Future<void> _initSettingsAndScore() async {
    await ScoreManager.loadScore();
    if (mounted) {
      setState(() {});
    }
  }

  void _openGuideDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey.shade900,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Colors.amber, width: 2),
          ),
          title: const Row(
            children: [
              Icon(Icons.auto_stories, color: Colors.amberAccent),
              SizedBox(width: 8),
              Text(
                '心得（ゲームの遊び方）',
                style: TextStyle(
                  color: Colors.amberAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 420,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSectionHeader('【基本操作（スマホ）】'),
                  const Text(
                    '・赤円が攻撃ボタン、青円が防御ボタン\n'
                    '・赤円（攻撃）と青円（防御）は、敵と自分の位置により入れ替わる\n'
                    '・赤円１タップ＝攻撃、ツバゼリ中２タップで吹き飛ばし\n'
                    '・青円１タップ＝防御、２タップで後ろ回避\n'
                    '・敵の攻撃は予兆があるので、見極めて防御',
                    style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 10),
                  // _buildSectionHeader('【キーボード操作（PC）】'),
                  // const Text(
                  //   '・Q キー: 画面左側タップ相当\n'
                  //   '・E キー: 画面右側タップ相当\n'
                  //   '・S キー: 離脱\n'
                  //   '・P キー: ポーズ（一時停止）',
                  //   style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                  // ),
                  // const SizedBox(height: 10),
                  _buildSectionHeader('【勝つためのルール（先守後攻）】'),
                  const Text(
                    '・画面全体が赤く光ったら防御する\n'
                    '・防御成功時、攻撃のチャンス\n'
                    '・防御成功していないと、攻撃は効かない\n'
                    '・３回攻撃を決めると、１本取れる\n'
                    '・時間切れは、相手の一本',
                    style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                '閉じる',
                style: TextStyle(color: Colors.amberAccent, fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _openSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final soundEnabled = ScoreManager.soundEnabledNotifier.value;
            final debugEnabled = ScoreManager.debugEnabledNotifier.value;

            return AlertDialog(
              backgroundColor: Colors.grey.shade900,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Colors.amber, width: 2),
              ),
              title: const Row(
                children: [
                  Icon(Icons.settings, color: Colors.amberAccent),
                  SizedBox(width: 8),
                  Text(
                    '設定',
                    style: TextStyle(
                      color: Colors.amberAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 380,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 1. Sound Effects Toggle
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '効果音',
                            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          Row(
                            children: [
                              ChoiceChip(
                                label: const Text('入', style: TextStyle(fontSize: 13)),
                                selected: soundEnabled,
                                selectedColor: Colors.amber.shade800,
                                onSelected: (selected) {
                                  if (selected) {
                                    ScoreManager.setSoundEnabled(true);
                                    setDialogState(() {});
                                    setState(() {});
                                  }
                                },
                              ),
                              const SizedBox(width: 6),
                              ChoiceChip(
                                label: const Text('切', style: TextStyle(fontSize: 13)),
                                selected: !soundEnabled,
                                selectedColor: Colors.red.shade900,
                                onSelected: (selected) {
                                  if (selected) {
                                    ScoreManager.setSoundEnabled(false);
                                    setDialogState(() {});
                                    setState(() {});
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white24, height: 18),
                      // 2. Debug Grid / Coordinates Toggle
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'デバッグ（座標表示）',
                            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          Row(
                            children: [
                              ChoiceChip(
                                label: const Text('入', style: TextStyle(fontSize: 13)),
                                selected: debugEnabled,
                                selectedColor: Colors.amber.shade800,
                                onSelected: (selected) {
                                  if (selected) {
                                    ScoreManager.setDebugEnabled(true);
                                    setDialogState(() {});
                                    setState(() {});
                                  }
                                },
                              ),
                              const SizedBox(width: 6),
                              ChoiceChip(
                                label: const Text('切', style: TextStyle(fontSize: 13)),
                                selected: !debugEnabled,
                                selectedColor: Colors.red.shade900,
                                onSelected: (selected) {
                                  if (selected) {
                                    ScoreManager.setDebugEnabled(false);
                                    setDialogState(() {});
                                    setState(() {});
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white24, height: 18),
                      // 3. Guard Active Duration Slider (200ms ～ 1000ms / 0.2s ～ 1.0s)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                '防御有効時間',
                                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '${KendoFighter.guardActiveDuration.toStringAsFixed(1)}秒 (${(KendoFighter.guardActiveDuration * 1000).round()}ms)',
                                style: const TextStyle(color: Colors.amberAccent, fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          Slider(
                            value: KendoFighter.guardActiveDuration.clamp(0.2, 1.0),
                            min: 0.2,
                            max: 1.0,
                            divisions: 8, // 0.1s刻み (0.2s, 0.3s, 0.4s, ..., 1.0s)
                            activeColor: Colors.amberAccent,
                            inactiveColor: Colors.grey.shade700,
                            label: '${KendoFighter.guardActiveDuration.toStringAsFixed(1)}秒',
                            onChanged: (val) {
                              final rounded = (val * 10).round() / 10.0;
                              setDialogState(() {
                                ScoreManager.setGuardDuration(rounded);
                              });
                              setState(() {});
                            },
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white24, height: 18),
                      // 4. Score Clear Option
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '通算スコア',
                            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade900,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              side: const BorderSide(color: Colors.amber, width: 1),
                            ),
                            onPressed: () async {
                              await ScoreManager.clearScore();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('スコアをクリアしました'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.delete_forever, size: 18),
                            label: const Text(
                              'クリア',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    '完了',
                    style: TextStyle(color: Colors.amberAccent, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.amberAccent,
        fontWeight: FontWeight.bold,
        fontSize: 14,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D11),
      body: SafeArea(
        child: Stack(
          children: [
            // Background Dojo Pattern & Border Overlay
            Positioned.fill(
              child: Container(
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  border: Border.all(color: Colors.amber.shade700, width: 3),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black87,
                      blurRadius: 15,
                      spreadRadius: 3,
                    ),
                  ],
                ),
              ),
            ),

            // Responsive Content Area
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isLandscape = constraints.maxWidth > constraints.maxHeight;
                  final isCompactHeight = constraints.maxHeight < 420;
                  final buttonWidth = isLandscape ? 180.0 : 240.0;
                  final buttonHeight = isCompactHeight ? 44.0 : 48.0;

                  return Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: isCompactHeight ? 12 : 20,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Title Logo / Header
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: isCompactHeight ? 8 : 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade900.withValues(alpha: 0.9),
                              border: Border.all(color: Colors.amber, width: 2),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black87,
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'キューピーカップ',
                                  style: TextStyle(
                                    color: Colors.amberAccent,
                                    fontSize: isCompactHeight ? 15 : 18,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 3,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '剣道対戦',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: isCompactHeight ? 28 : 36,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 6,
                                    shadows: const [
                                      Shadow(color: Colors.red, blurRadius: 10),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: isCompactHeight ? 12 : 20),

                          // Persistent Score & Win Streak Badge (2連勝以上から表示)
                          ValueListenableBuilder<int>(
                            valueListenable: ScoreManager.winsNotifier,
                            builder: (context, wins, _) {
                              return ValueListenableBuilder<int>(
                                valueListenable: ScoreManager.lossesNotifier,
                                builder: (context, losses, _) {
                                  return ValueListenableBuilder<int>(
                                    valueListenable: ScoreManager.streakNotifier,
                                    builder: (context, streak, _) {
                                      final streakText = streak >= 2 ? ' ($streak連勝中！)' : '';
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.8),
                                          border: Border.all(color: Colors.amber, width: 1.5),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          '通算成績: $wins勝 $losses敗$streakText',
                                          style: const TextStyle(
                                            color: Colors.amberAccent,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.5,
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              );
                            },
                          ),
                          SizedBox(height: isCompactHeight ? 14 : 20),

                          // 3 Menu Choice Buttons: 横画面時は横並び、縦画面時は縦並び
                          if (isLandscape)
                            Wrap(
                              spacing: 16,
                              runSpacing: 12,
                              alignment: WrapAlignment.center,
                              children: [
                                _buildMenuButton(
                                  icon: Icons.play_arrow,
                                  label: '試合開始',
                                  color: Colors.red.shade900,
                                  width: buttonWidth,
                                  height: buttonHeight,
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => GamePage(
                                          isDebugEnabled: ScoreManager.debugEnabledNotifier.value,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                _buildMenuButton(
                                  icon: Icons.auto_stories,
                                  label: '心得',
                                  color: Colors.amber.shade900,
                                  width: buttonWidth,
                                  height: buttonHeight,
                                  onPressed: _openGuideDialog,
                                ),
                                _buildMenuButton(
                                  icon: Icons.settings,
                                  label: '設定',
                                  color: Colors.blueGrey.shade900,
                                  width: buttonWidth,
                                  height: buttonHeight,
                                  onPressed: _openSettingsDialog,
                                ),
                              ],
                            )
                          else
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildMenuButton(
                                  icon: Icons.play_arrow,
                                  label: '試合開始',
                                  color: Colors.red.shade900,
                                  width: buttonWidth,
                                  height: buttonHeight,
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => GamePage(
                                          isDebugEnabled: ScoreManager.debugEnabledNotifier.value,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 14),
                                _buildMenuButton(
                                  icon: Icons.auto_stories,
                                  label: '心得',
                                  color: Colors.amber.shade900,
                                  width: buttonWidth,
                                  height: buttonHeight,
                                  onPressed: _openGuideDialog,
                                ),
                                const SizedBox(height: 14),
                                _buildMenuButton(
                                  icon: Icons.settings,
                                  label: '設定',
                                  color: Colors.blueGrey.shade900,
                                  width: buttonWidth,
                                  height: buttonHeight,
                                  onPressed: _openSettingsDialog,
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
    double width = 240,
    double height = 48,
  }) {
    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Colors.amber, width: 1.5),
          ),
          elevation: 6,
        ),
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.amberAccent, size: 22),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}
