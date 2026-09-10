import 'package:flutter/material.dart';
import '../models/financial_health_model.dart';
import '../services/financial_health_service.dart';
import 'finance_provider.dart';
import 'budget_provider.dart';
import 'goal_provider.dart';

class FinancialHealthProvider extends ChangeNotifier {
  final FinanceProvider financeProvider;
  final BudgetProvider budgetProvider;
  final GoalProvider goalProvider;

  FinancialHealthProvider({
    required this.financeProvider,
    required this.budgetProvider,
    required this.goalProvider,
  }) {
    financeProvider.addListener(_onDependencyChanged);
    budgetProvider.addListener(_onDependencyChanged);
    goalProvider.addListener(_onDependencyChanged);
  }

  void _onDependencyChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    financeProvider.removeListener(_onDependencyChanged);
    budgetProvider.removeListener(_onDependencyChanged);
    goalProvider.removeListener(_onDependencyChanged);
    super.dispose();
  }

  FinancialHealthModel get healthData {
    return FinancialHealthService.calculateScore(
      monthlyIncome: financeProvider.monthlyIncome,
      monthlyExpense: financeProvider.monthlyExpense,
      monthlyBudget: budgetProvider.monthlyBudget,
      categorySpent: financeProvider.monthlyCategorySpent,
      categoryLimits: budgetProvider.categoryBudgets,
      goals: goalProvider.goals,
    );
  }

  double get healthScore => healthData.totalScore;
  double get savingsScore => healthData.savingsScore;
  double get budgetScore => healthData.budgetScore;
  double get expenseControlScore => healthData.expenseControlScore;
  double get cashFlowScore => healthData.cashFlowScore;
  double get goalScore => healthData.goalScore;
}
