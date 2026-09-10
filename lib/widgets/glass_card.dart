import 'dart:ui';
import 'package:flutter/material.dart';
import '../utils/constants.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final double? borderRadius;
  final Color? color;
  final double blur;
  final Border? border;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;

  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius,
    this.color,
    this.blur = 15.0,
    this.border,
    this.padding,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final double radius = borderRadius ?? AppConstants.cardRadius;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          width: width,
          height: height,
          padding: padding ?? const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color ?? AppColors.cardBackground.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(radius),
            border: border ?? Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1.0,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
