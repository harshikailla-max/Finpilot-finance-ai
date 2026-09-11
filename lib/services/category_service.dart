class CategoryService {
  static String detectExpenseCategory(String title) {
    final cleanTitle = title.toLowerCase().trim();

    if (_matchesAny(cleanTitle, ['swiggy', 'zomato', 'restaurant', 'food', 'cafe', 'groceries', 'starbucks', 'mcdonalds', 'pizza', 'burger', 'eat', 'dining', 'bakery'])) {
      return 'Food';
    }
    if (_matchesAny(cleanTitle, ['uber', 'ola', 'metro', 'fuel', 'petrol', 'cab', 'taxi', 'train', 'flight', 'auto', 'ride', 'diesel', 'toll'])) {
      return 'Transport';
    }
    if (_matchesAny(cleanTitle, ['netflix', 'prime', 'movie', 'cinema', 'spotify', 'youtube premium', 'concert', 'game', 'entertainment', 'club', 'pub', 'theater'])) {
      return 'Entertainment';
    }
    if (_matchesAny(cleanTitle, ['amazon', 'flipkart', 'myntra', 'clothes', 'shoes', 'mall', 'store', 'purchase', 'shopping', 'fashion', 'zara'])) {
      return 'Shopping';
    }
    if (_matchesAny(cleanTitle, ['electricity', 'water', 'rent', 'recharge', 'wifi', 'broadband', 'mobile', 'gas', 'bill', 'subscription', 'insurance', 'phone'])) {
      return 'Bills';
    }
    if (_matchesAny(cleanTitle, ['pharmacy', 'doctor', 'hospital', 'medicine', 'health', 'dental', 'clinic', 'medical'])) {
      return 'Health';
    }
    if (_matchesAny(cleanTitle, ['hotel', 'airbnb', 'booking', 'travel', 'vacation', 'trip', 'flight', 'resort'])) {
      return 'Travel';
    }
    if (_matchesAny(cleanTitle, ['books', 'textbook', 'course', 'udemy', 'coursera', 'college', 'tuition', 'school', 'fees', 'class'])) {
      return 'Education';
    }

    return 'Other';
  }

  static String detectIncomeCategory(String title) {
    final cleanTitle = title.toLowerCase().trim();

    if (_matchesAny(cleanTitle, ['salary', 'paycheck', 'monthly salary', 'employer', 'ctc', 'wages'])) {
      return 'Salary';
    }
    if (_matchesAny(cleanTitle, ['freelance', 'upwork', 'fiverr', 'client', 'project', 'contract'])) {
      return 'Freelance';
    }
    if (_matchesAny(cleanTitle, ['business', 'sales', 'revenue', 'customer', 'invoice'])) {
      return 'Business';
    }
    if (_matchesAny(cleanTitle, ['dividend', 'interest', 'stock', 'crypto', 'mutual fund', 'returns', 'payout'])) {
      return 'Investment';
    }
    if (_matchesAny(cleanTitle, ['bonus', 'reward', 'incentive', 'commission'])) {
      return 'Bonus';
    }
    if (_matchesAny(cleanTitle, ['gift', 'birthday', 'present', 'cashback'])) {
      return 'Gift';
    }
    if (_matchesAny(cleanTitle, ['scholarship', 'grant', 'fellowship', 'stipend'])) {
      return 'Scholarship';
    }

    return 'Other';
  }

  static bool _matchesAny(String value, List<String> keywords) {
    return keywords.any((keyword) => value.contains(keyword));
  }
}
