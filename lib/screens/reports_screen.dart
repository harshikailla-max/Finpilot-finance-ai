import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../providers/budget_provider.dart';
import '../providers/financial_health_provider.dart';
import '../utils/constants.dart';
import '../utils/currency_formatter.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_button.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  void _exportPDF(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.secondaryBackground,
          title: const Text('Exporting PDF...', style: TextStyle(color: Colors.white)),
          content: const Row(
            children: [
              CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppColors.cyan)),
              SizedBox(width: 16),
              Text('Formatting PDF report...', style: TextStyle(color: Colors.white70)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Report exported to Downloads successfully!'),
                    backgroundColor: AppColors.successGreen,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              },
              child: const Text('Simulate Finish', style: TextStyle(color: AppColors.cyan)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final budget = context.watch<BudgetProvider>();
    final health = context.watch<FinancialHealthProvider>();

    final monthlyIncome = finance.monthlyIncome;
    final monthlyExpense = finance.monthlyExpense;
    final monthlySavings = finance.monthlySavings;
    final savingsRate = monthlyIncome > 0 ? (monthlySavings / monthlyIncome) * 100 : 0.0;

    final healthScore = health.healthScore;
    final budgetLimit = budget.monthlyBudget;
    final budgetStatus = budget.budgetStatus(monthlyExpense);

    final categorySpentMap = finance.monthlyCategorySpent;
    final sortedCategories = categorySpentMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final highestSpendingCategory = sortedCategories.isNotEmpty ? sortedCategories.first.key : 'None';

    // Summary Text
    final summaryText = "This month you earned ${CurrencyFormatter.format(monthlyIncome)} and spent ${CurrencyFormatter.format(monthlyExpense)}. "
        "Your savings were ${CurrencyFormatter.format(monthlySavings)}, representing a ${savingsRate.toStringAsFixed(0)}% savings rate. "
        "Your highest spending category was $highestSpendingCategory, and your overall budget status is marked as $budgetStatus. "
        "Your Financial Health Score is evaluated at ${healthScore.toStringAsFixed(0)}/100.";

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Financial Report'),
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
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryPurple.withValues(alpha: 0.05),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary Card
                  const Text(
                    'MONTH IN REVIEW',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                  ),
                  const SizedBox(height: 12),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.description_rounded, color: AppColors.cyan, size: 20),
                            SizedBox(width: 8),
                            Text('Executive Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          summaryText,
                          style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.6),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Core Metrics Card
                  const Text(
                    'FINANCIAL METRICS',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                  ),
                  const SizedBox(height: 12),
                  GlassCard(
                    child: Column(
                      children: [
                        _buildMetricRow('Total Income logged', CurrencyFormatter.format(monthlyIncome), AppColors.successGreen),
                        const Divider(height: 24, color: Colors.white10),
                        _buildMetricRow('Total Expenses logged', CurrencyFormatter.format(monthlyExpense), AppColors.dangerRed),
                        const Divider(height: 24, color: Colors.white10),
                        _buildMetricRow('Net Savings (Mo.)', CurrencyFormatter.format(monthlySavings), AppColors.cyan),
                        const Divider(height: 24, color: Colors.white10),
                        _buildMetricRow('Savings Rate %', '${savingsRate.toStringAsFixed(0)}%', Colors.white),
                        const Divider(height: 24, color: Colors.white10),
                        _buildMetricRow('Budget Limit configured', CurrencyFormatter.format(budgetLimit), Colors.white),
                        const Divider(height: 24, color: Colors.white10),
                        _buildMetricRow('Budget Usage level', budgetStatus, _getStatusColor(budgetStatus)),
                        const Divider(height: 24, color: Colors.white10),
                        _buildMetricRow('Financial Health Index', '${healthScore.toStringAsFixed(0)} / 100', AppColors.primaryPurple),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Category Spent list
                  if (sortedCategories.isNotEmpty) ...[
                    const Text(
                      'SPENDING BREAKDOWN',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                    ),
                    const SizedBox(height: 12),
                    GlassCard(
                      child: Column(
                        children: sortedCategories.map((entry) {
                          final category = entry.key;
                          final spent = entry.value;
                          final limit = budget.categorySpentLimit(category);
                          final pct = limit > 0 ? (spent / limit) : 0.0;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(category, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      CurrencyFormatter.format(spent),
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                    if (limit > 0)
                                      Text(
                                        '${(pct * 100).toStringAsFixed(0)}% of category budget limit',
                                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],

                  // PDF Trigger
                  GradientButton(
                    text: 'Export Report as PDF',
                    onTap: () => _exportPDF(context),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
        Text(
          value,
          style: TextStyle(color: valueColor, fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    if (status == 'Healthy') return AppColors.successGreen;
    if (status == 'Moderate') return AppColors.cyan;
    if (status == 'Warning') return AppColors.warningOrange;
    return AppColors.dangerRed;
  }
}
