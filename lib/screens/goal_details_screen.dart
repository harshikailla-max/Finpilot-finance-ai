import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/goal_model.dart';
import '../providers/goal_provider.dart';
import '../utils/constants.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_utils.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_button.dart';

class GoalDetailsScreen extends StatefulWidget {
  final GoalModel goal;
  const GoalDetailsScreen({super.key, required this.goal});

  @override
  State<GoalDetailsScreen> createState() => _GoalDetailsScreenState();
}

class _GoalDetailsScreenState extends State<GoalDetailsScreen> {
  final _moneyController = TextEditingController();

  @override
  void dispose() {
    _moneyController.dispose();
    super.dispose();
  }

  void _addMoneyDialog(BuildContext context, GoalModel currentGoal) {
    _moneyController.clear();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.secondaryBackground,
          title: const Text('Add Goal Savings', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: _moneyController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Enter amount to add',
              prefixIcon: Icon(Icons.currency_rupee, color: AppColors.textMuted),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () async {
                final amt = double.tryParse(_moneyController.text.trim());
                if (amt != null && amt > 0) {
                  await context.read<GoalProvider>().addMoneyToGoal(currentGoal.id, amt);
                  if (mounted) {
                    Navigator.pop(context);
                    // Refresh local view
                    setState(() {});
                  }
                }
              },
              child: const Text('Add', style: TextStyle(color: AppColors.successGreen, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _deleteGoal(BuildContext context) async {
    await context.read<GoalProvider>().deleteGoal(widget.goal.id);
    if (context.mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final goalProvider = context.watch<GoalProvider>();
    // Fetch latest instance of goal from provider in case it was modified
    final currentGoal = goalProvider.goals.firstWhere(
      (g) => g.id == widget.goal.id,
      orElse: () => widget.goal,
    );

    final pct = currentGoal.progressPercentage;
    final remaining = currentGoal.remainingAmount;
    final days = currentGoal.daysRemaining;
    final monthlyRequired = currentGoal.monthlyAmountRequired;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Goal Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.dangerRed),
            onPressed: () => _deleteGoal(context),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned(
            top: -40,
            left: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.successGreen.withValues(alpha: 0.08),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 12),

                  // Large Circular Score Visualizer
                  Center(
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.cardBackground,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.04),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.successGreen.withValues(alpha: 0.06),
                            blurRadius: 32,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 160,
                            height: 160,
                            child: CircularProgressIndicator(
                              value: pct,
                              strokeWidth: 10,
                              backgroundColor: AppColors.secondaryBackground,
                              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.successGreen),
                            ),
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${(pct * 100).toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'SAVED',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textSecondary.withValues(alpha: 0.6),
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 36),

                  // Text Info
                  Text(
                    currentGoal.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Category: ${currentGoal.category}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 32),

                  // Progress Details Card
                  GlassCard(
                    child: Column(
                      children: [
                        _buildStatRow(
                          icon: Icons.currency_rupee_rounded,
                          label: 'Target Amount',
                          value: CurrencyFormatter.format(currentGoal.targetAmount),
                        ),
                        const Divider(height: 24, color: Colors.white10),
                        _buildStatRow(
                          icon: Icons.savings_rounded,
                          label: 'Amount Saved',
                          value: CurrencyFormatter.format(currentGoal.currentAmount),
                          valueColor: AppColors.successGreen,
                        ),
                        const Divider(height: 24, color: Colors.white10),
                        _buildStatRow(
                          icon: Icons.hourglass_empty_rounded,
                          label: 'Remaining Target',
                          value: CurrencyFormatter.format(remaining),
                        ),
                        const Divider(height: 24, color: Colors.white10),
                        _buildStatRow(
                          icon: Icons.calendar_month_outlined,
                          label: 'Deadline Date',
                          value: AppDateUtils.formatFriendly(currentGoal.deadline),
                        ),
                        const Divider(height: 24, color: Colors.white10),
                        _buildStatRow(
                          icon: Icons.event_repeat_rounded,
                          label: 'Time Left',
                          value: days > 0 ? '$days days' : 'Due today',
                          valueColor: AppColors.warningOrange,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Dynamic Advice / Target Goal Forecast Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.primaryPurple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.primaryPurple.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.auto_awesome_rounded, color: AppColors.cyan, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'FINPILOT AI TARGET ESTIMATION',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (remaining <= 0)
                          const Text(
                            'Excellent work! You have completed 100% of this goal target. Allocate these funds or archiving the goal.',
                            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                          )
                        else ...[
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                              children: [
                                const TextSpan(text: 'To reach this goal by the deadline, you need to save approximately '),
                                TextSpan(
                                  text: CurrencyFormatter.format(monthlyRequired),
                                  style: const TextStyle(color: AppColors.cyan, fontWeight: FontWeight.bold),
                                ),
                                const TextSpan(text: ' each month.'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Allocating ₹3,000 more than this target can accelerate completion, reaching the target days ahead of expectation.',
                            style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.8), fontSize: 12, height: 1.4),
                          ),
                        ]
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Fund button
                  GradientButton(
                    text: 'Fund Savings Goal',
                    onTap: () => _addMoneyDialog(context, currentGoal),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textMuted),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
