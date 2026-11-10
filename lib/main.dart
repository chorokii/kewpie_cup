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
        scaffoldBackgroundColor: const Color(0xFF0D0D11),
      ),
      builder: (context, child) {
        return LandscapeWrapper(child: child ?? const SizedBox.shrink());
      },
      home: const TitleScreen(),
    );
  }
}

class LandscapeWrapper extends StatelessWidget {
  const LandscapeWrapper({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        final size = MediaQuery.of(context).size;
        final isPortrait = orientation == Orientation.portrait && size.width < size.height;

        return Stack(
          children: [
            child,
            if (isPortrait)
              Positioned.fill(
                child: Container(
                  color: const Color(0xFF0D0D11),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.red.shade900.withValues(alpha: 0.85),
                              border: Border.all(color: Colors.amberAccent, width: 2.5),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black87,
                                  blurRadius: 15,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.screen_rotation,
                              color: Colors.amberAccent,
                              size: 52,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            '画面を横向きにしてください',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.amberAccent,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                              decoration: TextDecoration.none,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'スマホを横向きに傾けると対戦を開始できます',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.normal,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
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
