import '../../models/advisor_models.dart';

class ExtractedEntities {
  final double? amount;
  final String? product;
  final String? timeframe;
  final String? category;

  const ExtractedEntities({
    this.amount,
    this.product,
    this.timeframe,
    this.category,
  });
}

class AdvisorContextMemory {
  String? lastProduct;
  double? lastAmount;
  String? lastTimeframe;
  AdvisorIntent? lastIntent;
  DateTime lastUpdated = DateTime.now();

  void update({
    String? product,
    double? amount,
    String? timeframe,
    AdvisorIntent? intent,
  }) {
    if (product != null && product.isNotEmpty) lastProduct = product;
    if (amount != null && amount > 0) lastAmount = amount;
    if (timeframe != null && timeframe.isNotEmpty) lastTimeframe = timeframe;
    if (intent != null) lastIntent = intent;
    lastUpdated = DateTime.now();
  }

  void clear() {
    lastProduct = null;
    lastAmount = null;
    lastTimeframe = null;
    lastIntent = null;
  }
}

class AdvisorIntentService {
  final AdvisorContextMemory memory = AdvisorContextMemory();

  AdvisorIntent detectIntent(String query) {
    final lower = query.toLowerCase().trim();

    // 1. Purchase / Affordability
    if (_containsAny(lower, [
      'can i afford',
      'should i buy',
      'can i buy',
      'is it worth buying',
      'afford this',
      'purchase',
      'affordability',
      'can i get',
    ])) {
      return AdvisorIntent.affordability;
    }

    // 2. Financial X-Ray / Audit / Checkup
    if (_containsAny(lower, [
      'analyze my finances',
      'financial xray',
      'financial x-ray',
      'audit my money',
      'financial health',
      'health check',
      'score my finances',
      'how healthy are my finances',
      'evaluate my money',
    ])) {
      return AdvisorIntent.financialHealth;
    }

    // 3. Goal Optimization & Planning
    if (_containsAny(lower, [
      'optimize my goals',
      'best next goal',
      'which goal first',
      'goal conflict',
      'prioritize goals',
      'goal roadmap',
      'plan my goal',
      'reach my goal',
      'goal timeline',
    ])) {
      return AdvisorIntent.goalOptimization;
    }

    // 4. What-If Simulation
    if (_containsAny(lower, [
      'what if',
      'simulate',
      'scenario',
      'if my salary',
      'if i save',
      'if i spend less',
      'what happens if',
    ])) {
      return AdvisorIntent.futureSimulation;
    }

    // 5. Financial DNA
    if (_containsAny(lower, [
      'financial dna',
      'my spending personality',
      'am i a saver',
      'am i a spender',
      'money archetype',
      'behavior analysis',
    ])) {
      return AdvisorIntent.generalFinance;
    }

    // 6. Investments & Portfolio
    if (_containsAny(lower, [
      'where should i invest',
      'where to invest',
      'increase my sip',
      'sip amount',
      'mutual fund',
      'stocks',
      'invest more',
      'asset allocation',
      'portfolio risk',
      'investment strategy',
    ])) {
      return AdvisorIntent.investment;
    }

    // 7. Debt & Loan & EMI
    if (_containsAny(lower, [
      'repay loan',
      'pay off debt',
      'emi burden',
      'prepay home loan',
      'debt or invest',
      'credit card debt',
      'clear loan',
      'debt repayment',
    ])) {
      return AdvisorIntent.debt;
    }

    // 8. Emergency Fund & Runway
    if (_containsAny(lower, [
      'emergency fund',
      'rainy day',
      'emergency reserve',
      'runway',
      'how many months of expenses',
    ])) {
      return AdvisorIntent.emergencyFund;
    }

    // 9. Cash Flow & Surplus
    if (_containsAny(lower, [
      'cash flow',
      'monthly surplus',
      'burn rate',
      'income vs expense',
      'am i running a deficit',
      'overspending trend',
    ])) {
      return AdvisorIntent.cashFlow;
    }

    // 10. Budget & Expense Tracking
    if (_containsAny(lower, [
      'budget',
      'spending limit',
      'category budget',
      'where am i spending',
      'cut expenses',
      'food delivery spend',
    ])) {
      return AdvisorIntent.budget;
    }

    // 11. Specific Big Purchases (Car, Home, Education, Travel)
    if (_containsAny(lower, ['buy a car', 'car loan', 'purchase vehicle', 'electric car'])) {
      return AdvisorIntent.car;
    }
    if (_containsAny(lower, ['buy a house', 'buy a flat', 'home loan', 'down payment'])) {
      return AdvisorIntent.home;
    }
    if (_containsAny(lower, ['vacation', 'trip to', 'holiday', 'travel budget'])) {
      return AdvisorIntent.travel;
    }
    if (_containsAny(lower, ['mba', 'masters', 'education loan', 'college fees'])) {
      return AdvisorIntent.education;
    }

    // 12. Tax planning
    if (_containsAny(lower, ['tax saving', 'save tax', '80c', 'old vs new regime', 'tax bracket'])) {
      return AdvisorIntent.tax;
    }

    // 13. Retirement
    if (_containsAny(lower, ['retirement', 'retire early', 'fire number', 'pension', 'nps'])) {
      return AdvisorIntent.retirement;
    }

    // If context memory has a previous intent (e.g. user just said "Next year" or "₹10 lakh")
    if (memory.lastIntent != null &&
        DateTime.now().difference(memory.lastUpdated).inMinutes < 10) {
      return memory.lastIntent!;
    }

    return AdvisorIntent.generalFinance;
  }

  ExtractedEntities extractEntities(String query) {
    final lower = query.toLowerCase();

    // 1. Amount extraction: handles ₹50,000, 50k, 10 lakh, 1.5 cr, etc.
    double? amount;

    // Pattern: 50k / 50K
    final kMatch = RegExp(r'(\d+(?:\.\d+)?)\s*k\b', caseSensitive: false).firstMatch(lower);
    if (kMatch != null) {
      amount = (double.tryParse(kMatch.group(1)!) ?? 0) * 1000;
    }

    // Pattern: 10 lakh / 10 lakhs / 1.5 lac
    if (amount == null) {
      final lakhMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(?:lakh|lakhs|lac|lacs)\b', caseSensitive: false).firstMatch(lower);
      if (lakhMatch != null) {
        amount = (double.tryParse(lakhMatch.group(1)!) ?? 0) * 100000;
      }
    }

    // Pattern: 1 cr / 1.5 crore
    if (amount == null) {
      final crMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(?:cr|crore|crores)\b', caseSensitive: false).firstMatch(lower);
      if (crMatch != null) {
        amount = (double.tryParse(crMatch.group(1)!) ?? 0) * 10000000;
      }
    }

    // Pattern: ₹50,000 or Rs 50000 or standard number > 100
    if (amount == null) {
      final numMatch = RegExp(r'(?:₹|rs\.?|inr)?\s*([0-9]{1,3}(?:,[0-9]{3})+(?:\.[0-9]+)?|[0-9]{3,9}(?:\.[0-9]+)?)').firstMatch(lower);
      if (numMatch != null) {
        final cleanNum = numMatch.group(1)!.replaceAll(',', '');
        amount = double.tryParse(cleanNum);
      }
    }

    // 2. Product / Target extraction
    String? product;
    final productPatterns = [
      RegExp(r'(?:buy|afford|get|purchase)\s+(?:a|an|the)?\s*([a-zA-Z0-9\s]{3,20}?)(?:\s+for|\s+at|\s+worth|\s+next|\s+in|\?|$)', caseSensitive: false),
      RegExp(r'(?:iphone|macbook|laptop|car|bike|watch|headphone|phone|tv|house|apartment|flat|trip|course)', caseSensitive: false),
    ];

    for (final pattern in productPatterns) {
      final match = pattern.firstMatch(lower);
      if (match != null) {
        product = match.group(0)!.replaceAll(RegExp(r'\b(buy|afford|get|purchase|a|an|the|for|at|worth)\b', caseSensitive: false), '').trim();
        if (product.isNotEmpty) break;
      }
    }

    // 3. Timeframe extraction
    String? timeframe;
    if (lower.contains('next year')) timeframe = 'in 1 year';
    if (lower.contains('this year')) timeframe = 'this year';
    if (lower.contains('next month')) timeframe = 'next month';
    if (lower.contains('3 months') || lower.contains('6 months')) timeframe = 'in 6 months';

    // Update memory if values found, or fallback to memory if missing
    final resolvedAmount = amount ?? memory.lastAmount;
    final resolvedProduct = (product != null && product.isNotEmpty) ? product : memory.lastProduct;
    final resolvedTimeframe = timeframe ?? memory.lastTimeframe;

    memory.update(
      product: resolvedProduct,
      amount: resolvedAmount,
      timeframe: resolvedTimeframe,
    );

    return ExtractedEntities(
      amount: resolvedAmount,
      product: resolvedProduct,
      timeframe: resolvedTimeframe,
    );
  }

  bool _containsAny(String text, List<String> phrases) {
    for (final phrase in phrases) {
      if (text.contains(phrase)) return true;
    }
    return false;
  }
}
