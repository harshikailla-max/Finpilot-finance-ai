import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../providers/budget_provider.dart';
import '../utils/constants.dart';
import '../utils/currency_formatter.dart';
import '../widgets/glass_card.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final _limitController = TextEditingController();

  void _showEditOverallBudgetDialog(double currentLimit) {
    _limitController.text = currentLimit.toStringAsFixed(0);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.secondaryBackground,
          title: const Text('Edit Monthly Budget', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: _limitController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Enter monthly limit',
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
                final amt = double.tryParse(_limitController.text);
                if (amt != null && amt >= 0) {
                  await context.read<BudgetProvider>().setMonthlyBudget(amt);
                  if (mounted) Navigator.pop(context);
                }
              },
              child: const Text('Save', style: TextStyle(color: AppColors.cyan)),
            ),
          ],
        );
      },
    );
  }

  void _showEditCategoryBudgetDialog(String category, double currentLimit) {
    _limitController.text = currentLimit.toStringAsFixed(0);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.secondaryBackground,
          title: Text('Set $category Limit', style: const TextStyle(color: Colors.white)),
          content: TextField(
            controller: _limitController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Enter category limit',
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
                final amt = double.tryParse(_limitController.text);
                if (amt != null && amt >= 0) {
                  await context.read<BudgetProvider>().setCategoryBudget(category, amt);
                  if (mounted) Navigator.pop(context);
                }
              },
              child: const Text('Save', style: TextStyle(color: AppColors.cyan)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final financeProvider = context.watch<FinanceProvider>();
    final budgetProvider = context.watch<BudgetProvider>();

    final monthlyExpense = financeProvider.monthlyExpense;
    final totalLimit = budgetProvider.monthlyBudget;
    final remainingOverall = budgetProvider.remainingBudget(monthlyExpense);
    final overallPct = budgetProvider.budgetPercentage(monthlyExpense);
    final overallStatus = budgetProvider.budgetStatus(monthlyExpense);

    final categoryLimits = budgetProvider.categoryBudgets;
    final categorySpentMap = financeProvider.monthlyCategorySpent;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Budgets'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore_rounded),
            tooltip: 'Reset Budgets',
            onPressed: () async {
              await budgetProvider.resetBudget();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Budgets reset to default guidelines')),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Overall budget overview card
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'TOTAL BUDGET LIMIT',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_rounded, color: AppColors.cyan, size: 18),
                          onPressed: () => _showEditOverallBudgetDialog(totalLimit),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      CurrencyFormatter.format(totalLimit),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: overallPct,
                        backgroundColor: AppColors.secondaryBackground,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          overallPct >= 1.0
                              ? AppColors.dangerRed
                              : overallPct >= 0.85
                                  ? AppColors.warningOrange
                                  : AppColors.primaryPurple,
                        ),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Spent: ${CurrencyFormatter.format(monthlyExpense)} (${(overallPct * 100).toStringAsFixed(0)}%)',
                          style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.8), fontSize: 12),
                        ),
                        Text(
                          remainingOverall >= 0
                              ? 'Remaining: ${CurrencyFormatter.format(remainingOverall)}'
                              : 'Exceeded: ${CurrencyFormatter.format(-remainingOverall)}',
                          style: TextStyle(
                            color: remainingOverall >= 0 ? AppColors.successGreen : AppColors.dangerRed,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (overallPct >= 1.0
                                ? AppColors.dangerRed
                                : overallPct >= 0.75
                                    ? AppColors.warningOrange
                                    : AppColors.successGreen)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Budget Status: $overallStatus',
                        style: TextStyle(
                          color: overallPct >= 1.0
                              ? AppColors.dangerRed
                              : overallPct >= 0.75
                                  ? AppColors.warningOrange
                                  : AppColors.successGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Category Limits Title
              const Text(
                'CATEGORY BUDGET LIMITS',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),

              // Categories List
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: categoryLimits.length,
                itemBuilder: (context, index) {
                  final category = categoryLimits.keys.elementAt(index);
                  final limit = categoryLimits[category] ?? 0.0;
                  final spent = categorySpentMap[category] ?? 0.0;

                  final pct = budgetProvider.categoryPercentage(category, spent);
                  final remaining = budgetProvider.categoryRemaining(category, spent);
                  final isExceeded = spent > limit && limit > 0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: GlassCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.05),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _getCategoryIcon(category),
                                      color: AppColors.cyan,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    category,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Text(
                                    limit > 0 ? CurrencyFormatter.format(limit) : 'Not Configured',
                                    style: TextStyle(
                                      color: limit > 0 ? Colors.white : AppColors.textMuted,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(Icons.edit_rounded, color: AppColors.cyan, size: 16),
                                    onPressed: () => _showEditCategoryBudgetDialog(category, limit),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (limit > 0) ...[
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: pct,
                                backgroundColor: AppColors.secondaryBackground,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isExceeded
                                      ? AppColors.dangerRed
                                      : pct >= 0.75
                                          ? AppColors.warningOrange
                                          : AppColors.successGreen,
                                ),
                                minHeight: 6,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Spent: ${CurrencyFormatter.format(spent)} (${(pct * 100).toStringAsFixed(0)}%)',
                                  style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.6), fontSize: 11),
                                ),
                                Text(
                                  isExceeded
                                      ? 'Over: ${CurrencyFormatter.format(spent - limit)}'
                                      : 'Remaining: ${CurrencyFormatter.format(remaining)}',
                                  style: TextStyle(
                                    color: isExceeded ? AppColors.dangerRed : AppColors.successGreen,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Food':
        return Icons.restaurant_rounded;
      case 'Transport':
        return Icons.directions_car_rounded;
      case 'Shopping':
        return Icons.shopping_bag_rounded;
      case 'Bills':
        return Icons.receipt_long_rounded;
      case 'Entertainment':
        return Icons.sports_esports_rounded;
      case 'Health':
        return Icons.local_hospital_rounded;
      case 'Education':
        return Icons.school_rounded;
      case 'Travel':
        return Icons.flight_takeoff_rounded;
      default:
        return Icons.category_rounded;
    }
  }
}
