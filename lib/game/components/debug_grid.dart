import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class DebugGrid extends PositionComponent {
  DebugGrid({required this.isDebugVisible}) {
    priority = 100; // 最前面に表示
  }

  final ValueNotifier<bool> isDebugVisible;

  @override
  void render(Canvas canvas) {
    if (!isDebugVisible.value) return;

    super.render(canvas);

    // ==========================================
    // ペイント設定
    // ==========================================
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = 1.0;

    final centerLinePaint = Paint()
      ..color = Colors.redAccent.withValues(alpha: 0.8)
      ..strokeWidth = 2.0;

    final boundaryPaint = Paint()
      ..color = Colors.greenAccent.withValues(alpha: 0.8)
      ..strokeWidth = 2.0;

    final stageLimitPaint = Paint()
      ..color = Colors.amberAccent.withValues(alpha: 0.7)
      ..strokeWidth = 1.5;

    // ==========================================
    // 1. 横方向（Y軸）水平ガイドライン描画
    // ==========================================
    for (double y = -350; y <= 350; y += 50) {
      if (y == 0) {
        canvas.drawLine(const Offset(-640, 0), const Offset(640, 0), centerLinePaint);
        _drawLabel(canvas, 'Y = 0 (Center)', const Offset(-620, -16), Colors.redAccent);
      } else {
        canvas.drawLine(Offset(-640, y), Offset(640, y), linePaint);
        _drawLabel(canvas, 'Y = ${y.toInt()}', Offset(-620, y - 12), Colors.white70);
      }
    }

    // 上端・下端境界線
    canvas.drawLine(const Offset(-640, -360), const Offset(640, -360), boundaryPaint);
    _drawLabel(canvas, 'Y = -360 (Top)', const Offset(-600, -350), Colors.greenAccent);

    canvas.drawLine(const Offset(-640, 360), const Offset(640, 360), boundaryPaint);
    _drawLabel(canvas, 'Y = +360 (Bottom)', const Offset(-600, 340), Colors.greenAccent);

    // ==========================================
    // 2. 縦方向（X軸）垂直ガイドライン描画
    // ==========================================
    // 100px 刻みで描画（-600 から +600）
    for (double x = -600; x <= 600; x += 100) {
      if (x == 0) {
        // 中央垂直線
        canvas.drawLine(const Offset(0, -360), const Offset(0, 360), centerLinePaint);
        _drawLabel(canvas, 'X = 0', const Offset(-20, -340), Colors.redAccent);
      } else {
        canvas.drawLine(Offset(x, -360), Offset(x, 360), linePaint);
        _drawLabel(canvas, '${x.toInt()}', Offset(x - 18, -340), Colors.white70);
      }
    }

    // ステージ壁境界線（X = ±520）
    canvas.drawLine(const Offset(-520, -360), const Offset(-520, 360), stageLimitPaint);
    _drawLabel(canvas, 'Stage Min (-520)', const Offset(-515, -310), Colors.amberAccent);

    canvas.drawLine(const Offset(520, -360), const Offset(520, 360), stageLimitPaint);
    _drawLabel(canvas, 'Stage Max (+520)', const Offset(410, -310), Colors.amberAccent);

    // 画面左右端境界線（X = ±640）
    canvas.drawLine(const Offset(-640, -360), const Offset(-640, 360), boundaryPaint);
    _drawLabel(canvas, 'X = -640 (Left)', const Offset(-635, -280), Colors.greenAccent);

    canvas.drawLine(const Offset(640, -360), const Offset(640, 360), boundaryPaint);
    _drawLabel(canvas, 'X = +640 (Right)', const Offset(530, -280), Colors.greenAccent);
  }

  void _drawLabel(Canvas canvas, String text, Offset offset, Color color) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          backgroundColor: Colors.black87,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    painter.paint(canvas, offset);
  }
}
