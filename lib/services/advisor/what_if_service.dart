import '../../models/advisor_models.dart';
import '../../providers/finance_provider.dart';
import '../../utils/currency_formatter.dart';

class WhatIfService {
  static WhatIfScenarioResult simulateScenario({
    required FinanceProvider finance,
    double incomeDelta = 0.0,
    double expenseDelta = 0.0,
    double newRecurringEmi = 0.0,
    double oneTimeCost = 0.0,
    String? scenarioDescription,
  }) {
    final double currentIncome = finance.monthlyIncome > 0
        ? finance.monthlyIncome
        : 65000.0;
    final double currentExpense = finance.monthlyExpense;
    final double baselineSurplus = currentIncome - currentExpense;
    final double baselineSavingsRate = currentIncome > 0
        ? (baselineSurplus / currentIncome * 100)
        : 0.0;

    final double projectedIncome = currentIncome + incomeDelta;
    final double projectedExpense =
        currentExpense + expenseDelta + newRecurringEmi;
    final double projectedSurplus = projectedIncome - projectedExpense;
    final double projectedSavingsRate = projectedIncome > 0
        ? (projectedSurplus / projectedIncome * 100)
        : 0.0;
    final double monthlyDelta = projectedSurplus - baselineSurplus;

    final double liquidCash = finance.balance > 0
        ? finance.balance
        : (baselineSurplus * 3.0);
    final double projectedLiquid = (liquidCash - oneTimeCost).clamp(
      0.0,
      100000000.0,
    );
    final double projectedRunwayMonths = projectedExpense > 0
        ? (projectedLiquid / projectedExpense)
        : 0.0;

    String title = scenarioDescription ?? 'Custom Financial Scenario';
    if (scenarioDescription == null) {
      if (incomeDelta > 0) {
        title = 'Income Hike (+${CurrencyFormatter.format(incomeDelta)})';
      } else if (expenseDelta < 0) {
        title = 'Expense Cut (${CurrencyFormatter.format(-expenseDelta)})';
      } else if (newRecurringEmi > 0) {
        title =
            'New Loan / EMI (${CurrencyFormatter.format(newRecurringEmi)}/mo)';
      } else if (oneTimeCost > 0) {
        title = 'One-Time Purchase (${CurrencyFormatter.format(oneTimeCost)})';
      }
    }

    String goalSummary;
    if (monthlyDelta > 0) {
      final annualExtra = monthlyDelta * 12;
      goalSummary =
          'Accelerates long-term savings by ${CurrencyFormatter.format(annualExtra)} annually. Could fund major goals up to 30% faster.';
    } else if (monthlyDelta < 0) {
      final annualLost = (-monthlyDelta) * 12;
      goalSummary =
          'Reduces annual savings by ${CurrencyFormatter.format(annualLost)}. Goal timelines will extend by 2-5 months.';
    } else {
      goalSummary = 'Net monthly cash flow remains neutral.';
    }

    String runwaySummary =
        'Projected liquid safety runway: ${projectedRunwayMonths.toStringAsFixed(1)} months of living expenses.';

    String insight;
    if (projectedSavingsRate >= 30) {
      insight =
          'Pinnacle wealth creation zone. At a ${projectedSavingsRate.toStringAsFixed(0)}% savings rate, financial independence velocity accelerates dramatically.';
    } else if (projectedSavingsRate >= 20) {
      insight = 'Healthy sustainable trajectory. Retains strong operating safety margins.';
    } else if (projectedSavingsRate > 0) {
      insight = 'Positive surplus, but thin capital reserves. Keep close control on discretionary creep.';
    } else {
      insight = 'Deficit scenario warning! Monthly outflows exceed inflows. Counterbalance with targeted budget adjustments.';
    }

    return WhatIfScenarioResult(
      scenarioTitle: title,
      baselineMonthlySavings: baselineSurplus,
      projectedMonthlySavings: projectedSurplus,
      monthlyDelta: monthlyDelta,
      baselineSavingsRate: double.parse(baselineSavingsRate.toStringAsFixed(1)),
      projectedSavingsRate: double.parse(
        projectedSavingsRate.toStringAsFixed(1),
      ),
      goalImpactSummary: goalSummary,
      safetyRunwaySummary: runwaySummary,
      strategicInsight: insight,
    );
  }
}
