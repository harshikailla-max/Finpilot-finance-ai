import '../models/finance_transaction.dart';
import '../models/budget_model.dart';
import '../models/goal_model.dart';
import '../utils/currency_formatter.dart';

class AIInsight {
  final String title;
  final String message;
  final String type; // positive, warning, opportunity, tip

  AIInsight({
    required this.title,
    required this.message,
    required this.type,
  });
}

class AIFinanceService {
  static List<AIInsight> generateInsights({
    required List<FinanceTransaction> transactions,
    required BudgetModel budget,
    required List<GoalModel> goals,
  }) {
    List<AIInsight> insights = [];

    // Calculate totals
    double totalIncome = 0.0;
    double totalExpense = 0.0;
    Map<String, double> categorySpent = {};

    for (var tx in transactions) {
      if (tx.type == TransactionType.income) {
        totalIncome += tx.amount;
      } else {
        totalExpense += tx.amount;
        categorySpent[tx.category] = (categorySpent[tx.category] ?? 0.0) + tx.amount;
      }
    }

    final savings = totalIncome - totalExpense;
    final savingsRate = totalIncome > 0 ? (savings / totalIncome) * 100 : 0.0;

    // 1. Positive Insight: Savings Rate
    if (savingsRate >= 20.0) {
      insights.add(AIInsight(
        title: 'Healthy Savings Rate',
        message: 'You saved ${savingsRate.toStringAsFixed(0)}% of your income this month (${CurrencyFormatter.format(savings)}). Keep it up!',
        type: 'positive',
      ));
    } else if (savingsRate > 0) {
      insights.add(AIInsight(
        title: 'Positive Cash Flow',
        message: 'You achieved a positive savings rate of ${savingsRate.toStringAsFixed(0)}% (${CurrencyFormatter.format(savings)}), but aiming for 20% can build wealth faster.',
        type: 'positive',
      ));
    } else if (totalIncome > 0 && savingsRate <= 0) {
      insights.add(AIInsight(
        title: 'Negative Cash Flow',
        message: 'Your expenses exceeded your income by ${CurrencyFormatter.format(-savings)} this month. Consider checking your discretionary costs.',
        type: 'warning',
      ));
    }

    // 2. Budget Alert Warnings
    budget.categoryLimits.forEach((category, limit) {
      if (limit > 0) {
        final spent = categorySpent[category] ?? 0.0;
        final usage = (spent / limit) * 100;
        if (usage >= 100) {
          insights.add(AIInsight(
            title: '$category Budget Exceeded',
            message: 'You have spent ${CurrencyFormatter.format(spent)} against a budget of ${CurrencyFormatter.format(limit)} for $category.',
            type: 'warning',
          ));
        } else if (usage >= 80) {
          insights.add(AIInsight(
            title: '$category Budget Alert',
            message: 'Your $category expenses are at ${usage.toStringAsFixed(0)}% of your limit. Consider holding off on further $category purchases.',
            type: 'warning',
          ));
        }
      }
    });

    // 3. Opportunities (e.g. Discretionary expenses reductions)
    final foodSpend = categorySpent['Food'] ?? 0.0;
    if (foodSpend > 5000) {
      final potentialSavings = foodSpend * 0.15;
      insights.add(AIInsight(
        title: 'Food Savings Opportunity',
        message: 'Reducing food delivery and dine-out expenses by 15% could save you around ${CurrencyFormatter.format(potentialSavings)} monthly.',
        type: 'opportunity',
      ));
    }

    final shoppingSpend = categorySpent['Shopping'] ?? 0.0;
    if (shoppingSpend > 3000) {
      final potentialSavings = shoppingSpend * 0.20;
      insights.add(AIInsight(
        title: 'Shopping Optimization',
        message: 'Delaying non-essential shopping items to save 20% would add ${CurrencyFormatter.format(potentialSavings)} back to your pocket.',
        type: 'opportunity',
      ));
    }

    // 4. Financial Tips
    if (goals.isEmpty) {
      insights.add(AIInsight(
        title: 'Set a Savings Goal',
        message: 'Users with active goals save up to 40% more. Create your first goal, like an Emergency Fund, on the Goals screen.',
        type: 'tip',
      ));
    } else {
      final emergencyFundGoal = goals.any((g) => g.category == 'Emergency Fund');
      if (!emergencyFundGoal) {
        insights.add(AIInsight(
          title: 'Emergency Fund Tip',
          message: 'It is highly recommended to set up an Emergency Fund covering 3 to 6 months of living expenses before active investing.',
          type: 'tip',
        ));
      }
    }

    // Default tip if list is small
    if (insights.length < 3) {
      insights.add(AIInsight(
        title: 'Rule of 50/30/20',
        message: 'Aim to budget 50% for Needs, 30% for Wants, and direct 20% to Savings or Investments.',
        type: 'tip',
      ));
    }

    return insights;
  }

  static String generateChatResponse({
    required String query,
    required List<FinanceTransaction> transactions,
    required BudgetModel budget,
    required List<GoalModel> goals,
  }) {
    final cleanQuery = query.toLowerCase();

    // Summing values
    double totalIncome = 0.0;
    double totalExpense = 0.0;
    Map<String, double> categorySpent = {};

    for (var tx in transactions) {
      if (tx.type == TransactionType.income) {
        totalIncome += tx.amount;
      } else {
        totalExpense += tx.amount;
        categorySpent[tx.category] = (categorySpent[tx.category] ?? 0.0) + tx.amount;
      }
    }

    final savings = totalIncome - totalExpense;
    final savingsRate = totalIncome > 0 ? (savings / totalIncome) * 100 : 0.0;

    // 1. Where am I spending the most?
    if (cleanQuery.contains('spending the most') ||
        cleanQuery.contains('highest spend') ||
        cleanQuery.contains('where did my money go') ||
        cleanQuery.contains('most spend')) {
      if (categorySpent.isEmpty) {
        return "You haven't logged any expenses yet. Once you add some expenses, I can tell you where you are spending the most.";
      }
      var sortedCategories = categorySpent.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topCategory = sortedCategories.first.key;
      final topAmount = sortedCategories.first.value;
      final percentage = totalExpense > 0 ? (topAmount / totalExpense) * 100 : 0.0;

      String response = "Your highest spending category this month is **$topCategory** at **${CurrencyFormatter.format(topAmount)}**, which represents **${percentage.toStringAsFixed(0)}%** of your total monthly expenses.\n\n";
      if (sortedCategories.length > 1) {
        response += "Here is your top category breakdown:\n";
        for (int i = 0; i < sortedCategories.length && i < 3; i++) {
          final cat = sortedCategories[i].key;
          final amt = sortedCategories[i].value;
          final pct = totalExpense > 0 ? (amt / totalExpense) * 100 : 0.0;
          response += "- **$cat**: ${CurrencyFormatter.format(amt)} (${pct.toStringAsFixed(0)}%)\n";
        }
      }
      return response;
    }

    // 2. How can I save more?
    if (cleanQuery.contains('save more') ||
        cleanQuery.contains('increase savings') ||
        cleanQuery.contains('how to save')) {
      String response = "Your current savings rate is **${savingsRate.toStringAsFixed(0)}%** (${CurrencyFormatter.format(savings)} saved from ${CurrencyFormatter.format(totalIncome)} income).\n\n";
      response += "To increase your savings rate to the recommended **20% - 30%**, try these actions:\n";

      final foodSpend = categorySpent['Food'] ?? 0.0;
      if (foodSpend > 3000) {
        response += "- **Optimize Food Budgets**: You spent ${CurrencyFormatter.format(foodSpend)} on food. Cutting back on food delivery services by ₹1,500 would increase your savings rate immediately.\n";
      }

      final shoppingSpend = categorySpent['Shopping'] ?? 0.0;
      if (shoppingSpend > 2000) {
        response += "- **Limit Non-Essential Shopping**: You spent ${CurrencyFormatter.format(shoppingSpend)} on shopping. Delaying shopping items by implementing a '48-hour rule' before buying would save you considerable cash.\n";
      }

      response += "- **Automate Savings**: Set a rule to transfer 10% of your salary directly to a savings/investment vehicle on payday before spending.";
      return response;
    }

    // 3. Am I overspending?
    if (cleanQuery.contains('overspending') ||
        cleanQuery.contains('budget limit') ||
        cleanQuery.contains('budget status')) {
      if (budget.monthlyLimit == 0) {
        return "You have not set a monthly budget yet! Setting a budget helps prevent overspending. You can configure it on the Budgets screen.";
      }
      final usage = totalExpense;
      final limit = budget.monthlyLimit;
      final percentage = (usage / limit) * 100;

      String response = "Your overall budget usage is **${percentage.toStringAsFixed(0)}%** (${CurrencyFormatter.format(usage)} spent out of ${CurrencyFormatter.format(limit)}).\n\n";

      List<String> overBudgetCategories = [];
      budget.categoryLimits.forEach((cat, lim) {
        if (lim > 0 && (categorySpent[cat] ?? 0.0) > lim) {
          overBudgetCategories.add(cat);
        }
      });

      if (percentage > 100) {
        response += "⚠️ **You have exceeded your total monthly budget** by **${CurrencyFormatter.format(usage - limit)}**.";
      } else if (percentage >= 80) {
        response += "⚠️ **Warning**: You are approaching your budget limit. You only have **${CurrencyFormatter.format(limit - usage)}** remaining.";
      } else {
        response += "✅ Your total spending is currently within healthy limits.";
      }

      if (overBudgetCategories.isNotEmpty) {
        response += "\n\nSpecific categories that have exceeded budget:\n";
        for (var cat in overBudgetCategories) {
          final lim = budget.categoryLimits[cat]!;
          final sp = categorySpent[cat]!;
          response += "- **$cat**: Spent ${CurrencyFormatter.format(sp)} (Limit: ${CurrencyFormatter.format(lim)})\n";
        }
      }
      return response;
    }

    // 4. Create a budget for me
    if (cleanQuery.contains('create a budget') ||
        cleanQuery.contains('suggest budget') ||
        cleanQuery.contains('budget allocation')) {
      if (totalIncome == 0) {
        return "I need to know your monthly income to create a budget. Please log some income transactions or specify your income in the Future Simulator.";
      }

      final needsLimit = totalIncome * 0.50;
      final wantsLimit = totalIncome * 0.30;
      final savingsLimit = totalIncome * 0.20;

      return "Based on your current monthly income of **${CurrencyFormatter.format(totalIncome)}**, here is a recommended **50/30/20 budget plan**:\n\n"
          "1. **Needs (50%)**: **${CurrencyFormatter.format(needsLimit)}**\n"
          "   - For rent, utility bills, transport, health, and education.\n"
          "2. **Wants (30%)**: **${CurrencyFormatter.format(wantsLimit)}**\n"
          "   - For dining out, shopping, hobbies, movies, and travel.\n"
          "3. **Savings & Debt (20%)**: **${CurrencyFormatter.format(savingsLimit)}**\n"
          "   - For investments, emergency fund, and goals.\n\n"
          "Would you like me to pre-fill your monthly category limits based on this guideline?";
    }

    // 5. Can I reach my savings goal?
    if (cleanQuery.contains('reach my savings goal') ||
        cleanQuery.contains('savings goal') ||
        cleanQuery.contains('my goals')) {
      if (goals.isEmpty) {
        return "You don't have any savings goals set up yet. Creating goals like 'New Laptop' or 'Emergency Fund' keeps you motivated. Go to the Goals section to set one!";
      }

      String response = "You have **${goals.length} active savings goal(s)**:\n\n";
      for (var goal in goals) {
        final remaining = goal.remainingAmount;
        final monthsNeeded = savings > 0 ? (remaining / savings) : double.infinity;

        response += "🏆 **${goal.title}**\n"
            "- Target: ${CurrencyFormatter.format(goal.targetAmount)}\n"
            "- Current: ${CurrencyFormatter.format(goal.currentAmount)} (${(goal.progressPercentage * 100).toStringAsFixed(0)}%)\n"
            "- Remaining: ${CurrencyFormatter.format(remaining)}\n";

        if (monthsNeeded == double.infinity) {
          response += "- *Status*: You have no savings this month to allocate. Try reducing expenses to make progress.\n\n";
        } else {
          response += "- *Estimation*: At your current monthly savings rate (${CurrencyFormatter.format(savings)}/mo), you will reach this in **${monthsNeeded.toStringAsFixed(1)} months**.\n\n";
        }
      }
      return response;
    }

    // Generic response fallback
    return "Hi, I am FinPilot AI, your intelligent financial companion. I can analyze your transactions, track budgets, and help you project future wealth.\n\n"
        "Try asking me:\n"
        "- *'Where am I spending the most?'*\n"
        "- *'Am I overspending?'*\n"
        "- *'How can I save more?'*\n"
        "- *'Create a budget for me'*";
  }
}
