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

class LandscapeWrapper extends StatefulWidget {
  const LandscapeWrapper({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<LandscapeWrapper> createState() => _LandscapeWrapperState();
}

class _LandscapeWrapperState extends State<LandscapeWrapper> {
  bool _isDismissedManually = false;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;

    // Reset manual dismissal if phone is turned landscape
    if (isLandscape && _isDismissedManually) {
      _isDismissedManually = false;
    }

    final showOverlay = !isLandscape && !_isDismissedManually;

    return Stack(
      children: [
        widget.child,
        if (showOverlay)
          Positioned.fill(
            child: Container(
              color: const Color(0xFF0D0D11),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(18),
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
                            size: 44,
                          ),
                        ),
                        const SizedBox(height: 18),
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
                        const SizedBox(height: 8),
                        const Text(
                          'スマホを横向きに傾けると横画面で快適にプレイできます。\n'
                          '※スマホの「画面縦向きロック」がオンの場合は解除してください。',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.normal,
                            height: 1.4,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber.shade900,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            side: const BorderSide(color: Colors.amberAccent, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              _isDismissedManually = true;
                            });
                          },
                          icon: const Icon(Icons.play_arrow, size: 20),
                          label: const Text(
                            'このまま対戦を開始する',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
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
