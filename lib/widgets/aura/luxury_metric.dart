import 'package:flutter/material.dart';
import '../../utils/constants.dart';

class LuxuryMetric extends StatelessWidget {
  final String label;
  final String value;
  final String? trendText;
  final bool isTrendPositive;
  final double valueSize;
  final Color? valueColor;
  final CrossAxisAlignment alignment;

  const LuxuryMetric({
    super.key,
    required this.label,
    required this.value,
    this.trendText,
    this.isTrendPositive = true,
    this.valueSize = 48.0,
    this.valueColor,
    this.alignment = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Micro-label with tracking
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 6),

        // 2. Massive Financial Number
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? AppColors.textPrimary,
            fontSize: valueSize,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.0,
            height: 1.1,
          ),
        ),

        // 3. Trend Indicator Badge
        if (trendText != null) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isTrendPositive ? AppColors.success : AppColors.warning)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: (isTrendPositive ? AppColors.success : AppColors.warning)
                        .withValues(alpha: 0.3),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isTrendPositive
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      color: isTrendPositive ? AppColors.success : AppColors.warning,
                      size: 13,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      trendText!,
                      style: TextStyle(
                        color: isTrendPositive ? AppColors.success : AppColors.warning,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class InlineWealthMetric extends StatelessWidget {
  final String label;
  final String amount;
  final Color dotColor;

  const InlineWealthMetric({
    super.key,
    required this.label,
    required this.amount,
    required this.dotColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: dotColor.withValues(alpha: 0.4),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$label ',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          amount,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
