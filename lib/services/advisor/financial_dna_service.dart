import '../../models/advisor_models.dart';
import '../../providers/finance_provider.dart';
import '../../providers/goal_provider.dart';
import '../../providers/investment_provider.dart';
import '../../utils/currency_formatter.dart';

class FinancialDNAService {
  static FinancialDNAProfile evaluateDNA({
    required FinanceProvider finance,
    required GoalProvider goals,
    required InvestmentProvider investments,
  }) {
    final double income = finance.monthlyIncome > 0
        ? finance.monthlyIncome
        : 65000.0;
    final double expense = finance.monthlyExpense;
    final double savingsRate = income > 0
        ? ((income - expense) / income * 100)
        : 0.0;

    final foodSpend = finance.monthlyCategorySpent['Food'] ?? 0.0;
    final shoppingSpend = finance.monthlyCategorySpent['Shopping'] ?? 0.0;
    final entertainmentSpend =
        finance.monthlyCategorySpent['Entertainment'] ?? 0.0;
    final double discretionaryTotal =
        foodSpend + shoppingSpend + entertainmentSpend;
    final double discretionaryRatio = expense > 0
        ? (discretionaryTotal / expense)
        : 0.2;

    final int goalsCount = goals.goals.length;
    final double totalInvested = investments.totalCurrentValue;

    final evidence = <String>[];
    String archetype = 'Planner';
    String secondaryArchetype = 'Saver';
    double disciplineScore = 78.0;
    String coreTrait = 'Methodical capital allocator';
    String growthOpportunity =
        'Scale automated SIP allocations to match monthly surplus';

    // Build evidence from real data
    if (savingsRate >= 25.0) {
      evidence.add(
        'Strong savings rate of ${savingsRate.toStringAsFixed(0)}% (exceeds 20% benchmark).',
      );
    } else {
      evidence.add(
        'Current savings rate is ${savingsRate.toStringAsFixed(0)}% of monthly earnings.',
      );
    }

    if (discretionaryTotal > 0) {
      evidence.add(
        'Discretionary spending (Dining, Shopping, Entertainment) is ${CurrencyFormatter.format(discretionaryTotal)} (${(discretionaryRatio * 100).toStringAsFixed(0)}% of expenses).',
      );
    }

    if (goalsCount > 0) {
      evidence.add(
        '$goalsCount structured financial goals actively tracked in roadmap.',
      );
    } else {
      evidence.add('Milestone roadmap is unconfigured.');
    }

    if (totalInvested > 0) {
      evidence.add(
        '${CurrencyFormatter.format(totalInvested)} actively invested in wealth-building assets.',
      );
    }

    // Determine Archetype
    if (totalInvested > income * 2 && savingsRate >= 20) {
      archetype = 'Investor';
      secondaryArchetype = 'Planner';
      disciplineScore = 88.0;
      coreTrait = 'Long-term equity & compound growth mindset';
      growthOpportunity =
          'Rebalance asset classes annually to manage downside volatility';
    } else if (goalsCount >= 2 && discretionaryRatio <= 0.35) {
      archetype = 'Planner';
      secondaryArchetype = savingsRate >= 25 ? 'Saver' : 'Investor';
      disciplineScore = 85.0;
      coreTrait = 'Organized, milestone-driven, and forward-looking';
      growthOpportunity = 'Shift excess idle savings from cash accounts into index/mutual funds';
    } else if (savingsRate >= 30 && discretionaryRatio <= 0.25) {
      archetype = 'Saver';
      secondaryArchetype = 'Planner';
      disciplineScore = 82.0;
      coreTrait = 'Highly disciplined guardian of liquid capital';
      growthOpportunity = 'Avoid holding excessive cash against inflation; deploy into growth assets';
    } else if (discretionaryRatio >= 0.45) {
      archetype = 'Spender';
      secondaryArchetype = 'Risk Taker';
      disciplineScore = 55.0;
      coreTrait = 'Lifestyle-oriented, high discretionary consumption';
      growthOpportunity = 'Establish automated transfer to savings on salary credit day before spending';
    } else {
      archetype = 'Emerging Planner';
      secondaryArchetype = 'Saver';
      disciplineScore = 70.0;
      coreTrait = 'Building steady financial habits and consistent reserves';
      growthOpportunity = 'Set a dedicated 3-month emergency fund milestone';
    }

    return FinancialDNAProfile(
      archetype: archetype,
      secondaryArchetype: secondaryArchetype,
      financialDisciplineScore: disciplineScore,
      evidencePoints: evidence,
      coreTrait: coreTrait,
      growthOpportunity: growthOpportunity,
    );
  }
}
