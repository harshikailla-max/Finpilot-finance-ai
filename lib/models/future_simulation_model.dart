class FutureSimulationModel {
  final double monthlyIncome;
  final double monthlyExpenses;
  final double currentSavings;
  final double incomeGrowth; // percentage (e.g. 5 for 5%)
  final double expenseGrowth; // percentage
  final int durationMonths;
  final String scenarioMode; // Conservative, Balanced, Aggressive

  FutureSimulationModel({
    required this.monthlyIncome,
    required this.monthlyExpenses,
    required this.currentSavings,
    required this.incomeGrowth,
    required this.expenseGrowth,
    required this.durationMonths,
    required this.scenarioMode,
  });

  Map<String, dynamic> toJson() {
    return {
      'monthlyIncome': monthlyIncome,
      'monthlyExpenses': monthlyExpenses,
      'currentSavings': currentSavings,
      'incomeGrowth': incomeGrowth,
      'expenseGrowth': expenseGrowth,
      'durationMonths': durationMonths,
      'scenarioMode': scenarioMode,
    };
  }

  factory FutureSimulationModel.fromJson(Map<String, dynamic> json) {
    return FutureSimulationModel(
      monthlyIncome: (json['monthlyIncome'] as num).toDouble(),
      monthlyExpenses: (json['monthlyExpenses'] as num).toDouble(),
      currentSavings: (json['currentSavings'] as num).toDouble(),
      incomeGrowth: (json['incomeGrowth'] as num).toDouble(),
      expenseGrowth: (json['expenseGrowth'] as num).toDouble(),
      durationMonths: json['durationMonths'] as int,
      scenarioMode: json['scenarioMode'] as String,
    );
  }
}

class SimulationPoint {
  final int month;
  final double balance;

  SimulationPoint({required this.month, required this.balance});
}
