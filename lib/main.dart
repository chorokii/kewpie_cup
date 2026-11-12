import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/kendo_game.dart';
import 'screens/title_screen.dart';
import 'widgets/fighting_hud.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // タイトル画面や選手登録を縦画面でも操作できるよう、初期状態では全方向を許可する
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
    // 対戦画面開始時にOS側へ横画面への切り替えを要求する
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    game = KendoGame();
    game.isDebugVisibleNotifier.value = widget.isDebugEnabled;
  }

  @override
  void dispose() {
    // タイトル画面へ戻る際は縦画面・横画面のどちらでも操作できるよう全方向許可に戻す
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
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

          // 縦画面状態で対戦が開始された場合でも、自動的に90度回転して横画面表示にする
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
