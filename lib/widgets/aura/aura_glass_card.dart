import 'dart:ui';
import 'package:flutter/material.dart';
import '../../utils/constants.dart';

enum AuraGlassLevel {
  level1, // Flat atmospheric section
  level2, // Soft glass surface
  level3, // Premium elevated card
  level4, // Hero intelligence surface
}

class AuraGlassCard extends StatelessWidget {
  final Widget child;
  final AuraGlassLevel level;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? borderRadius;
  final Color? customBorderColor;
  final Color? customGlowColor;
  final VoidCallback? onTap;

  const AuraGlassCard({
    super.key,
    required this.child,
    this.level = AuraGlassLevel.level2,
    this.padding,
    this.margin,
    this.borderRadius,
    this.customBorderColor,
    this.customGlowColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double radius = borderRadius ?? _defaultRadius(level);
    final BoxDecoration decoration = _buildDecoration(level, radius);

    Widget content = Container(
      margin: margin,
      decoration: decoration,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
          child: Padding(
            padding: padding ?? _defaultPadding(level),
            child: child,
          ),
        ),
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: content,
      );
    }

    return content;
  }

  double _defaultRadius(AuraGlassLevel lvl) {
    switch (lvl) {
      case AuraGlassLevel.level1:
        return 18.0;
      case AuraGlassLevel.level2:
        return 22.0;
      case AuraGlassLevel.level3:
        return 24.0;
      case AuraGlassLevel.level4:
        return 28.0;
    }
  }

  EdgeInsetsGeometry _defaultPadding(AuraGlassLevel lvl) {
    switch (lvl) {
      case AuraGlassLevel.level1:
        return const EdgeInsets.all(14.0);
      case AuraGlassLevel.level2:
        return const EdgeInsets.all(18.0);
      case AuraGlassLevel.level3:
        return const EdgeInsets.all(20.0);
      case AuraGlassLevel.level4:
        return const EdgeInsets.all(24.0);
    }
  }

  BoxDecoration _buildDecoration(AuraGlassLevel lvl, double radius) {
    switch (lvl) {
      case AuraGlassLevel.level1:
        return BoxDecoration(
          color: Colors.white.withValues(alpha: 0.025),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: customBorderColor ?? Colors.white.withValues(alpha: 0.05),
            width: 1,
          ),
        );

      case AuraGlassLevel.level2:
        return BoxDecoration(
          color: Colors.white.withValues(alpha: 0.045),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: customBorderColor ?? AppColors.glassBorder,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        );

      case AuraGlassLevel.level3:
        return BoxDecoration(
          color: AppColors.cardBackground.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: customBorderColor ?? Colors.white.withValues(alpha: 0.10),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
            if (customGlowColor != null)
              BoxShadow(
                color: customGlowColor!.withValues(alpha: 0.15),
                blurRadius: 28,
                spreadRadius: 1,
              ),
          ],
        );

      case AuraGlassLevel.level4:
        return BoxDecoration(
          gradient: LinearGradient(
            colors: [
              (customGlowColor ?? AppColors.auroraViolet).withValues(alpha: 0.18),
              AppColors.cardBackground.withValues(alpha: 0.90),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: customBorderColor ?? (customGlowColor ?? AppColors.auroraCyan).withValues(alpha: 0.35),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: (customGlowColor ?? AppColors.auroraViolet).withValues(alpha: 0.20),
              blurRadius: 36,
              spreadRadius: 2,
              offset: const Offset(0, 12),
            ),
          ],
        );
    }
  }
}
