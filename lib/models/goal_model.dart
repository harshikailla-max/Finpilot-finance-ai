class GoalModel {
  final String id;
  final String title;
  final double targetAmount;
  final double currentAmount;
  final DateTime deadline;
  final String category;
  final DateTime createdAt;

  GoalModel({
    required this.id,
    required this.title,
    required this.targetAmount,
    required this.currentAmount,
    required this.deadline,
    required this.category,
    required this.createdAt,
  });

  double get progressPercentage {
    if (targetAmount == 0) return 0.0;
    return (currentAmount / targetAmount).clamp(0.0, 1.0);
  }

  double get remainingAmount {
    final diff = targetAmount - currentAmount;
    return diff > 0 ? diff : 0.0;
  }

  int get daysRemaining {
    final diff = deadline.difference(DateTime.now()).inDays;
    return diff > 0 ? diff : 0;
  }

  double get monthlyAmountRequired {
    final days = daysRemaining;
    if (days <= 0 || remainingAmount <= 0) return 0.0;
    final months = (days / 30.4).clamp(0.1, double.infinity);
    return remainingAmount / months;
  }

  GoalModel copyWith({
    String? id,
    String? title,
    double? targetAmount,
    double? currentAmount,
    DateTime? deadline,
    String? category,
    DateTime? createdAt,
  }) {
    return GoalModel(
      id: id ?? this.id,
      title: title ?? this.title,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      deadline: deadline ?? this.deadline,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
      'deadline': deadline.toIso8601String(),
      'category': category,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory GoalModel.fromJson(Map<String, dynamic> json) {
    return GoalModel(
      id: json['id'] as String,
      title: json['title'] as String,
      targetAmount: (json['targetAmount'] as num).toDouble(),
      currentAmount: (json['currentAmount'] as num).toDouble(),
      deadline: DateTime.parse(json['deadline'] as String),
      category: json['category'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
