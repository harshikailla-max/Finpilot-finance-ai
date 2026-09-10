class InvestmentModel {
  final String id;
  final String name;
  final String type;
  final double investedAmount;
  final double currentValue;
  final DateTime date;

  InvestmentModel({
    required this.id,
    required this.name,
    required this.type,
    required this.investedAmount,
    required this.currentValue,
    required this.date,
  });

  double get totalReturns {
    return currentValue - investedAmount;
  }

  double get returnPercentage {
    if (investedAmount == 0) return 0.0;
    return (totalReturns / investedAmount) * 100;
  }

  InvestmentModel copyWith({
    String? id,
    String? name,
    String? type,
    double? investedAmount,
    double? currentValue,
    DateTime? date,
  }) {
    return InvestmentModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      investedAmount: investedAmount ?? this.investedAmount,
      currentValue: currentValue ?? this.currentValue,
      date: date ?? this.date,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'investedAmount': investedAmount,
      'currentValue': currentValue,
      'date': date.toIso8601String(),
    };
  }

  factory InvestmentModel.fromJson(Map<String, dynamic> json) {
    return InvestmentModel(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      investedAmount: (json['investedAmount'] as num).toDouble(),
      currentValue: (json['currentValue'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
    );
  }
}
