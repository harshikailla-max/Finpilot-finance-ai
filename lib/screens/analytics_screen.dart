import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import '../models/finance_transaction.dart';
import '../providers/finance_provider.dart';
import '../utils/constants.dart';
import '../utils/currency_formatter.dart';
import '../widgets/glass_card.dart';
import '../widgets/empty_state.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int _activeChartIndex =
      0; // 0 = Categories Donut, 1 = Income vs Exp Bar, 2 = Spending Line

  @override
  Widget build(BuildContext context) {
    final financeProvider = context.watch<FinanceProvider>();
    final transactions = financeProvider.transactions;

    if (transactions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Financial Analytics')),
        body: const EmptyState(
          icon: Icons.analytics_rounded,
          title: 'No Data for Analytics',
          description: 'Log some income and expense transactions to view detailed spending charts.',
        ),
      );
    }

    // Process statistics
    double totalIncome = financeProvider.totalIncome;
    double totalExpense = financeProvider.totalExpense;
    double savingsRate = totalIncome > 0
        ? ((totalIncome - totalExpense) / totalIncome) * 100
        : 0.0;

    // Largest Transaction
    double largestTransactionVal = 0.0;
    String largestTransactionTitle = 'None';
    for (var tx in transactions) {
      if (tx.amount > largestTransactionVal) {
        largestTransactionVal = tx.amount;
        largestTransactionTitle = tx.title;
      }
    }

    // Average Daily Expense (current month)
    final now = DateTime.now();
    final currentMonthExpenses = transactions
        .where(
          (t) =>
              t.type == TransactionType.expense &&
              t.date.year == now.year &&
              t.date.month == now.month,
        )
        .toList();

    double monthlyExpenseSum = currentMonthExpenses.fold(
      0.0,
      (sum, t) => sum + t.amount,
    );
    int daysElapsed = now.day;
    double avgDailyExpense = daysElapsed > 0
        ? monthlyExpenseSum / daysElapsed
        : 0.0;

    // Highest Spending Day
    Map<int, double> dailySpending = {};
    for (var t in currentMonthExpenses) {
      final day = t.date.day;
      dailySpending[day] = (dailySpending[day] ?? 0.0) + t.amount;
    }
    int highestSpendDay = 0;
    double highestSpendDayAmt = 0.0;
    dailySpending.forEach((day, amount) {
      if (amount > highestSpendDayAmt) {
        highestSpendDayAmt = amount;
        highestSpendDay = day;
      }
    });

    // Top spending categories list
    final categorySpentMap = financeProvider.monthlyCategorySpent;
    final sortedCategories = categorySpentMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Analytics'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Chart Selector chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildChartChip('Category Spends', 0),
                    _buildChartChip('Income vs Expense', 1),
                    _buildChartChip('Daily Expense Line', 2),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Render active chart
              GlassCard(
                height: 280,
                padding: const EdgeInsets.all(16),
                child: _buildChart(
                  filteredCategories: sortedCategories,
                  totalIncome: totalIncome,
                  totalExpense: totalExpense,
                  currentMonthExpenses: currentMonthExpenses,
                ),
              ),
              const SizedBox(height: 28),

              // General Summary metrics
              const Text(
                'ANALYTICS SUMMARY',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.5,
                children: [
                  _buildSummaryItem(
                    title: 'Avg. Daily Expense',
                    value: CurrencyFormatter.format(avgDailyExpense),
                    accentColor: AppColors.primaryPurple,
                  ),
                  _buildSummaryItem(
                    title: 'Highest Spend Day',
                    value: highestSpendDay > 0
                        ? 'Day $highestSpendDay (${CurrencyFormatter.format(highestSpendDayAmt)})'
                        : 'No Data',
                    accentColor: AppColors.warningOrange,
                  ),
                  _buildSummaryItem(
                    title: 'Largest Transaction',
                    value: largestTransactionVal > 0
                        ? '${CurrencyFormatter.format(largestTransactionVal)}\n($largestTransactionTitle)'
                        : 'No Data',
                    accentColor: AppColors.dangerRed,
                  ),
                  _buildSummaryItem(
                    title: 'Savings Rate',
                    value: '${savingsRate.toStringAsFixed(0)}%',
                    accentColor: AppColors.successGreen,
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Top categories list
              if (sortedCategories.isNotEmpty) ...[
                const Text(
                  'TOP SPENDING CATEGORIES',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 12),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: sortedCategories.length > 5
                      ? 5
                      : sortedCategories.length,
                  itemBuilder: (context, index) {
                    final item = sortedCategories[index];
                    final String cat = item.key;
                    final double amt = item.value;
                    final double pct = totalExpense > 0
                        ? (amt / totalExpense)
                        : 0.0;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: GlassCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '${index + 1}.',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.cyan,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  cat,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  CurrencyFormatter.format(amt),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  '${(pct * 100).toStringAsFixed(0)}% of total spends',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChartChip(String title, int index) {
    final isActive = _activeChartIndex == index;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(title),
        selected: isActive,
        selectedColor: AppColors.primaryPurple,
        backgroundColor: AppColors.cardBackground,
        labelStyle: TextStyle(
          color: isActive ? Colors.white : AppColors.textSecondary,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onSelected: (val) {
          if (val) {
            setState(() {
              _activeChartIndex = index;
            });
          }
        },
      ),
    );
  }

  Widget _buildChart({
    required List<MapEntry<String, double>> filteredCategories,
    required double totalIncome,
    required double totalExpense,
    required List<FinanceTransaction> currentMonthExpenses,
  }) {
    if (_activeChartIndex == 0) {
      // Donut Pie Chart (Category Breakdown)
      if (filteredCategories.isEmpty) {
        return const Center(
          child: Text(
            'No Spends to Graph',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        );
      }

      List<PieChartSectionData> sections = [];
      final List<Color> palette = [
        AppColors.primaryPurple,
        AppColors.cyan,
        AppColors.successGreen,
        AppColors.warningOrange,
        AppColors.dangerRed,
        Colors.blue,
        Colors.indigo,
        Colors.pink,
      ];

      for (int i = 0; i < filteredCategories.length && i < 6; i++) {
        final item = filteredCategories[i];
        sections.add(
          PieChartSectionData(
            value: item.value,
            title: item.key,
            color: palette[i % palette.length],
            radius: 40,
            titleStyle: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        );
      }

      return PieChart(
        PieChartData(
          sections: sections,
          centerSpaceRadius: 50,
          sectionsSpace: 2,
        ),
      );
    } else if (_activeChartIndex == 1) {
      // Income vs Expense Bar Chart
      return BarChart(
        BarChartData(
          barGroups: [
            BarChartGroupData(
              x: 0,
              barRods: [
                BarChartRodData(
                  toY: totalIncome,
                  color: AppColors.successGreen,
                  width: 24,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(6),
                  ),
                ),
              ],
            ),
            BarChartGroupData(
              x: 1,
              barRods: [
                BarChartRodData(
                  toY: totalExpense,
                  color: AppColors.dangerRed,
                  width: 24,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(6),
                  ),
                ),
              ],
            ),
          ],
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  switch (value.toInt()) {
                    case 0:
                      return const Text(
                        'Income',
                        style: TextStyle(color: Colors.white, fontSize: 11),
                      );
                    case 1:
                      return const Text(
                        'Expenses',
                        style: TextStyle(color: Colors.white, fontSize: 11),
                      );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
        ),
      );
    } else {
      // Daily Expense Line Chart
      if (currentMonthExpenses.isEmpty) {
        return const Center(
          child: Text(
            'No daily data',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        );
      }

      // Group by day of month
      Map<int, double> daySummary = {};
      for (var tx in currentMonthExpenses) {
        final day = tx.date.day;
        daySummary[day] = (daySummary[day] ?? 0.0) + tx.amount;
      }

      final sortedDays = daySummary.keys.toList()..sort();
      List<FlSpot> spots = [];
      for (var day in sortedDays) {
        spots.add(FlSpot(day.toDouble(), daySummary[day]!));
      }

      if (spots.isEmpty) spots.add(const FlSpot(0, 0));

      return LineChart(
        LineChartData(
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppColors.cyan,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.cyan.withValues(alpha: 0.15),
              ),
            ),
          ],
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Text(
                    'Day ${value.toInt()}',
                    style: const TextStyle(color: Colors.white60, fontSize: 8),
                  );
                },
              ),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
        ),
      );
    }
  }

  Widget _buildSummaryItem({
    required String title,
    required String value,
    required Color accentColor,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppColors.textSecondary.withValues(alpha: 0.7),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: accentColor,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
