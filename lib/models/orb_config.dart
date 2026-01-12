import 'dart:ui';

class OrbConfig {
  final double radius;
  final Color color;
  final int score;

  const OrbConfig({
    required this.radius,
    required this.color,
    required this.score,
  });

  static const List<OrbConfig> levels = [
    OrbConfig(radius: 18, color: Color(0xFF00F2FF), score: 10),
    OrbConfig(radius: 28, color: Color(0xFF0072FF), score: 20),
    OrbConfig(radius: 38, color: Color(0xFF7AE7FF), score: 40),
    OrbConfig(radius: 48, color: Color(0xFF7EFF00), score: 80),
    OrbConfig(radius: 58, color: Color(0xFF33FF00), score: 160),
    OrbConfig(radius: 68, color: Color(0xFFFBFF00), score: 320),
    OrbConfig(radius: 78, color: Color(0xFFFF9D00), score: 640),
    OrbConfig(radius: 88, color: Color(0xFFFF4D00), score: 1280),
    OrbConfig(radius: 98, color: Color(0xFFFF0055), score: 2560),
    OrbConfig(radius: 115, color: Color(0xFFB700FF), score: 5120),
    OrbConfig(radius: 140, color: Color(0xFFFFFFFF), score: 10240),
  ];
}