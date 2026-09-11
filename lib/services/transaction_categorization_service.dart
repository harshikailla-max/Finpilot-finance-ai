import '../models/finance_transaction.dart';

class TransactionCategorizationService {
  static const List<String> allCategories = [
    'Food & Dining',
    'Shopping',
    'Transport',
    'Bills',
    'Entertainment',
    'Health',
    'Education',
    'Travel',
    'Groceries',
    'Housing',
    'Income',
    'Other',
  ];

  /// Categorizes a transaction based on merchant and description text.
  static String detectCategory(String text, {TransactionType? type}) {
    final clean = text.toLowerCase();

    // If explicit income type
    if (type == TransactionType.income) {
      return 'Income';
    }

    // Income keywords
    if (_containsAny(clean, [
      'salary',
      'salary credit',
      'payroll',
      'dividend',
      'interest credit',
      'stipend',
      'bonus',
      'freelance',
      'cashback credit',
      'refund credit',
    ])) {
      return 'Income';
    }

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
      'kirana',
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
      'haldiram',
      'barbeque',
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
      'iocl',
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
      'retail',
      'mall',
      'nykaa',
      'meesho',
    ])) {
      return 'Shopping';
    }

    // Housing & Rent
    if (_containsAny(clean, [
      'rent',
      'house rent',
      'landlord',
      'society maintenance',
      'apartment maintenance',
      'nobroker',
      'magicbricks',
    ])) {
      return 'Housing';
    }

    // Bills & Utilities
    if (_containsAny(clean, [
      'electricity',
      'bescom',
      'mseb',
      'tata power',
      'adani',
      'airtel',
      'jio',
      'vi recharge',
      'vodafone',
      'broadband',
      'wifi',
      'recharge',
      'water bill',
      'gas bill',
      'piped gas',
      'indane',
      'bharat gas',
      'insurance',
      'lic',
      'emi',
      'loan',
    ])) {
      return 'Bills';
    }

    // Entertainment
    if (_containsAny(clean, [
      'netflix',
      'spotify',
      'prime video',
      'youtube',
      'hotstar',
      'disney',
      'bookmyshow',
      'pvr',
      'inox',
      'cinepolis',
      'movie',
      'cinema',
      'steam',
      'playstation',
      'gaming',
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
      'diagnostics',
      'thyrocare',
      'medication',
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
      'books',
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
      'railway',
      'flight',
      'travel',
    ])) {
      return 'Travel';
    }

    return 'Other';
  }

  /// Extracts a clean merchant name from raw bank narration.
  static String extractMerchant(String rawText) {
    if (rawText.trim().isEmpty) return 'Bank Transaction';

    final text = rawText.replaceAll(RegExp(r'[\r\n\t]+'), ' ').trim();
    final lower = text.toLowerCase();

    // Specific well-known merchants
    const knownMerchants = {
      'swiggy': 'Swiggy',
      'zomato': 'Zomato',
      'starbucks': 'Starbucks',
      'uber': 'Uber',
      'ola': 'Ola',
      'rapido': 'Rapido',
      'amazon': 'Amazon',
      'flipkart': 'Flipkart',
      'myntra': 'Myntra',
      'ajio': 'Ajio',
      'zara': 'Zara',
      'netflix': 'Netflix',
      'spotify': 'Spotify',
      'apollo': 'Apollo Pharmacy',
      'zepto': 'Zepto',
      'blinkit': 'Blinkit',
      'reliance fresh': 'Reliance Fresh',
      'bigbasket': 'BigBasket',
      'dmart': 'DMart',
      'airtel': 'Airtel',
      'jio': 'Jio',
      'electricity': 'Electricity Board',
      'bescom': 'BESCOM',
      'tata power': 'Tata Power',
      'mcdonald': 'McDonald\'s',
      'domino': 'Domino\'s',
      'kfc': 'KFC',
      'subway': 'Subway',
      'bookmyshow': 'BookMyShow',
      'pvr': 'PVR Cinemas',
      'inox': 'INOX',
      'irctc': 'IRCTC',
      'indigo': 'IndiGo',
    };

    for (final entry in knownMerchants.entries) {
      if (lower.contains(entry.key)) {
        return entry.value;
      }
    }

    // Bank transaction patterns
    if (lower.contains('atm') && lower.contains('wdl')) return 'ATM Cash Withdrawal';
    if (lower.contains('salary')) return 'Salary Credit';
    if (lower.contains('interest credit')) return 'Bank Interest Credit';
    if (lower.contains('dividend')) return 'Dividend Payout';
    if (lower.contains('rent')) return 'House Rent';

    // UPI pattern extraction: e.g. "UPI/423523/MERCHANT NAME/..." or "UPI-MERCHANT"
    final upiMatch = RegExp(r'UPI[-/](?:[A-Z0-9]+[-/])?([A-Za-z0-9 ]{3,25})').firstMatch(text);
    if (upiMatch != null) {
      final name = upiMatch.group(1)!.trim();
      if (name.isNotEmpty && !name.toLowerCase().contains('ref')) {
        return _capitalize(name);
      }
    }

    // POS card swipe pattern: e.g. "POS 4012 STORE NAME"
    final posMatch = RegExp(r'POS\s+(?:[0-9]+\s+)?([A-Za-z0-9 ]{3,25})').firstMatch(text);
    if (posMatch != null) {
      return _capitalize(posMatch.group(1)!.trim());
    }

    // Default clean truncate
    final cleaned = text
        .replaceAll(RegExp(r'[^a-zA-Z0-9\s-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (cleaned.length > 25) {
      return cleaned.substring(0, 25).trim();
    }

    return cleaned.isNotEmpty ? _capitalize(cleaned) : 'Bank Transaction';
  }

  /// Detects transaction type from narration or column indicators.
  static TransactionType detectType(String text, {bool? isCreditColumn, bool? isDebitColumn}) {
    if (isCreditColumn == true) return TransactionType.income;
    if (isDebitColumn == true) return TransactionType.expense;

    final lower = text.toLowerCase();

    // Income indicators
    if (_containsAny(lower, [
      'cr',
      'credit',
      'credited',
      'deposit',
      'salary',
      'refund',
      'reversal',
      'dividend',
      'interest',
      'bonus',
      'stipend',
      'neft cr',
      'rtgs cr',
      'imps cr',
      'upi cr',
    ])) {
      return TransactionType.income;
    }

    return TransactionType.expense;
  }

  /// Detects payment method based on narration text.
  static String detectPaymentMethod(String text) {
    final lower = text.toLowerCase();

    if (lower.contains('upi')) return 'UPI';
    if (lower.contains('atm') || lower.contains('cash')) return 'Cash';
    if (lower.contains('pos') || lower.contains('card') || lower.contains('debit')) return 'Debit Card';
    if (lower.contains('credit card') || lower.contains('cc payment')) return 'Credit Card';
    if (_containsAny(lower, ['neft', 'rtgs', 'imps', 'transfer', 'ach', 'ecs', 'wire'])) {
      return 'Bank Transfer';
    }

    return 'Bank Transfer';
  }

  static bool _containsAny(String text, List<String> terms) {
    for (final term in terms) {
      if (text.contains(term)) return true;
    }
    return false;
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s.split(' ').map((word) {
      if (word.isEmpty) return '';
      return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
    }).join(' ');
  }
}
