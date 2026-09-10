import '../models/future_simulation_model.dart';

class FuturePredictionService {
  static List<SimulationPoint> runSimulation({
    required double currentSavings,
    required double monthlyIncome,
    required double monthlyExpenses,
    required double incomeGrowth, // Annual percentage (e.g. 10.0 for 10%)
    required double expenseGrowth, // Annual percentage
    required int durationMonths,
    required String scenarioMode,
  }) {
    List<SimulationPoint> points = [];
    double runningSavings = currentSavings;
    double currentIncome = monthlyIncome;
    double currentExpenses = monthlyExpenses;

    // Adjust growth factors based on scenario
    double adjustedIncomeGrowth = incomeGrowth;
    double adjustedExpenseGrowth = expenseGrowth;

    if (scenarioMode == 'Conservative') {
      adjustedIncomeGrowth = (incomeGrowth - 2.0).clamp(0.0, 100.0);
      adjustedExpenseGrowth = (expenseGrowth + 2.0).clamp(0.0, 100.0);
    } else if (scenarioMode == 'Aggressive') {
      adjustedIncomeGrowth = (incomeGrowth + 2.0).clamp(0.0, 100.0);
      adjustedExpenseGrowth = (expenseGrowth - 2.0).clamp(0.0, 100.0);
    }

    // Monthly compounding growth rates
    final double monthlyIncomeRate = (adjustedIncomeGrowth / 100) / 12;
    final double monthlyExpenseRate = (adjustedExpenseGrowth / 100) / 12;

    // Month 0 (current position)
    points.add(SimulationPoint(month: 0, balance: runningSavings));

    for (int month = 1; month <= durationMonths; month++) {
      // Apply monthly growth (compounded)
      currentIncome *= (1 + monthlyIncomeRate);
      currentExpenses *= (1 + monthlyExpenseRate);

      final double monthlySavings = currentIncome - currentExpenses;
      runningSavings += monthlySavings;

      points.add(SimulationPoint(
        month: month,
        balance: double.parse(runningSavings.toStringAsFixed(0)),
      ));
    }

    return points;
  }

  static String generateAIPrediction({
    required double currentSavings,
    required double monthlyIncome,
    required double monthlyExpenses,
    required double targetGoalAmount,
  }) {
    final monthlySavings = monthlyIncome - monthlyExpenses;
    if (monthlySavings <= 0) {
      return "Your expenses are equal to or exceed your income. Reducing expenses by ₹3,000 could create a savings buffer and help you build an emergency fund.";
    }

    final remaining = targetGoalAmount - currentSavings;
    if (remaining <= 0) {
      return "Congratulations! You have already met this target amount.";
    }

    final currentMonths = remaining / monthlySavings;
    final double optimizedSavings = monthlySavings + 3000.0;
    final optimizedMonths = remaining / optimizedSavings;
    final monthsSaved = (currentMonths - optimizedMonths).round();

    if (monthsSaved > 0) {
      return "If you reduce monthly expenses by ₹3,000, you could reach your goal approximately $monthsSaved months earlier.";
    } else {
      return "Setting aside ₹3,000 more each month will accelerate your timeline towards your target savings.";
    }
  }
}
