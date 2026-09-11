import '../../models/advisor_models.dart';
import '../../providers/finance_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/goal_provider.dart';
import '../../providers/investment_provider.dart';
import '../../utils/currency_formatter.dart';

class ProactiveMoneyMovesService {
  static List<MoneyMove> generateTodayMoves({
    required FinanceProvider finance,
    required BudgetProvider budget,
    required GoalProvider goals,
    required InvestmentProvider investments,
  }) {
    final moves = <MoneyMove>[];

    final double income = finance.monthlyIncome > 0 ? finance.monthlyIncome : 65000.0;
    final double expense = finance.monthlyExpense;
    final double surplus = income - expense;
    final double liquidBalance = finance.balance > 0 ? finance.balance : (surplus * 2.5);
    final double monthlyBurn = expense > 0 ? expense : (income * 0.7);
    final double emergencyMonths = monthlyBurn > 0 ? (liquidBalance / monthlyBurn) : 2.0;

    // 1. Emergency Fund Move
    if (emergencyMonths < 3.0) {
      final double targetFund = monthlyBurn * 3.0;
      final double shortfall = (targetFund - liquidBalance).clamp(0.0, 5000000.0);
      moves.add(
        MoneyMove(
          id: 'move_emergency_fund',
          title: 'Strengthen Emergency Moat',
          category: 'Safety',
          reason: 'Your liquid reserves cover only ${emergencyMonths.toStringAsFixed(1)} months of living costs. Recommended minimum is 3 to 6 months.',
          impact: 'Build ${CurrencyFormatter.format(shortfall)} reserve buffer',
          actionLabel: 'Setup Emergency Goal',
          actionRoute: 'goals',
        ),
      );
    }

    // 2. Discretionary Spending / Dining Move
    final double diningSpend = finance.monthlyCategorySpent['Food'] ?? 0.0;
    if (diningSpend > 3000) {
      final double savingsPotential = diningSpend * 0.20;
      moves.add(
        MoneyMove(
          id: 'move_dining_optimization',
          title: 'Trim Food & Dining Delivery',
          category: 'Expenses',
          reason: 'Dining expenses reached ${CurrencyFormatter.format(diningSpend)} this month. A 20% cap redirects ${CurrencyFormatter.format(savingsPotential)} straight to your savings.',
          impact: '+${CurrencyFormatter.format(savingsPotential)} monthly savings',
          actionLabel: 'Review Dining Budget',
          actionRoute: 'budget',
        ),
      );
    }

    // 3. Goal Pacing & Allocation Move
    if (goals.goals.isNotEmpty && surplus > 5000) {
      final unallocatedSurplus = (surplus * 0.4).roundToDouble();
      final topGoal = goals.goals.first;
      moves.add(
        MoneyMove(
          id: 'move_accelerate_goal',
          title: 'Accelerate "${topGoal.title}"',
          category: 'Goals',
          reason: 'You have an unallocated monthly surplus of ${CurrencyFormatter.format(surplus)}. Channeling ${CurrencyFormatter.format(unallocatedSurplus)}/month completes this milestone faster.',
          impact: 'Shorten target date by ~2 months',
          actionLabel: 'Add Funds to Goal',
          actionRoute: 'goals',
        ),
      );
    }

    // 4. Investment Deployment Move
    if (surplus > 10000 && investments.investments.isNotEmpty) {
      final sipRecommendation = (surplus * 0.35).roundToDouble();
      moves.add(
        MoneyMove(
          id: 'move_scale_investments',
          title: 'Scale Automated Monthly SIP',
          category: 'Wealth',
          reason: 'Your consistent monthly surplus can support an additional ${CurrencyFormatter.format(sipRecommendation)}/month index or mutual fund allocation.',
          impact: 'Builds ~${CurrencyFormatter.format(sipRecommendation * 12 * 1.12)} over 1 year',
          actionLabel: 'Open Investment Desk',
          actionRoute: 'investments',
        ),
      );
    }

    // 5. Default Fallback Move if list is small
    if (moves.length < 3) {
      moves.add(
        const MoneyMove(
          id: 'move_50_30_20_rule',
          title: 'Apply 50/30/20 Balance',
          category: 'Strategy',
          reason: 'Ensure 50% of income funds Needs, 30% funds Wants, and 20% is locked into Investments & Wealth Creation.',
          impact: 'Disciplined compounding velocity',
          actionLabel: 'Review Cash Flow',
          actionRoute: 'analytics',
        ),
      );
    }

    return moves.take(4).toList();
  }
}
