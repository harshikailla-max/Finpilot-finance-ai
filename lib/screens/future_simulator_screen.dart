import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import '../providers/finance_provider.dart';
import '../providers/investment_provider.dart';
import '../services/future_prediction_service.dart';
import '../utils/constants.dart';
import '../utils/currency_formatter.dart';
import '../widgets/glass_card.dart';

class FutureSimulatorScreen extends StatefulWidget {
  const FutureSimulatorScreen({super.key});

  @override
  State<FutureSimulatorScreen> createState() => _FutureSimulatorScreenState();
}

class _FutureSimulatorScreenState extends State<FutureSimulatorScreen> {
  final _incomeController = TextEditingController();
  final _expenseController = TextEditingController();
  final _incomeGrowthController = TextEditingController(
    text: '8',
  ); // 8% expected annual growth
  final _expenseGrowthController = TextEditingController(
    text: '5',
  ); // 5% expected inflation/growth

  int _selectedDurationMonths = 12; // 6, 12 (1 Yr), 36 (3 Yrs), 60 (5 Yrs)
  String _selectedScenario = 'Balanced'; // Conservative, Balanced, Aggressive

  @override
  void initState() {
    super.initState();
    // Pre-fill fields with current numbers from FinanceProvider
    final finance = context.read<FinanceProvider>();
    _incomeController.text = finance.monthlyIncome.toStringAsFixed(0);
    _expenseController.text = finance.monthlyExpense.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _incomeController.dispose();
    _expenseController.dispose();
    _incomeGrowthController.dispose();
    _expenseGrowthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final financeProvider = context.watch<FinanceProvider>();
    final investmentProvider = context.watch<InvestmentProvider>();

    final double currentSavings =
        financeProvider.balance + investmentProvider.totalCurrentValue;

    // Get input numbers
    final double inputIncome = double.tryParse(_incomeController.text) ?? 0.0;
    final double inputExpense = double.tryParse(_expenseController.text) ?? 0.0;
    final double inputIncomeGrowth =
        double.tryParse(_incomeGrowthController.text) ?? 0.0;
    final double inputExpenseGrowth =
        double.tryParse(_expenseGrowthController.text) ?? 0.0;

    // Run simulation points
    final simulationPoints = FuturePredictionService.runSimulation(
      currentSavings: currentSavings,
      monthlyIncome: inputIncome,
      monthlyExpenses: inputExpense,
      incomeGrowth: inputIncomeGrowth,
      expenseGrowth: inputExpenseGrowth,
      durationMonths: _selectedDurationMonths,
      scenarioMode: _selectedScenario,
    );

    final finalProjectedSavings = simulationPoints.last.balance;
    final double totalGrowthAmt = finalProjectedSavings - currentSavings;
    final double totalGrowthPct = currentSavings > 0
        ? (totalGrowthAmt / currentSavings) * 100
        : 0.0;

    // AI Prediction sentence
    final aiPrediction = FuturePredictionService.generateAIPrediction(
      currentSavings: currentSavings,
      monthlyIncome: inputIncome,
      monthlyExpenses: inputExpense,
      targetGoalAmount: finalProjectedSavings * 1.3,
    );

    // Convert simulation points to fl_chart spots
    List<FlSpot> spots = [];
    for (var pt in simulationPoints) {
      spots.add(FlSpot(pt.month.toDouble(), pt.balance));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Future Savings Simulator'),
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
              // Grid Input Fields inside GlassCard
              GlassCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildInputField(
                            label: 'Monthly Income',
                            controller: _incomeController,
                            icon: Icons.trending_up_rounded,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildInputField(
                            label: 'Monthly Expenses',
                            controller: _expenseController,
                            icon: Icons.trending_down_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInputField(
                            label: 'Annual Income Growth (%)',
                            controller: _incomeGrowthController,
                            icon: Icons.arrow_upward_rounded,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildInputField(
                            label: 'Annual Expense Growth (%)',
                            controller: _expenseGrowthController,
                            icon: Icons.auto_graph,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Duration and Scenario select
              Row(
                children: [
                  // Duration Dropdown
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SIMULATION TIMELINE',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<int>(
                          initialValue: _selectedDurationMonths,
                          dropdownColor: AppColors.cardBackground,
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(value: 6, child: Text('6 Months')),
                            DropdownMenuItem(value: 12, child: Text('1 Year')),
                            DropdownMenuItem(value: 36, child: Text('3 Years')),
                            DropdownMenuItem(value: 60, child: Text('5 Years')),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _selectedDurationMonths = val!;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Scenario Dropdown
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SCENARIO MODE',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedScenario,
                          dropdownColor: AppColors.cardBackground,
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Conservative',
                              child: Text('Conservative'),
                            ),
                            DropdownMenuItem(
                              value: 'Balanced',
                              child: Text('Balanced'),
                            ),
                            DropdownMenuItem(
                              value: 'Aggressive',
                              child: Text('Aggressive'),
                            ),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _selectedScenario = val!;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // PROJECTIONS SUMMARY DISPLAY
              Row(
                children: [
                  // Current
                  Expanded(
                    child: GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'CURRENT NET WORTH',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            CurrencyFormatter.format(currentSavings),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Projected
                  Expanded(
                    child: GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PROJECTED FUTURE',
                            style: TextStyle(
                              color: _getScenarioColor(_selectedScenario),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            CurrencyFormatter.format(finalProjectedSavings),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '+${totalGrowthPct.toStringAsFixed(0)}% Growth',
                            style: const TextStyle(
                              color: AppColors.successGreen,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // line chart of growth
              const Text(
                'PROJECTED SAVINGS GRAPH',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),
              GlassCard(
                height: 220,
                padding: const EdgeInsets.only(
                  top: 24,
                  bottom: 8,
                  right: 16,
                  left: 16,
                ),
                child: LineChart(
                  LineChartData(
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: _getScenarioColor(_selectedScenario),
                        barWidth: 3.5,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: _getScenarioColor(_selectedScenario)
                              .withValues(alpha: 0.15),
                        ),
                      ),
                    ],
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      show: true,
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            if (value.toInt() == 0 ||
                                value.toInt() == _selectedDurationMonths) {
                              return Text(
                                'Month ${value.toInt()}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 9,
                                ),
                              );
                            }
                            return const Text('');
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // AI Advice Card
              Container(
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
                        Icon(
                          Icons.auto_awesome_rounded,
                          color: AppColors.cyan,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'FINPILOT SIMULATOR PREDICTION',
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
                    Text(
                      aiPrediction,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppColors.textMuted, size: 16),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onChanged: (val) {
            setState(() {});
          },
        ),
      ],
    );
  }

  Color _getScenarioColor(String mode) {
    if (mode == 'Conservative') return AppColors.warningOrange;
    if (mode == 'Aggressive') return AppColors.successGreen;
    return AppColors.cyan;
  }
}
