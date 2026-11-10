import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/kendo_game.dart';
import 'screens/title_screen.dart';
import 'widgets/fighting_hud.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fix orientation to landscape for fighting game feel
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
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
        scaffoldBackgroundColor: Colors.black,
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
