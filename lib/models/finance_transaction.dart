enum TransactionType { income, expense }

class FinanceTransaction {
  final String id;
  final String title;
  final double amount;
  final String category;
  final TransactionType type;
  final DateTime date;
  final String paymentMethod;
  final String note;
  final String merchant;
  final bool isRecurring;
  final DateTime createdAt;
  final String source;

  FinanceTransaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.type,
    required this.date,
    required this.paymentMethod,
    this.note = '',
    this.merchant = '',
    this.isRecurring = false,
    required this.createdAt,
    this.source = 'Manual',
  });

  FinanceTransaction copyWith({
    String? id,
    String? title,
    double? amount,
    String? category,
    TransactionType? type,
    DateTime? date,
    String? paymentMethod,
    String? note,
    String? merchant,
    bool? isRecurring,
    DateTime? createdAt,
    String? source,
  }) {
    return FinanceTransaction(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      type: type ?? this.type,
      date: date ?? this.date,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      note: note ?? this.note,
      merchant: merchant ?? this.merchant,
      isRecurring: isRecurring ?? this.isRecurring,
      createdAt: createdAt ?? this.createdAt,
      source: source ?? this.source,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'category': category,
      'type': type.name,
      'date': date.toIso8601String(),
      'paymentMethod': paymentMethod,
      'note': note,
      'merchant': merchant,
      'isRecurring': isRecurring,
      'createdAt': createdAt.toIso8601String(),
      'source': source,
    };
  }

  factory FinanceTransaction.fromJson(Map<String, dynamic> json) {
    return FinanceTransaction(
      id: json['id'] as String,
      title: json['title'] as String,
      amount: (json['amount'] as num).toDouble(),
      category: json['category'] as String,
      type: TransactionType.values.byName(json['type'] as String),
      date: DateTime.parse(json['date'] as String),
      paymentMethod: json['paymentMethod'] as String,
      note: json['note'] as String? ?? '',
      merchant: json['merchant'] as String? ?? '',
      isRecurring: json['isRecurring'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      source: json['source'] as String? ?? 'Manual',
    );
  }
}
