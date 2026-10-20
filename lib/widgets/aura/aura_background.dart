import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../utils/constants.dart';

class AuraBackground extends StatefulWidget {
  final Widget? child;
  final Color primaryGlow;
  final Color secondaryGlow;
  final double intensity;

  const AuraBackground({
    super.key,
    this.child,
    this.primaryGlow = AppColors.auroraViolet,
    this.secondaryGlow = AppColors.auroraCyan,
    this.intensity = 1.0,
  });

  @override
  State<AuraBackground> createState() => _AuraBackgroundState();
}

class _AuraBackgroundState extends State<AuraBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. Base Obsidian Gradient
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.obsidian,
                AppColors.background,
                AppColors.secondaryBackground,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),

        // 2. Animated Ambient Auroras
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final val = _controller.value;
            final double shiftX = math.sin(val * math.pi) * 30.0;
            final double shiftY = math.cos(val * math.pi) * 20.0;

            return CustomPaint(
              painter: _AuraCosmicPainter(
                primaryColor: widget.primaryGlow.withValues(
                  alpha: (0.07 * widget.intensity).clamp(0.01, 0.2),
                ),
                secondaryColor: widget.secondaryGlow.withValues(
                  alpha: (0.05 * widget.intensity).clamp(0.01, 0.2),
                ),
                animationValue: val,
                shiftX: shiftX,
                shiftY: shiftY,
              ),
              size: Size.infinite,
            );
          },
        ),

        // 3. Child content
        if (widget.child != null) widget.child!,
      ],
    );
  }
}

class _AuraCosmicPainter extends CustomPainter {
  final Color primaryColor;
  final Color secondaryColor;
  final double animationValue;
  final double shiftX;
  final double shiftY;

  _AuraCosmicPainter({
    required this.primaryColor,
    required this.secondaryColor,
    required this.animationValue,
    required this.shiftX,
    required this.shiftY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(
      size.width * 0.5 + shiftX,
      size.height * 0.2 + shiftY,
    );
    final secondCenter = Offset(
      size.width * 0.85 - shiftX,
      size.height * 0.65 - shiftY,
    );

    // Primary gentle Aurora cloud (Top center)
    final primaryPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [primaryColor, primaryColor.withValues(alpha: 0.0)],
            stops: const [0.0, 1.0],
          ).createShader(
            Rect.fromCircle(center: center, radius: size.width * 0.75),
          );

    canvas.drawCircle(center, size.width * 0.75, primaryPaint);

    // Secondary soft Cyan cloud (Mid-right)
    final secondaryPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [secondaryColor, secondaryColor.withValues(alpha: 0.0)],
            stops: const [0.0, 1.0],
          ).createShader(
            Rect.fromCircle(center: secondCenter, radius: size.width * 0.65),
          );

    canvas.drawCircle(secondCenter, size.width * 0.65, secondaryPaint);

    // Subtle micro-stars (Deterministic layout)
    final starPaint = Paint()..color = Colors.white.withValues(alpha: 0.22);
    final random = math.Random(42);
    for (int i = 0; i < 35; i++) {
      final double x = random.nextDouble() * size.width;
      final double y = random.nextDouble() * size.height;
      final double r = (random.nextDouble() * 0.8) + 0.3;
      final double twinkle =
          math.sin((animationValue * 2 * math.pi) + i) * 0.15;
      starPaint.color = Colors.white.withValues(
        alpha: (0.15 + twinkle).clamp(0.05, 0.4),
      );
      canvas.drawCircle(Offset(x, y), r, starPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AuraCosmicPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.primaryColor != primaryColor;
  }
}
