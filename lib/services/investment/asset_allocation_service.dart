import '../../models/investment_command_models.dart';

class AssetAllocationResult {
  final Map<String, double> allocationPercentages;
  final String horizonCategory; // Short-term, Medium-term, Long-term
  final String strategicRationale;
  final String illustrativeNotice;

  const AssetAllocationResult({
    required this.allocationPercentages,
    required this.horizonCategory,
    required this.strategicRationale,
    this.illustrativeNotice = 'Illustrative allocation. Does not constitute personal portfolio management. Actual allocation should be calibrated to individual risk tolerance and tax status.',
  });
}

class AssetAllocationService {
  /// Determines an explainable, goal-first asset allocation
  static AssetAllocationResult determineAllocation({
    required String goalCategory,
    required double timeHorizonYears,
    required RiskProfileType riskProfile,
    required bool isEmergencyFundHealthy,
    required bool hasHighCostDebt,
    double monthlyCapacity = 0.0,
    bool requiresImmediateLiquidity = false,
  }) {
    String horizonCategory;
    double equity = 0.0;
    double debt = 0.0;
    double liquid = 0.0;
    double gold = 0.0;
    double other = 0.0;
    final List<String> rationalePoints = [];

    // Short-term: < 2 years
    if (timeHorizonYears < 2.0 ||
        requiresImmediateLiquidity ||
        goalCategory.toLowerCase().contains('emergency')) {
      horizonCategory = 'Short-Term (< 2 Years)';
      equity = 0.0;
      debt = 55.0;
      liquid = 40.0;
      gold = 5.0;
      other = 0.0;
      rationalePoints.add(
        'For horizons under 24 months, zero equity is recommended to avoid capital drawdown risk right before withdrawal.',
      );
      rationalePoints.add(
        'High allocation to liquid funds and ultra-short term debt ensures capital preservation and immediate access.',
      );
    }
    // Medium-term: 2 to 5 years
    else if (timeHorizonYears <= 5.0) {
      horizonCategory = 'Medium-Term (2 - 5 Years)';
      switch (riskProfile) {
        case RiskProfileType.conservative:
        case RiskProfileType.moderatelyConservative:
          equity = 25.0;
          debt = 50.0;
          liquid = 15.0;
          gold = 10.0;
          break;
        case RiskProfileType.moderate:
          equity = 45.0;
          debt = 35.0;
          liquid = 10.0;
          gold = 10.0;
          break;
        case RiskProfileType.moderatelyAggressive:
        case RiskProfileType.aggressive:
          equity = 55.0;
          debt = 30.0;
          liquid = 10.0;
          gold = 5.0;
          break;
      }
      rationalePoints.add(
        'Medium-term horizon balances equity growth compounding with debt ballast to dampen market swings.',
      );
    }
    // Long-term: > 5 years (Retirement, Wealth Creation, Children Education, Home)
    else {
      horizonCategory = 'Long-Term (5+ Years)';
      switch (riskProfile) {
        case RiskProfileType.conservative:
          equity = 45.0;
          debt = 40.0;
          liquid = 5.0;
          gold = 10.0;
          break;
        case RiskProfileType.moderatelyConservative:
          equity = 55.0;
          debt = 30.0;
          liquid = 5.0;
          gold = 10.0;
          break;
        case RiskProfileType.moderate:
          equity = 65.0;
          debt = 20.0;
          liquid = 5.0;
          gold = 10.0;
          break;
        case RiskProfileType.moderatelyAggressive:
          equity = 75.0;
          debt = 15.0;
          liquid = 5.0;
          gold = 5.0;
          break;
        case RiskProfileType.aggressive:
          equity = 80.0;
          debt = 10.0;
          liquid = 5.0;
          gold = 5.0;
          break;
      }
      rationalePoints.add(
        'Extended horizon (>5 years) provides sufficient recovery time to ride out business cycles and benefit from compounding.',
      );
    }

    // Adjustments for Emergency Reserve weakness
    if (!isEmergencyFundHealthy && liquid < 20.0) {
      final double delta = 20.0 - liquid;
      liquid = 20.0;
      equity = (equity - (delta * 0.7)).clamp(0.0, 100.0);
      debt = (debt - (delta * 0.3)).clamp(0.0, 100.0);
      rationalePoints.add(
        'Emergency reserve is incomplete; increased liquid buffer by ${delta.toStringAsFixed(0)}% to defend against unplanned shocks.',
      );
    }

    // Adjustments for high-interest debt
    if (hasHighCostDebt) {
      rationalePoints.add(
        'Notice: High-cost credit card/personal loan debt should take priority over non-tax-advantaged market investments.',
      );
    }

    // Normalize map to 100%
    final double total = equity + debt + liquid + gold + other;
    final Map<String, double> normalized = {
      'Equity': double.parse((equity / total * 100).toStringAsFixed(1)),
      'Debt': double.parse((debt / total * 100).toStringAsFixed(1)),
      'Liquid': double.parse((liquid / total * 100).toStringAsFixed(1)),
      'Gold': double.parse((gold / total * 100).toStringAsFixed(1)),
      'Other': double.parse((other / total * 100).toStringAsFixed(1)),
    };

    return AssetAllocationResult(
      allocationPercentages: normalized,
      horizonCategory: horizonCategory,
      strategicRationale: rationalePoints.join(' '),
    );
  }
}
