import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/financial_health_provider.dart';
import '../providers/ai_provider.dart';
import '../utils/constants.dart';
import '../widgets/glass_card.dart';

class FinancialHealthScreen extends StatefulWidget {
  const FinancialHealthScreen({super.key});

  @override
  State<FinancialHealthScreen> createState() => _FinancialHealthScreenState();
}

class _FinancialHealthScreenState extends State<FinancialHealthScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getScoreColor(double score) {
    if (score >= 90) return AppColors.successGreen;
    if (score >= 75) return AppColors.cyan;
    if (score >= 60) return AppColors.warningOrange;
    return AppColors.dangerRed;
  }

  @override
  Widget build(BuildContext context) {
    final healthProvider = context.watch<FinancialHealthProvider>();
    final healthData = healthProvider.healthData;
    final totalScore = healthProvider.healthScore;
    final scoreLabel = healthData.scoreLabel;

    final aiProvider = context.watch<AIProvider>();
    // Filter recommendations specifically for advice
    final recommendations = aiProvider.insights
        .where((i) => i.type == 'tip' || i.type == 'warning')
        .toList();

    final scoreColor = _getScoreColor(totalScore);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Health Index'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scoreColor.withValues(alpha: 0.08),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 12),

                  // Score Dial Display
                  AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      final scoreVal = totalScore * _animation.value;
                      return Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.cardBackground,
                          boxShadow: [
                            BoxShadow(
                              color: scoreColor.withValues(alpha: 0.1),
                              blurRadius: 40,
                              spreadRadius: 6,
                            ),
                          ],
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.04),
                            width: 2,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 180,
                              height: 180,
                              child: CircularProgressIndicator(
                                value: scoreVal / 100,
                                strokeWidth: 14,
                                backgroundColor: AppColors.secondaryBackground,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  scoreColor,
                                ),
                              ),
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  scoreVal.toStringAsFixed(0),
                                  style: const TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: -1,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  scoreLabel.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: scoreColor,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 36),

                  // Score Breakdown grid
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'SCORE BREAKDOWN',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GlassCard(
                    child: Column(
                      children: [
                        _buildBreakdownRow(
                          title: 'Savings Rate',
                          score: healthProvider.savingsScore,
                          max: 25,
                          icon: Icons.savings_rounded,
                        ),
                        const Divider(height: 24, color: Colors.white10),
                        _buildBreakdownRow(
                          title: 'Budget Discipline',
                          score: healthProvider.budgetScore,
                          max: 25,
                          icon: Icons.pie_chart_rounded,
                        ),
                        const Divider(height: 24, color: Colors.white10),
                        _buildBreakdownRow(
                          title: 'Expense Control',
                          score: healthProvider.expenseControlScore,
                          max: 20,
                          icon: Icons.money_off_rounded,
                        ),
                        const Divider(height: 24, color: Colors.white10),
                        _buildBreakdownRow(
                          title: 'Positive Cash Flow',
                          score: healthProvider.cashFlowScore,
                          max: 15,
                          icon: Icons.trending_up_rounded,
                        ),
                        const Divider(height: 24, color: Colors.white10),
                        _buildBreakdownRow(
                          title: 'Goal Progress',
                          score: healthProvider.goalScore,
                          max: 15,
                          icon: Icons.flag_rounded,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Recommendations list
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'AI RECOMMENDATIONS',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (recommendations.isEmpty)
                    const GlassCard(
                      child: Center(
                        child: Text(
                          'No advice currently. Keep keeping your budgets healthy!',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    )
                  else
                    ...recommendations.map((item) {
                      final isWarning = item.type == 'warning';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: GlassCard(
                          border: Border.all(
                            color: isWarning
                                ? AppColors.dangerRed.withValues(alpha: 0.2)
                                : Colors.white.withValues(alpha: 0.04),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                isWarning
                                    ? Icons.warning_amber_rounded
                                    : Icons.auto_awesome_rounded,
                                color: isWarning
                                    ? AppColors.dangerRed
                                    : AppColors.cyan,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item.message,
                                      style: TextStyle(
                                        color: AppColors.textSecondary
                                            .withValues(alpha: 0.8),
                                        fontSize: 12,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow({
    required String title,
    required double score,
    required int max,
    required IconData icon,
  }) {
    final pct = score / max;
    return Row(
      children: [
        Icon(icon, color: AppColors.cyan, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '${score.toStringAsFixed(0)} / $max',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 5,
                  backgroundColor: AppColors.secondaryBackground,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    pct >= 0.80
                        ? AppColors.successGreen
                        : pct >= 0.50
                        ? AppColors.warningOrange
                        : AppColors.dangerRed,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
