import 'package:flutter/material.dart';
import 'dart:math' as math;

class IntroSplashScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const IntroSplashScreen({
    super.key,
    required this.onComplete,
  });

  @override
  State<IntroSplashScreen> createState() => _IntroSplashScreenState();
}

class _IntroSplashScreenState extends State<IntroSplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _orbController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Fade in animation
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    // Scale animation
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    // Orb rotation animation
    _orbController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    // Start animations
    _fadeController.forward();
    _scaleController.forward();

    // Auto-dismiss after 3 seconds (or tap to skip)
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  void _dismiss() {
    _fadeController.reverse().then((_) {
      if (mounted) {
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _orbController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _dismiss,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              colors: [
                Color(0xFF1A1A2E),
                Color(0xFF050507),
              ],
            ),
          ),
          child: AnimatedBuilder(
            animation: Listenable.merge([_fadeController, _scaleController]),
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Animated orbs
                        SizedBox(
                          width: 200,
                          height: 200,
                          child: AnimatedBuilder(
                            animation: _orbController,
                            builder: (context, child) {
                              return CustomPaint(
                                painter: RotatingOrbsPainter(
                                  animation: _orbController.value,
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 40),

                        // Game title
                        const Text(
                          'ZEN DROP',
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 4,
                            shadows: [
                              Shadow(
                                color: Color(0xFF00F2FF),
                                blurRadius: 20,
                              ),
                              Shadow(
                                color: Color(0xFF00F2FF),
                                blurRadius: 40,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Subtitle
                        const Text(
                          'NEON MERGE',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w300,
                            color: Colors.white70,
                            letterSpacing: 8,
                          ),
                        ),
                        const SizedBox(height: 60),

                        // Tap to continue hint
                        FadeTransition(
                          opacity: Tween<double>(begin: 0.3, end: 1.0).animate(
                            CurvedAnimation(
                              parent: _orbController,
                              curve: Curves.easeInOut,
                            ),
                          ),
                          child: const Text(
                            'TAP TO CONTINUE',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white38,
                              letterSpacing: 3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class RotatingOrbsPainter extends CustomPainter {
  final double animation;

  RotatingOrbsPainter({required this.animation});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 3;

    // Define orb colors
    final colors = [
      const Color(0xFF00F2FF), // Cyan
      const Color(0xFF7AE7FF), // Light blue
      const Color(0xFF7EFF00), // Lime
      const Color(0xFFFFD700), // Gold
      const Color(0xFFFF4D00), // Orange
      const Color(0xFFFF0055), // Pink
    ];

    // Draw rotating orbs
    for (int i = 0; i < colors.length; i++) {
      final angle = (animation * 2 * math.pi) + (i * 2 * math.pi / colors.length);
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      final orbSize = 15.0 + (5.0 * math.sin(animation * 4 * math.pi + i));

      _drawGlassOrb(canvas, Offset(x, y), orbSize, colors[i]);
    }

    // Draw center orb
    _drawGlassOrb(canvas, center, 25.0, Colors.white);
  }

  void _drawGlassOrb(Canvas canvas, Offset center, double radius, Color baseColor) {
    // Outer glow
    final glowPaint = Paint()
      ..color = baseColor.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
    canvas.drawCircle(center, radius * 1.5, glowPaint);

    // Main orb body with radial gradient
    final mainGradient = RadialGradient(
      center: const Alignment(-0.3, -0.3),
      radius: 1.2,
      colors: [
        baseColor.withValues(alpha: 0.4),
        baseColor.withValues(alpha: 0.8),
        baseColor,
      ],
      stops: const [0.0, 0.6, 1.0],
    );

    final mainPaint = Paint()
      ..shader = mainGradient.createShader(
        Rect.fromCircle(center: center, radius: radius),
      );
    canvas.drawCircle(center, radius, mainPaint);

    // Top highlight
    final highlightCenter = Offset(
      center.dx - radius * 0.25,
      center.dy - radius * 0.25,
    );
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(highlightCenter, radius * 0.3, highlightPaint);

    // Rim
    final rimPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius - 1, rimPaint);
  }

  @override
  bool shouldRepaint(RotatingOrbsPainter oldDelegate) => true;
}