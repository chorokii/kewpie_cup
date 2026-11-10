import 'package:flutter/material.dart';

import '../game/audio/sound_manager.dart';
import '../game/components/kendo_fighter.dart';
import '../game/score/score_manager.dart';
import '../main.dart';

class TitleScreen extends StatefulWidget {
  const TitleScreen({super.key});

  @override
  State<TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends State<TitleScreen> {
  static bool _soundEnabled = true;
  static bool _debugEnabled = false;

  @override
  void initState() {
    super.initState();
    SoundManager.isEnabled = _soundEnabled;
    ScoreManager.loadScore();
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
                    '・画面左右下の円アイコンが操作ガイドです（赤円＝攻撃、青円＝防御）。\n'
                    '・敵の位置に応じて赤円（攻撃）と青円（防御）が自動で入れ替わります。\n'
                    '・敵が右側にいる場合: 左エリア（青円）＝防御、左ダブルタップ＝離脱、右エリア（赤円）＝攻撃\n'
                    '・敵が左側にいる場合: 左エリア（赤円）＝攻撃、右エリア（青円）＝防御、右ダブルタップ＝離脱',
                    style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 10),
                  _buildSectionHeader('【キーボード操作（PC）】'),
                  const Text(
                    '・Q キー: 画面左側タップ相当\n'
                    '・E キー: 画面右側タップ相当\n'
                    '・S キー: 離脱\n'
                    '・P キー: ポーズ（一時停止）',
                    style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 10),
                  _buildSectionHeader('【勝負のルール（先守後攻）】'),
                  const Text(
                    '・敵の面打ち（赤エフェクト）に合わせて防御すると「ジャスト防御成功」！\n'
                    '・成功時、敵が1.5秒間「体勢崩れ（反撃チャンス）」になります。\n'
                    '・反撃チャンス中のみプレイヤーの攻撃がヒットし一本となります（平常時の攻撃は自動防がれます）。\n'
                    '・防御有効時間は設定画面で0.4秒〜3.0秒まで自由に調整可能です。\n'
                    '・制限時間30秒、2本先取で勝利！',
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
                                selected: _soundEnabled,
                                selectedColor: Colors.amber.shade800,
                                onSelected: (selected) {
                                  if (selected) {
                                    setDialogState(() => _soundEnabled = true);
                                    setState(() => _soundEnabled = true);
                                    SoundManager.isEnabled = true;
                                  }
                                },
                              ),
                              const SizedBox(width: 6),
                              ChoiceChip(
                                label: const Text('切', style: TextStyle(fontSize: 13)),
                                selected: !_soundEnabled,
                                selectedColor: Colors.red.shade900,
                                onSelected: (selected) {
                                  if (selected) {
                                    setDialogState(() => _soundEnabled = false);
                                    setState(() => _soundEnabled = false);
                                    SoundManager.isEnabled = false;
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
                                selected: _debugEnabled,
                                selectedColor: Colors.amber.shade800,
                                onSelected: (selected) {
                                  if (selected) {
                                    setDialogState(() => _debugEnabled = true);
                                    setState(() => _debugEnabled = true);
                                  }
                                },
                              ),
                              const SizedBox(width: 6),
                              ChoiceChip(
                                label: const Text('切', style: TextStyle(fontSize: 13)),
                                selected: !_debugEnabled,
                                selectedColor: Colors.red.shade900,
                                onSelected: (selected) {
                                  if (selected) {
                                    setDialogState(() => _debugEnabled = false);
                                    setState(() => _debugEnabled = false);
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white24, height: 18),
                      // 3. Guard Active Duration Slider (400ms ～ 3000ms / 0.4s ～ 3.0s)
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
                                '${KendoFighter.guardActiveDuration.toStringAsFixed(1)}秒 (${(KendoFighter.guardActiveDuration * 1000).toInt()}ms)',
                                style: const TextStyle(color: Colors.amberAccent, fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          Slider(
                            value: KendoFighter.guardActiveDuration.clamp(0.4, 3.0),
                            min: 0.4,
                            max: 3.0,
                            divisions: 26, // 0.1s刻み (0.4s, 0.5s, ..., 3.0s)
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

            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Title Logo / Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
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
                      child: const Column(
                        children: [
                          Text(
                            'キューピーカップ',
                            style: TextStyle(
                              color: Colors.amberAccent,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 3,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '剣道対戦',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 6,
                              shadows: [
                                Shadow(color: Colors.red, blurRadius: 10),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Persistent Score & Win Streak Badge
                    ValueListenableBuilder<int>(
                      valueListenable: ScoreManager.winsNotifier,
                      builder: (context, wins, _) {
                        return ValueListenableBuilder<int>(
                          valueListenable: ScoreManager.lossesNotifier,
                          builder: (context, losses, _) {
                            return ValueListenableBuilder<int>(
                              valueListenable: ScoreManager.streakNotifier,
                              builder: (context, streak, _) {
                                final streakText = streak > 0 ? ' ($streak連勝中！)' : '';
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
                    const SizedBox(height: 20),

                    // 3 Menu Choice Buttons: 試合開始, 心得, 設定
                    _buildMenuButton(
                      icon: Icons.play_arrow,
                      label: '試合開始',
                      color: Colors.red.shade900,
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => GamePage(
                              isDebugEnabled: _debugEnabled,
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
                      onPressed: _openGuideDialog,
                    ),
                    const SizedBox(height: 14),

                    _buildMenuButton(
                      icon: Icons.settings,
                      label: '設定',
                      color: Colors.blueGrey.shade900,
                      onPressed: _openSettingsDialog,
                    ),
                  ],
                ),
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
  }) {
    return SizedBox(
      width: 240,
      height: 48,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Colors.amber, width: 1.5),
          ),
          elevation: 6,
        ),
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.amberAccent, size: 24),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}
