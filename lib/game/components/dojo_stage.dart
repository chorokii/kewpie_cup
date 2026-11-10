import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class DojoStage extends PositionComponent {
  DojoStage({
    required this.stageWidth,
    required this.groundY,
  }) {
    size = Vector2(stageWidth, 720);
    anchor = Anchor.center;
    position = Vector2(0, 0);
    priority = -10; // Lowest layer (background)
  }

  final double stageWidth;
  final double groundY;

  Sprite? _bgSprite;
  double flashAlpha = 0.0; // 打撃直前200ms背景フラッシュ警告の不透明度 (0.0 ～ 1.0)

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    try {
      final sprite = await Sprite.load('stage/dojo_background.png');
      // Use background sprite if valid full-size image (>10px), otherwise fallback to procedural Canvas dojo
      if (sprite.image.width > 10 && sprite.image.height > 10) {
        _bgSprite = sprite;
      } else {
        _bgSprite = null;
      }
    } catch (_) {
      // Fallback to procedural Canvas drawing if asset fails or is missing
      _bgSprite = null;
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    if (_bgSprite != null) {
      _bgSprite!.render(canvas, size: size);
    } else {
      _renderFallback(canvas);
    }

    // 打撃直前200ms背景フラッシュ警告オーバーレイ（全画面・ステージ全体の背景警告フラッシュ）
    if (flashAlpha > 0.0) {
      final warningPaint = Paint()
        ..color = const Color(0xFFFF3D00).withValues(alpha: (flashAlpha * 0.60).clamp(0.0, 0.60))
        ..style = PaintingStyle.fill;

      if (_bgSprite != null) {
        // Spriteローカル領域 [0, 0] ～ [size.x, size.y]
        canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), warningPaint);
      } else {
        // キャンバス描画フォールバック領域 [-size.x / 2, -size.y / 2] ～ [size.x / 2, size.y / 2]
        canvas.drawRect(Rect.fromLTWH(-size.x / 2, -size.y / 2, size.x, size.y), warningPaint);
      }
    }
  }

  void _renderFallback(Canvas canvas) {
    // Local coordinate space for 1280x720 with Anchor.center: X: [-640, 640], Y: [-360, 360]
    final rect = Rect.fromLTWH(-size.x / 2, -size.y / 2, size.x, size.y);

    // 1. Dojo Background Wall (Local Y = -360 to +180)
    final wallPaint = Paint()..color = const Color(0xFF3E2723);
    canvas.drawRect(Rect.fromLTWH(-size.x / 2, -size.y / 2, size.x, 540), wallPaint);

    // Wall panel lines
    final linePaint = Paint()
      ..color = const Color(0xFF271510)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (double x = -size.x / 2; x < size.x / 2; x += 80) {
      canvas.drawLine(Offset(x, -size.y / 2), Offset(x, 180), linePaint);
    }

    // Shoji Screen windows (upper wall)
    final shojiFramePaint = Paint()..color = const Color(0xFF5D4037);
    final shojiPaperPaint = Paint()..color = const Color(0xFFFFF8E1);

    for (double x = -size.x / 2 + 40; x < size.x / 2 - 120; x += 180) {
      final shojiRect = Rect.fromLTWH(x, -260, 120, 100);
      canvas.drawRect(shojiRect, shojiPaperPaint);
      canvas.drawRect(shojiRect, shojiFramePaint..style = PaintingStyle.stroke..strokeWidth = 4);

      // Grid lines inside Shoji
      canvas.drawLine(Offset(x + 60, -260), Offset(x + 60, -160), shojiFramePaint..strokeWidth = 2);
      canvas.drawLine(Offset(x, -210), Offset(x + 120, -210), shojiFramePaint..strokeWidth = 2);
    }

    // Calligraphy Banner (掛軸: "正々堂々")
    final scrollRect = Rect.fromLTWH(-60, -280, 120, 180);
    canvas.drawRect(scrollRect, Paint()..color = const Color(0xFFFFFDD0));
    canvas.drawRect(
      scrollRect,
      Paint()
        ..color = const Color(0xFF8B0000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );

    // Banner Text Style
    final textPainter = TextPainter(
      text: const TextSpan(
        text: '正\n々\n堂\n堂',
        style: TextStyle(
          color: Colors.black,
          fontSize: 24,
          fontWeight: FontWeight.bold,
          height: 1.1,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(-textPainter.width / 2, -265),
    );

    // 2. Baseboard / Wall-Floor Boundary (Local Y = +180)
    final baseboardPaint = Paint()..color = const Color(0xFF271510);
    canvas.drawRect(Rect.fromLTWH(-size.x / 2, 172, size.x, 8), baseboardPaint);

    final baseboardLinePaint = Paint()
      ..color = const Color(0xFF1B0000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawLine(Offset(-size.x / 2, 180), Offset(size.x / 2, 180), baseboardLinePaint);

    // 3. Dojo Floor (Local Y = +180 to +360)
    final floorRect = Rect.fromLTWH(-size.x / 2, 180, size.x, 180);
    final floorPaint = Paint()..color = const Color(0xFF8D6E63);
    canvas.drawRect(floorRect, floorPaint);

    // Floor board planks
    final plankPaint = Paint()
      ..color = const Color(0xFF5D4037)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (double y = 180; y <= size.y / 2; y += 25) {
      canvas.drawLine(Offset(-size.x / 2, y), Offset(size.x / 2, y), plankPaint);
    }

    // Center Match Mark (床面中央標: 「｜   ×   ｜」 Local Y = 240, matching fighterGroundY)
    final centerMarkPainter = TextPainter(
      text: const TextSpan(
        text: '｜   ×   ｜',
        style: TextStyle(
          color: Colors.white,
          fontSize: 32,
          fontWeight: FontWeight.w900,
          letterSpacing: 6,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    centerMarkPainter.paint(
      canvas,
      Offset(-centerMarkPainter.width / 2, 215),
    );

    // Stage outer walls
    final wallBorderPaint = Paint()
      ..color = const Color(0xFF1B0000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12.0;
    canvas.drawRect(rect, wallBorderPaint);
  }
}
