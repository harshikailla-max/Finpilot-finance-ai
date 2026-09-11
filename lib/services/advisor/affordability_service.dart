import '../../models/advisor_models.dart';
import '../../providers/finance_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/goal_provider.dart';
import '../../utils/currency_formatter.dart';

class AffordabilityService {
  static AffordabilityAnalysis evaluatePurchase({
    required String product,
    required double price,
    String? timeframe,
    required FinanceProvider finance,
    required BudgetProvider budget,
    required GoalProvider goals,
  }) {
    final double income = finance.monthlyIncome > 0 ? finance.monthlyIncome : 65000.0;
    final double expense = finance.monthlyExpense;
    final double monthlySurplus = income - expense;
    final double liquidBalance = finance.balance > 0 ? finance.balance : (monthlySurplus * 3.0);
    final double monthlyBurn = expense > 0 ? expense : (income * 0.65);

    // Current emergency fund runway in months
    final double currentRunwayMonths = monthlyBurn > 0 ? (liquidBalance / monthlyBurn) : 3.0;

    // Remaining runway if paid in cash today
    final double remainingLiquid = liquidBalance - price;
    final double remainingRunwayMonths = monthlyBurn > 0 ? (remainingLiquid / monthlyBurn) : 0.0;
    final double runwayImpact = currentRunwayMonths - remainingRunwayMonths;

    // Budget impact percentage
    final double monthlyBudgetLimit = budget.monthlyBudget > 0 ? budget.monthlyBudget : income;
    final double budgetImpactPercentage = (price / monthlyBudgetLimit) * 100;

    // Required monthly savings if deferred
    int targetMonths = 1;
    if (timeframe != null) {
      if (timeframe.contains('year')) targetMonths = 12;
      if (timeframe.contains('6 month')) targetMonths = 6;
      if (timeframe.contains('3 month')) targetMonths = 3;
    }
    final double monthlyPacingCost = price / targetMonths;

    // Active goal impact evaluation
    final int activeGoalsCount = goals.goals.length;
    String goalImpactSummary;
    if (activeGoalsCount > 0) {
      if (remainingLiquid < 20000) {
        goalImpactSummary = 'May delay progress on active savings targets by 2-3 months.';
      } else {
        goalImpactSummary = 'Compatible with existing milestones without delaying deadlines.';
      }
    } else {
      goalImpactSummary = 'No active target conflicts detected.';
    }

    // Affordability Scoring algorithm (0 to 100)
    double score = 100.0;

    // 1. Price vs Monthly Surplus
    if (monthlySurplus <= 0) {
      score -= 40;
    } else if (price > monthlySurplus * 4) {
      score -= 30;
    } else if (price > monthlySurplus * 2) {
      score -= 15;
    }

    // 2. Impact on Emergency Fund (Must keep at least 3 months liquid)
    if (remainingRunwayMonths < 1.0) {
      score -= 45;
    } else if (remainingRunwayMonths < 3.0) {
      score -= 25;
    } else if (remainingRunwayMonths < 6.0) {
      score -= 10;
    }

    // 3. Size of purchase vs Income
    if (price > income * 2) {
      score -= 20;
    } else if (price > income * 0.8) {
      score -= 10;
    }

    score = score.clamp(5.0, 100.0);

    // Determine Verdict
    DecisionVerdict verdict;
    String reasoning;
    String alternative;
    String recommendedAction;

    if (score >= 85) {
      verdict = DecisionVerdict.safe;
      reasoning = 'Your liquid reserves will comfortably maintain ${remainingRunwayMonths.toStringAsFixed(1)} months of runway post-purchase, and your monthly surplus covers this with ease.';
      alternative = 'Direct purchase is fully viable. Consider using a cashback or rewards card with immediate full balance payoff.';
      recommendedAction = 'Safe to proceed with immediate purchase.';
    } else if (score >= 70) {
      verdict = DecisionVerdict.good;
      reasoning = 'The purchase represents ${budgetImpactPercentage.toStringAsFixed(0)}% of your monthly budget capacity. Liquid reserves stay above safety thresholds.';
      alternative = 'If you wish to optimize, stagger payments across 2 months at ${CurrencyFormatter.format(price / 2)}/month.';
      recommendedAction = 'Approved with moderate pacing.';
    } else if (score >= 50) {
      verdict = DecisionVerdict.possible;
      reasoning = 'You have sufficient funds, but this purchase draws your emergency runway down to ${remainingRunwayMonths.toStringAsFixed(1)} months, which is tight.';
      alternative = 'Save ${CurrencyFormatter.format(monthlyPacingCost)}/month over ${targetMonths > 1 ? targetMonths : 3} months to purchase without touching your baseline safety buffer.';
      recommendedAction = 'Feasible, but funding via short-term savings target recommended.';
    } else if (score >= 35) {
      verdict = DecisionVerdict.tight;
      reasoning = 'This expense absorbs significant liquidity, leaving less than ${(remainingRunwayMonths).clamp(0.1, 10.0).toStringAsFixed(1)} months of emergency buffer. High vulnerability if unplanned expenses occur.';
      alternative = 'Defer for 90 days while directing discretionary budget cuts (${CurrencyFormatter.format(price / 3)}/mo) into a dedicated sinking fund.';
      recommendedAction = 'Wait and save first.';
    } else {
      verdict = DecisionVerdict.notRecommended;
      reasoning = 'Outflow exceeds safe liquidity parameters and poses immediate cash flow and safety risks (${remainingLiquid <= 0 ? 'Exceeds total liquid assets' : 'Depletes defensive emergency reserves'}).';
      alternative = 'Re-evaluate necessity, explore lower-tier alternatives, or set a dedicated 6-12 month savings milestone.';
      recommendedAction = 'Not recommended at current liquidity levels.';
    }

    return AffordabilityAnalysis(
      product: product.isNotEmpty ? product : 'Selected Purchase',
      price: price,
      verdict: verdict,
      affordabilityScore: double.parse(score.toStringAsFixed(1)),
      monthlyImpact: monthlyPacingCost,
      budgetImpactPercentage: double.parse(budgetImpactPercentage.toStringAsFixed(1)),
      emergencyFundImpactMonths: double.parse(runwayImpact.toStringAsFixed(1)),
      remainingEmergencyMonths: double.parse(remainingRunwayMonths.toStringAsFixed(1)),
      goalImpact: goalImpactSummary,
      reasoning: reasoning,
      alternative: alternative,
      recommendedAction: recommendedAction,
    );
  }
}
