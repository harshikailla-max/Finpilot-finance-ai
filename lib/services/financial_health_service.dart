import '../models/financial_health_model.dart';
import '../models/finance_transaction.dart';
import '../models/goal_model.dart';

class FinancialHealthService {
  static FinancialHealthModel calculateScore({
    required double monthlyIncome,
    required double monthlyExpense,
    required double monthlyBudget,
    required Map<String, double> categorySpent,
    required Map<String, double> categoryLimits,
    required List<GoalModel> goals,
  }) {
    // 1. Savings Rate (25 points)
    // Formula: (Income - Expense) / Income. Goal is >= 30% savings rate for max points.
    double savingsScore = 0.0;
    if (monthlyIncome > 0) {
      final savings = monthlyIncome - monthlyExpense;
      final savingsRate = savings / monthlyIncome;
      if (savingsRate >= 0.30) {
        savingsScore = 25.0;
      } else if (savingsRate > 0) {
        savingsScore = (savingsRate / 0.30) * 25.0;
      }
    }

    // 2. Budget Discipline (25 points)
    // Formula: Based on whether categories exceeded their budget limits.
    // Start with 25 points, deduct 5 points for each category that exceeded budget limit (limit > 0 and spent > limit).
    double budgetScore = 25.0;
    int exceededCount = 0;
    categoryLimits.forEach((category, limit) {
      if (limit > 0) {
        final spent = categorySpent[category] ?? 0.0;
        if (spent > limit) {
          exceededCount++;
        }
      }
    });
    // Deduct 5 points per exceeded limit
    budgetScore = (budgetScore - (exceededCount * 5.0)).clamp(0.0, 25.0);

    // Also deduct if overall budget exceeded
    if (monthlyBudget > 0 && monthlyExpense > monthlyBudget) {
      final excessFactor = (monthlyExpense - monthlyBudget) / monthlyBudget;
      final deduction = excessFactor * 25.0;
      budgetScore = (budgetScore - deduction).clamp(0.0, 25.0);
    }

    // 3. Expense Control (20 points)
    // discretionary spending (Food, Shopping, Entertainment, Travel) relative to income.
    // If discretionary spending is <= 25% of income, full 20 points. Scale down to 0 points at 50% or more.
    double expenseControlScore = 20.0;
    if (monthlyIncome > 0) {
      double discretionarySpend = 0.0;
      final discretionaryCategories = ['Food', 'Shopping', 'Entertainment', 'Travel'];
      for (var cat in discretionaryCategories) {
        discretionarySpend += categorySpent[cat] ?? 0.0;
      }
      final ratio = discretionarySpend / monthlyIncome;
      if (ratio <= 0.25) {
        expenseControlScore = 20.0;
      } else if (ratio >= 0.50) {
        expenseControlScore = 0.0;
      } else {
        expenseControlScore = 20.0 - ((ratio - 0.25) / 0.25) * 20.0;
      }
    } else {
      expenseControlScore = 0.0;
    }

    // 4. Positive Cash Flow (15 points)
    // Formula: Income vs Expense. If Income > Expense, cash flow is positive.
    double cashFlowScore = 0.0;
    if (monthlyIncome > monthlyExpense && monthlyIncome > 0) {
      final surplus = monthlyIncome - monthlyExpense;
      final surplusRatio = surplus / monthlyIncome;
      if (surplusRatio >= 0.20) {
        cashFlowScore = 15.0;
      } else {
        cashFlowScore = (surplusRatio / 0.20) * 15.0;
      }
    } else if (monthlyIncome == monthlyExpense && monthlyIncome > 0) {
      cashFlowScore = 5.0;
    }

    // 5. Goal Progress (15 points)
    // Average progress of active goals. If no goals, default to a neutral/encouraging 5 points.
    double goalScore = 5.0;
    if (goals.isNotEmpty) {
      double totalProgress = 0.0;
      for (var goal in goals) {
        totalProgress += goal.progressPercentage;
      }
      final avgProgress = totalProgress / goals.length;
      goalScore = avgProgress * 15.0;
    }

    return FinancialHealthModel(
      savingsScore: double.parse(savingsScore.toStringAsFixed(1)),
      budgetScore: double.parse(budgetScore.toStringAsFixed(1)),
      expenseControlScore: double.parse(expenseControlScore.toStringAsFixed(1)),
      cashFlowScore: double.parse(cashFlowScore.toStringAsFixed(1)),
      goalScore: double.parse(goalScore.toStringAsFixed(1)),
    );
  }
}
