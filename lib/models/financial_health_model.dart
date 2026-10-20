class FinancialHealthModel {
  final double savingsScore; // max 25
  final double budgetScore; // max 25
  final double expenseControlScore; // max 20
  final double cashFlowScore; // max 15
  final double goalScore; // max 15

  FinancialHealthModel({
    required this.savingsScore,
    required this.budgetScore,
    required this.expenseControlScore,
    required this.cashFlowScore,
    required this.goalScore,
  });

  double get totalScore {
    return (savingsScore +
            budgetScore +
            expenseControlScore +
            cashFlowScore +
            goalScore)
        .clamp(0.0, 100.0);
  }

  String get scoreLabel {
    final score = totalScore;
    if (score >= 90) return 'Excellent';
    if (score >= 75) return 'Good';
    if (score >= 60) return 'Fair';
    return 'Needs Attention';
  }

  Map<String, dynamic> toJson() {
    return {
      'savingsScore': savingsScore,
      'budgetScore': budgetScore,
      'expenseControlScore': expenseControlScore,
      'cashFlowScore': cashFlowScore,
      'goalScore': goalScore,
    };
  }

  factory FinancialHealthModel.fromJson(Map<String, dynamic> json) {
    return FinancialHealthModel(
      savingsScore: (json['savingsScore'] as num).toDouble(),
      budgetScore: (json['budgetScore'] as num).toDouble(),
      expenseControlScore: (json['expenseControlScore'] as num).toDouble(),
      cashFlowScore: (json['cashFlowScore'] as num).toDouble(),
      goalScore: (json['goalScore'] as num).toDouble(),
    );
  }
}
