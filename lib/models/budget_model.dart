class BudgetModel {
  final double monthlyLimit;
  final Map<String, double> categoryLimits;

  BudgetModel({required this.monthlyLimit, required this.categoryLimits});

  BudgetModel copyWith({
    double? monthlyLimit,
    Map<String, double>? categoryLimits,
  }) {
    return BudgetModel(
      monthlyLimit: monthlyLimit ?? this.monthlyLimit,
      categoryLimits: categoryLimits ?? this.categoryLimits,
    );
  }

  Map<String, dynamic> toJson() {
    return {'monthlyLimit': monthlyLimit, 'categoryLimits': categoryLimits};
  }

  factory BudgetModel.fromJson(Map<String, dynamic> json) {
    return BudgetModel(
      monthlyLimit: (json['monthlyLimit'] as num).toDouble(),
      categoryLimits: (json['categoryLimits'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      ),
    );
  }
}
