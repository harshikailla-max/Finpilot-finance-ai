import 'package:flutter/material.dart';

import '../../utils/constants.dart';

enum AuraOrbState { idle, thinking, speaking, alert, success }

class FinPilotAuraOrb extends StatefulWidget {
  final double size;
  final AuraOrbState state;
  final VoidCallback? onTap;
  final bool showOuterHalo;

  const FinPilotAuraOrb({
    super.key,
    this.size = 70.0,
    this.state = AuraOrbState.idle,
    this.onTap,
    this.showOuterHalo = true,
  });

  @override
  State<FinPilotAuraOrb> createState() => _FinPilotAuraOrbState();
}

class _FinPilotAuraOrbState extends State<FinPilotAuraOrb>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: _durationForState(widget.state),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.90, end: 1.10).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void didUpdateWidget(covariant FinPilotAuraOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _pulseController.duration = _durationForState(widget.state);
      _pulseController.repeat(reverse: true);
    }
  }

  Duration _durationForState(AuraOrbState state) {
    switch (state) {
      case AuraOrbState.thinking:
        return const Duration(milliseconds: 1200);
      case AuraOrbState.speaking:
        return const Duration(milliseconds: 800);
      case AuraOrbState.alert:
        return const Duration(milliseconds: 1500);
      case AuraOrbState.success:
        return const Duration(milliseconds: 2200);
      case AuraOrbState.idle:
        return const Duration(milliseconds: 3200);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = _colorsForState(widget.state);

    Widget orb = AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final scale = _pulseAnimation.value;
        return Container(
          width: widget.size * scale,
          height: widget.size * scale,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                colors[0].withValues(alpha: 0.95),
                colors[1].withValues(alpha: 0.65),
                colors[2].withValues(alpha: 0.0),
              ],
              stops: const [0.2, 0.6, 1.0],
            ),
            boxShadow: [
              if (widget.showOuterHalo)
                BoxShadow(
                  color: colors[0].withValues(alpha: 0.35),
                  blurRadius: widget.size * 0.6,
                  spreadRadius: widget.size * 0.1,
                ),
              BoxShadow(
                color: colors[1].withValues(alpha: 0.25),
                blurRadius: widget.size * 0.3,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: widget.size * 0.35,
              height: widget.size * 0.35,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.95),
                    colors[0].withValues(alpha: 0.4),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    if (widget.onTap != null) {
      return GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: orb,
      );
    }

    return orb;
  }

  List<Color> _colorsForState(AuraOrbState state) {
    switch (state) {
      case AuraOrbState.idle:
        return const [
          AppColors.auroraViolet,
          AppColors.auroraCyan,
          AppColors.softBlue,
        ];
      case AuraOrbState.thinking:
        return const [
          AppColors.auroraCyan,
          AppColors.auroraViolet,
          AppColors.softBlue,
        ];
      case AuraOrbState.speaking:
        return const [
          AppColors.auroraCyan,
          AppColors.success,
          AppColors.auroraViolet,
        ];
      case AuraOrbState.alert:
        return const [
          AppColors.warning,
          AppColors.danger,
          AppColors.auroraViolet,
        ];
      case AuraOrbState.success:
        return const [
          AppColors.luxuryChampagne,
          AppColors.success,
          AppColors.auroraViolet,
        ];
    }
  }
}
