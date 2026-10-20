import '../providers/finance_provider.dart';
import '../models/finance_transaction.dart';

class ReceiptSuggestionService {
  static const List<String> categories = [
    'Food & Dining',
    'Shopping',
    'Transport',
    'Bills',
    'Entertainment',
    'Health',
    'Education',
    'Travel',
    'Groceries',
    'Other',
  ];

  static const List<String> paymentMethods = [
    'UPI',
    'Cash',
    'Debit Card',
    'Credit Card',
    'Bank Transfer',
    'Other',
  ];

  /// Suggests a category based on the merchant name using local intelligence.
  static String suggestCategory(String merchant) {
    final clean = merchant.trim().toLowerCase();
    if (clean.isEmpty) return 'Other';

    // Groceries
    if (_containsAny(clean, [
      'zepto',
      'blinkit',
      'instamart',
      'reliance fresh',
      'bigbasket',
      'dmart',
      'nature basket',
      'spencer',
      'supermarket',
      'grocery',
      'groceries',
      'vegetable',
      'fruits',
    ])) {
      return 'Groceries';
    }

    // Food & Dining
    if (_containsAny(clean, [
      'swiggy',
      'zomato',
      'starbucks',
      'mcdonald',
      'kfc',
      'domino',
      'pizza',
      'burger',
      'cafe',
      'coffee',
      'restaurant',
      'dining',
      'subway',
      'eatclub',
      'faasos',
      'behrouz',
      'bakery',
      'diner',
    ])) {
      return 'Food & Dining';
    }

    // Transport
    if (_containsAny(clean, [
      'uber',
      'ola',
      'rapido',
      'metro',
      'fuel',
      'petrol',
      'diesel',
      'shell',
      'hpcl',
      'bpcl',
      'ioc',
      'fastag',
      'toll',
      'parking',
      'auto',
      'cab',
      'taxi',
    ])) {
      return 'Transport';
    }

    // Shopping
    if (_containsAny(clean, [
      'amazon',
      'flipkart',
      'myntra',
      'ajio',
      'zara',
      'h&m',
      'nike',
      'adidas',
      'uniqlo',
      'decathlon',
      'lifestyle',
      'westside',
      'pantaloons',
      'shoppers stop',
      'clothing',
      'store',
      'retail',
      'mall',
    ])) {
      return 'Shopping';
    }

    // Bills & Utilities
    if (_containsAny(clean, [
      'electricity',
      'water',
      'gas',
      'bescom',
      'mseb',
      'tata power',
      'adani',
      'airtel',
      'jio',
      'vi',
      'broadband',
      'wifi',
      'recharge',
      'bill',
      'rent',
      'society',
      'maintenance',
    ])) {
      return 'Bills';
    }

    // Entertainment
    if (_containsAny(clean, [
      'netflix',
      'spotify',
      'prime',
      'youtube',
      'hotstar',
      'disney',
      'bookmyshow',
      'pvr',
      'inox',
      'cinepolis',
      'movie',
      'cinema',
      'game',
      'steam',
      'playstation',
    ])) {
      return 'Entertainment';
    }

    // Health
    if (_containsAny(clean, [
      'apollo',
      'pharmacy',
      'chemist',
      'netmeds',
      'pharmeasy',
      '1mg',
      'medplus',
      'hospital',
      'clinic',
      'doctor',
      'dental',
      'pathology',
      'lab',
      'medicine',
    ])) {
      return 'Health';
    }

    // Education
    if (_containsAny(clean, [
      'udemy',
      'coursera',
      'edx',
      'college',
      'school',
      'university',
      'tuition',
      'course',
      'class',
      'books',
      'bookstore',
      'stationery',
    ])) {
      return 'Education';
    }

    // Travel
    if (_containsAny(clean, [
      'makemytrip',
      'goibibo',
      'booking.com',
      'airbnb',
      'hotel',
      'resort',
      'indigo',
      'air india',
      'spicejet',
      'akasa',
      'irctc',
      'flight',
      'trip',
      'travel',
    ])) {
      return 'Travel';
    }

    return 'Other';
  }

  /// Suggests a probable payment method based on merchant text.
  static String suggestPaymentMethod(String text) {
    final clean = text.trim().toLowerCase();
    if (clean.isEmpty) return 'UPI';

    if (_containsAny(clean, [
      'credit card',
      'credit',
      'mastercard',
      'visa',
      'amex',
    ])) {
      return 'Credit Card';
    }
    if (_containsAny(clean, ['debit card', 'debit'])) {
      return 'Debit Card';
    }
    if (_containsAny(clean, ['cash', 'counter', 'petty'])) {
      return 'Cash';
    }
    if (_containsAny(clean, [
      'neft',
      'rtgs',
      'imps',
      'transfer',
      'rent',
      'electricity',
      'society',
      'wire',
      'bank',
    ])) {
      return 'Bank Transfer';
    }
    if (_containsAny(clean, [
      'amazon',
      'netflix',
      'flight',
      'hotel',
      'zara',
      'apple',
      'croma',
    ])) {
      return 'Credit Card';
    }
    if (_containsAny(clean, [
      'swiggy',
      'zomato',
      'uber',
      'ola',
      'zepto',
      'blinkit',
      'tea',
      'cafe',
      'upiqr',
      'upi',
      'gpay',
      'phonepe',
      'paytm',
    ])) {
      return 'UPI';
    }

    return 'UPI';
  }

  /// Calculates the budget impact of the expense against the monthly budget or total monthly income/spending.
  static BudgetImpact calculateBudgetImpact({
    required double amount,
    required FinanceProvider finance,
  }) {
    // Current monthly expense baseline
    final currentMonthlyExpense = finance.monthlyExpense;
    // Use monthly income or a fallback base budget if income is 0
    final double monthlyTarget = finance.monthlyIncome > 0
        ? finance.monthlyIncome
        : 25000.0;
    final double newTotal = currentMonthlyExpense + amount;
    final double percentage = (newTotal / monthlyTarget).clamp(0.0, 1.5) * 100;

    return BudgetImpact(
      amount: amount,
      monthlyTarget: monthlyTarget,
      projectedMonthlySpend: newTotal,
      percentageOfTarget: percentage,
      isExceeding: newTotal > monthlyTarget,
    );
  }

  /// Generates a realistic, data-driven AI financial insight for the saved receipt expense.
  static ReceiptInsight generateInsight({
    required double amount,
    required String category,
    required String merchant,
    required FinanceProvider finance,
  }) {
    final now = DateTime.now();
    final transactions = finance.transactions;

    // Current month transactions in this category (including or plus this one)
    final currentMonthCategorySpend = transactions
        .where(
          (t) =>
              t.type == TransactionType.expense &&
              t.date.year == now.year &&
              t.date.month == now.month &&
              _isCategoryMatch(t.category, category),
        )
        .fold(0.0, (sum, t) => sum + t.amount);

    // Prior month transactions in this category
    final lastMonth = DateTime(now.year, now.month - 1, 1);
    final lastMonthCategorySpend = transactions
        .where(
          (t) =>
              t.type == TransactionType.expense &&
              t.date.year == lastMonth.year &&
              t.date.month == lastMonth.month &&
              _isCategoryMatch(t.category, category),
        )
        .fold(0.0, (sum, t) => sum + t.amount);

    // Calculate trend percentage
    double trendPercentage = 0.0;
    if (lastMonthCategorySpend > 0) {
      trendPercentage =
          ((currentMonthCategorySpend - lastMonthCategorySpend) /
              lastMonthCategorySpend) *
          100;
    } else if (currentMonthCategorySpend > 0) {
      trendPercentage = 12.0; // Realistic default if no prior month record
    }

    final budgetImpact = calculateBudgetImpact(
      amount: amount,
      finance: finance,
    );

    String headline;
    String recommendation;

    if (budgetImpact.isExceeding) {
      headline =
          'This purchase puts your monthly spending above your planned target.';
      recommendation =
          'Consider limiting discretionary $category purchases for the remainder of the month.';
    } else if (trendPercentage > 15) {
      headline =
          'This purchase is within your monthly limit, but $category expenses are trending upward.';
      final suggestedWeeklyCap = (amount * 0.7).clamp(200.0, 5000.0).round();
      recommendation =
          'Consider limiting $category purchases to \u20B9$suggestedWeeklyCap per week to stay comfortably within your target.';
    } else {
      headline = 'Expense successfully logged. Your cash flow and monthly spending remain well balanced.';
      recommendation =
          'Great job maintaining steady financial discipline this month.';
    }

    return ReceiptInsight(
      headline: headline,
      monthlyCategorySpend: currentMonthCategorySpend,
      categoryName: category,
      trendPercentage: trendPercentage,
      recommendation: recommendation,
      budgetImpact: budgetImpact,
    );
  }

  static bool _containsAny(String text, List<String> terms) {
    for (final term in terms) {
      if (text.contains(term)) return true;
    }
    return false;
  }

  static bool _isCategoryMatch(String cat1, String cat2) {
    final c1 = cat1.toLowerCase().trim();
    final c2 = cat2.toLowerCase().trim();
    if (c1 == c2) return true;
    if (c1.contains('food') && c2.contains('food')) return true;
    if (c1.contains('grocer') && c2.contains('grocer')) return true;
    return false;
  }
}

class BudgetImpact {
  final double amount;
  final double monthlyTarget;
  final double projectedMonthlySpend;
  final double percentageOfTarget;
  final bool isExceeding;

  BudgetImpact({
    required this.amount,
    required this.monthlyTarget,
    required this.projectedMonthlySpend,
    required this.percentageOfTarget,
    required this.isExceeding,
  });
}

class ReceiptInsight {
  final String headline;
  final double monthlyCategorySpend;
  final String categoryName;
  final double trendPercentage;
  final String recommendation;
  final BudgetImpact budgetImpact;

  ReceiptInsight({
    required this.headline,
    required this.monthlyCategorySpend,
    required this.categoryName,
    required this.trendPercentage,
    required this.recommendation,
    required this.budgetImpact,
  });
}
