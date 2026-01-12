import 'package:flutter/material.dart';
import '../game/physics_world.dart';

class GameRenderer extends StatelessWidget {
  final PhysicsWorld physicsWorld;
  final bool showDeathLine;

  const GameRenderer({
    super.key,
    required this.physicsWorld,
    required this.showDeathLine,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: GamePainter(
        physicsWorld: physicsWorld,
        showDeathLine: showDeathLine,
      ),
      child: Container(),
    );
  }
}

class GamePainter extends CustomPainter {
  final PhysicsWorld physicsWorld;
  final bool showDeathLine;

  GamePainter({
    required this.physicsWorld,
    required this.showDeathLine,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / physicsWorld.worldWidth;
    final scaleY = size.height / physicsWorld.worldHeight;

    // Draw death line
    if (showDeathLine) {
      final deathY = physicsWorld.deathLineY * scaleY;
      final paint = Paint()
        ..color = const Color(0xFFFF0055).withValues(alpha: 0.6)
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke;
      
      canvas.drawLine(
        Offset(0, deathY),
        Offset(size.width, deathY),
        paint,
      );
    }

    // Draw orbs with glass effect
    for (final orb in physicsWorld.orbs) {
      final x = orb.body.position.x * scaleX;
      final y = orb.body.position.y * scaleY;
      final radius = orb.radius;

      _drawGlassOrb(canvas, Offset(x, y), radius, orb.color);
    }
  }

  void _drawGlassOrb(Canvas canvas, Offset center, double radius, Color baseColor) {
    // Shadow (bottom glow)
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(
      Offset(center.dx, center.dy + radius * 0.2),
      radius * 0.9,
      shadowPaint,
    );

    // Main orb body with radial gradient
    final mainGradient = RadialGradient(
      center: const Alignment(-0.3, -0.3),
      radius: 1.2,
      colors: [
        baseColor.withValues(alpha: 0.4),
        baseColor.withValues(alpha: 0.8),
        baseColor,
        baseColor.withValues(alpha: 0.9),
      ],
      stops: const [0.0, 0.4, 0.7, 1.0],
    );

    final mainPaint = Paint()
      ..shader = mainGradient.createShader(
        Rect.fromCircle(center: center, radius: radius),
      );
    canvas.drawCircle(center, radius, mainPaint);

    // Top highlight (glossy reflection)
    final highlightCenter = Offset(
      center.dx - radius * 0.25,
      center.dy - radius * 0.25,
    );
    final highlightGradient = RadialGradient(
      colors: [
        Colors.white.withValues(alpha: 0.8),
        Colors.white.withValues(alpha: 0.4),
        Colors.white.withValues(alpha: 0.0),
      ],
      stops: const [0.0, 0.5, 1.0],
    );

    final highlightPaint = Paint()
      ..shader = highlightGradient.createShader(
        Rect.fromCircle(center: highlightCenter, radius: radius * 0.5),
      );
    canvas.drawCircle(highlightCenter, radius * 0.5, highlightPaint);

    // Secondary highlight (smaller, sharper)
    final shine1 = Offset(
      center.dx - radius * 0.35,
      center.dy - radius * 0.35,
    );
    final shine1Paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(shine1, radius * 0.15, shine1Paint);

    // Inner shadow for depth
    final innerShadowGradient = RadialGradient(
      center: const Alignment(0.4, 0.4),
      radius: 0.8,
      colors: [
        Colors.transparent,
        Colors.black.withValues(alpha: 0.15),
        Colors.black.withValues(alpha: 0.25),
      ],
      stops: const [0.0, 0.7, 1.0],
    );

    final innerShadowPaint = Paint()
      ..shader = innerShadowGradient.createShader(
        Rect.fromCircle(center: center, radius: radius),
      );
    canvas.drawCircle(center, radius, innerShadowPaint);

    // Glass rim (edge highlight)
    final rimPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(center, radius - 1, rimPaint);

    // Outer glow
    final glowGradient = RadialGradient(
      colors: [
        baseColor.withValues(alpha: 0.4),
        baseColor.withValues(alpha: 0.2),
        baseColor.withValues(alpha: 0.0),
      ],
      stops: const [0.0, 0.5, 1.0],
    );

    final glowPaint = Paint()
      ..shader = glowGradient.createShader(
        Rect.fromCircle(center: center, radius: radius * 1.3),
      )
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(center, radius * 1.2, glowPaint);

    // Bottom reflection (ground light)
    final bottomReflection = Offset(
      center.dx + radius * 0.2,
      center.dy + radius * 0.4,
    );
    final reflectionGradient = RadialGradient(
      colors: [
        Colors.white.withValues(alpha: 0.2),
        Colors.white.withValues(alpha: 0.05),
        Colors.transparent,
      ],
      stops: const [0.0, 0.5, 1.0],
    );

    final reflectionPaint = Paint()
      ..shader = reflectionGradient.createShader(
        Rect.fromCircle(center: bottomReflection, radius: radius * 0.4),
      );
    canvas.drawCircle(bottomReflection, radius * 0.4, reflectionPaint);
  }

  @override
  bool shouldRepaint(GamePainter oldDelegate) => true;
}