import 'package:flutter_test/flutter_test.dart';
import 'package:finpilot_ai/services/category_service.dart';
import 'package:finpilot_ai/services/financial_health_service.dart';
import 'package:finpilot_ai/services/future_prediction_service.dart';
import 'package:finpilot_ai/utils/currency_formatter.dart';
import 'package:finpilot_ai/models/goal_model.dart';

void main() {
  group('CategoryService Tests', () {
    test('Detects expense categories accurately', () {
      expect(CategoryService.detectExpenseCategory('Swiggy Order'), 'Food');
      expect(CategoryService.detectExpenseCategory('Uber Ride to Office'), 'Transport');
      expect(CategoryService.detectExpenseCategory('Amazon Prime Video'), 'Entertainment');
      expect(CategoryService.detectExpenseCategory('Amazon Shopping T-Shirt'), 'Shopping');
      expect(CategoryService.detectExpenseCategory('Electricity Bill for August'), 'Bills');
      expect(CategoryService.detectExpenseCategory('Pharmacy Medicines'), 'Health');
      expect(CategoryService.detectExpenseCategory('Udemy Python Course'), 'Education');
      expect(CategoryService.detectExpenseCategory('Hotel Booking in Goa'), 'Travel');
    });

    test('Detects income categories accurately', () {
      expect(CategoryService.detectIncomeCategory('Monthly Salary'), 'Salary');
      expect(CategoryService.detectIncomeCategory('Freelance Web Design'), 'Freelance');
      expect(CategoryService.detectIncomeCategory('Stock Dividend Payout'), 'Investment');
      expect(CategoryService.detectIncomeCategory('Annual Performance Bonus'), 'Bonus');
    });
  });

  group('CurrencyFormatter Tests', () {
    test('Formats rupees without decimals when integer', () {
      expect(CurrencyFormatter.format(65000), '₹65,000');
      expect(CurrencyFormatter.format(450), '₹450');
    });

    test('Formats rupees with decimals when fractional', () {
      expect(CurrencyFormatter.format(650.50), '₹650.50');
    });
  });

  group('FinancialHealthService Tests', () {
    test('Calculates excellent health score for disciplined finances', () {
      final health = FinancialHealthService.calculateScore(
        monthlyIncome: 65000,
        monthlyExpense: 24000,
        monthlyBudget: 30000,
        categorySpent: {'Food': 4000, 'Transport': 2000, 'Bills': 3000},
        categoryLimits: {'Food': 6000, 'Transport': 3000, 'Bills': 5000},
        goals: [
          GoalModel(
            id: '1',
            title: 'Laptop',
            targetAmount: 80000,
            currentAmount: 40000,
            deadline: DateTime.now().add(const Duration(days: 180)),
            category: 'Gadgets',
            createdAt: DateTime.now(),
          ),
        ],
      );

      expect(health.totalScore, greaterThan(75.0));
      expect(health.scoreLabel, anyOf('Good', 'Excellent'));
    });
  });

  group('FuturePredictionService Tests', () {
    test('Projects compound savings growth over 12 months', () {
      final points = FuturePredictionService.runSimulation(
        currentSavings: 35000,
        monthlyIncome: 65000,
        monthlyExpenses: 25000,
        incomeGrowth: 8,
        expenseGrowth: 5,
        durationMonths: 12,
        scenarioMode: 'Balanced',
      );

      expect(points.length, 13); // month 0 to 12
      expect(points.first.balance, 35000);
      expect(points.last.balance, greaterThan(35000 + (40000 * 12)));
    });
  });

  group('GoalModel Tests', () {
    test('Calculates progress, remaining amount, and monthly required correctly', () {
      final goal = GoalModel(
        id: 'g1',
        title: 'MacBook',
        targetAmount: 100000,
        currentAmount: 40000,
        deadline: DateTime.now().add(const Duration(days: 180)), // ~6 months
        category: 'Gadgets',
        createdAt: DateTime.now(),
      );

      expect(goal.progressPercentage, 0.4);
      expect(goal.remainingAmount, 60000);
      expect(goal.daysRemaining, greaterThan(170));
      expect(goal.monthlyAmountRequired, closeTo(10000, 1500));
    });
  });
}
