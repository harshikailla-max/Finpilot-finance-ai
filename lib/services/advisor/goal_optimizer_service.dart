import '../../models/advisor_models.dart';
import '../../models/goal_model.dart';
import '../../providers/finance_provider.dart';
import '../../providers/goal_provider.dart';
import '../../utils/currency_formatter.dart';

class GoalOptimizerService {
  static GoalOptimizationResult optimizeGoals({
    required GoalProvider goalProvider,
    required FinanceProvider finance,
  }) {
    final List<GoalModel> rawGoals = goalProvider.goals;
    final double income = finance.monthlyIncome > 0
        ? finance.monthlyIncome
        : 65000.0;
    final double expense = finance.monthlyExpense;
    final double availableMonthlySurplus = (income - expense).clamp(
      0.0,
      500000.0,
    );

    if (rawGoals.isEmpty) {
      return const GoalOptimizationResult(
        rankedGoals: [],
        bestNextGoalTitle: 'Emergency Fund',
        bestNextGoalReason: 'No active goals exist. Creating a 3-month emergency fund is the foundational cornerstone of financial freedom.',
        totalMonthlyRequired: 0,
        availableMonthlySurplus: 0,
        monthlyDeficitOrSurplus: 0,
        strategicAdvice:
            'Navigate to Goals and add your first target milestone.',
      );
    }

    final rankedItems = <GoalRankItem>[];
    double totalMonthlyRequired = 0.0;

    for (int i = 0; i < rawGoals.length; i++) {
      final g = rawGoals[i];
      final gap = (g.targetAmount - g.currentAmount).clamp(0.0, g.targetAmount);
      final monthly = g.monthlyAmountRequired;
      totalMonthlyRequired += monthly;

      // Priority ranking score based on deadline proximity and category type
      int priorityRank = 3;
      String reason = 'Standard milestone allocation.';

      if (g.category.toLowerCase().contains('emergency') ||
          g.title.toLowerCase().contains('emergency')) {
        priorityRank = 1;
        reason = 'Highest financial security priority (defensive moat).';
      } else if (g.deadline.difference(DateTime.now()).inDays < 180) {
        priorityRank = 2;
        reason = 'Imminent deadline within 6 months.';
      } else if ((g.progressPercentage * 100) >= 75) {
        priorityRank = 2;
        reason = 'Over 75% funded; close to final completion.';
      }

      rankedItems.add(
        GoalRankItem(
          goalId: g.id,
          title: g.title,
          targetAmount: g.targetAmount,
          currentAmount: g.currentAmount,
          monthlyRequired: monthly,
          fundingGap: gap,
          priorityRank: priorityRank,
          isConflict: false,
          reason: reason,
        ),
      );
    }

    // Sort by priority rank ascending (1 is highest), then by funding gap
    rankedItems.sort((a, b) {
      final rankComp = a.priorityRank.compareTo(b.priorityRank);
      if (rankComp != 0) return rankComp;
      return a.monthlyRequired.compareTo(b.monthlyRequired);
    });

    // Check for funding conflict
    final double monthlyDeficitOrSurplus =
        availableMonthlySurplus - totalMonthlyRequired;
    final bool hasConflict = monthlyDeficitOrSurplus < 0;

    if (hasConflict) {
      double runningSum = 0.0;
      for (final item in rankedItems) {
        runningSum += item.monthlyRequired;
        if (runningSum > availableMonthlySurplus) {
          // This goal conflicts with surplus
          // We mark it in advice
        }
      }
    }

    final bestNext = rankedItems.first;
    String advice;
    if (hasConflict) {
      advice =
          'Your active goals require ${CurrencyFormatter.format(totalMonthlyRequired)}/mo, exceeding your current surplus of ${CurrencyFormatter.format(availableMonthlySurplus)}/mo by ${CurrencyFormatter.format(-monthlyDeficitOrSurplus)}. Focus 70% of surplus on "${bestNext.title}" first to avoid spreading capital too thin.';
    } else {
      advice =
          'Your available monthly surplus of ${CurrencyFormatter.format(availableMonthlySurplus)} comfortably covers all goal run-rates (${CurrencyFormatter.format(totalMonthlyRequired)}/mo) with ${CurrencyFormatter.format(monthlyDeficitOrSurplus)} extra buffer for accelerated investing.';
    }

    return GoalOptimizationResult(
      rankedGoals: rankedItems,
      bestNextGoalTitle: bestNext.title,
      bestNextGoalReason: 'Highest priority allocation: ${bestNext.reason}',
      totalMonthlyRequired: totalMonthlyRequired,
      availableMonthlySurplus: availableMonthlySurplus,
      monthlyDeficitOrSurplus: monthlyDeficitOrSurplus,
      strategicAdvice: advice,
    );
  }
}
