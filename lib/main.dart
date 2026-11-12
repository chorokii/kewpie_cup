import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/kendo_game.dart';
import 'screens/title_screen.dart';
import 'widgets/fighting_hud.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // モバイル端末を横持ちに持ち替えた際のOS再描画・画面縮小を防ぐため、
  // 画面の向きは portraitUp（縦向き基準）に固定し、対戦画面は RotatedBox で横表示する
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

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
    // 端末を横持ちにした際にOS・ブラウザの再描画で背景やキャラが縮小されるのを防ぐため、
    // 縦向き固定を維持したまま RotatedBox(quarterTurns: 1) の比率で横画面表示を行う
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    game = KendoGame();
    game.isDebugVisibleNotifier.value = widget.isDebugEnabled;
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D11),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isPortrait = constraints.maxWidth < constraints.maxHeight;

          final gameWidget = GameWidget<KendoGame>(
            game: game,
            overlayBuilderMap: {
              'HudOverlay': (context, game) => FightingHudOverlay(game: game),
            },
            initialActiveOverlays: const ['HudOverlay'],
          );

          // 縦長画面（スマホ等）では常時90度回転して、縮小のない最適な比率で横画面表示にする
          if (isPortrait) {
            return RotatedBox(
              key: const ValueKey('auto_landscape_rotated_box'),
              quarterTurns: 1,
              child: gameWidget,
            );
          }

          return gameWidget;
        },
      ),
    );
  }
}
