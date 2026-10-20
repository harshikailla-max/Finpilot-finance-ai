import '../../models/investment_command_models.dart';
import '../../models/investment_model.dart';
import 'asset_allocation_service.dart';

class PortfolioHealthService {
  /// Evaluates current investment holdings against optimal asset allocation
  static PortfolioHealthAudit auditPortfolio({
    required List<InvestmentModel> holdings,
    required RiskProfileType userRisk,
    required bool isEmergencyFundHealthy,
    required bool hasHighCostDebt,
  }) {
    double equityTotal = 0.0;
    double debtTotal = 0.0;
    double goldTotal = 0.0;
    double liquidTotal = 0.0;
    double otherTotal = 0.0;

    for (final item in holdings) {
      final String typeLower = item.type.toLowerCase();
      final String nameLower = item.name.toLowerCase();
      final double val = item.currentValue > 0
          ? item.currentValue
          : item.investedAmount;

      if (typeLower.contains('gold') ||
          nameLower.contains('sgb') ||
          nameLower.contains('gold')) {
        goldTotal += val;
      } else if (typeLower.contains('liquid') ||
          typeLower.contains('cash') ||
          nameLower.contains('liquid')) {
        liquidTotal += val;
      } else if (typeLower.contains('ppf') ||
          typeLower.contains('epf') ||
          typeLower.contains('debt') ||
          typeLower.contains('bond') ||
          typeLower.contains('deposit') ||
          typeLower.contains('fd')) {
        debtTotal += val;
      } else if (typeLower.contains('equity') ||
          typeLower.contains('stock') ||
          typeLower.contains('index') ||
          typeLower.contains('mutual fund') ||
          typeLower.contains('fund')) {
        equityTotal += val;
      } else {
        otherTotal += val;
      }
    }

    final double totalCorpus =
        equityTotal + debtTotal + goldTotal + liquidTotal + otherTotal;

    // Current allocation percentages
    Map<String, double> currentAllocation;
    if (totalCorpus > 0) {
      currentAllocation = {
        'Equity': double.parse(
          (equityTotal / totalCorpus * 100).toStringAsFixed(1),
        ),
        'Debt': double.parse(
          (debtTotal / totalCorpus * 100).toStringAsFixed(1),
        ),
        'Liquid': double.parse(
          (liquidTotal / totalCorpus * 100).toStringAsFixed(1),
        ),
        'Gold': double.parse(
          (goldTotal / totalCorpus * 100).toStringAsFixed(1),
        ),
        'Other': double.parse(
          (otherTotal / totalCorpus * 100).toStringAsFixed(1),
        ),
      };
    } else {
      currentAllocation = const {
        'Equity': 50.0,
        'Debt': 30.0,
        'Liquid': 10.0,
        'Gold': 10.0,
        'Other': 0.0,
      };
    }

    // Target allocation based on 5-year balanced horizon
    final targetResult = AssetAllocationService.determineAllocation(
      goalCategory: 'Wealth Creation',
      timeHorizonYears: 5.0,
      riskProfile: userRisk,
      isEmergencyFundHealthy: isEmergencyFundHealthy,
      hasHighCostDebt: hasHighCostDebt,
    );
    final targetAllocation = targetResult.allocationPercentages;

    // Calculate drift (Current - Target)
    final Map<String, double> drift = {};
    bool needsRebalancing = false;
    currentAllocation.forEach((key, currVal) {
      final targetVal = targetAllocation[key] ?? 0.0;
      final diff = double.parse((currVal - targetVal).toStringAsFixed(1));
      drift[key] = diff;
      if (diff.abs() >= 10.0) {
        needsRebalancing = true;
      }
    });

    // Score dimensions (0-100)
    int diversificationScore = 80;
    int riskScore = 85;
    int goalAlignmentScore = 80;
    int liquidityScore = isEmergencyFundHealthy ? 85 : 55;
    int concentrationScore = 80;
    const int taxEfficiencyScore = 78;
    const int costAwarenessScore = 82;

    // Penalize if single asset is > 50%
    if (currentAllocation.values.any((v) => v > 65.0)) {
      concentrationScore = 50;
      diversificationScore -= 20;
    }

    // Check drift impact on risk score
    final equityDrift = drift['Equity'] ?? 0.0;
    if (equityDrift > 15.0) {
      riskScore -= 15;
    }

    final int overallScore =
        ((diversificationScore * 0.20) +
                (riskScore * 0.20) +
                (goalAlignmentScore * 0.15) +
                (liquidityScore * 0.15) +
                (concentrationScore * 0.15) +
                (taxEfficiencyScore * 0.075) +
                (costAwarenessScore * 0.075))
            .round()
            .clamp(20, 98);

    final List<String> strengths = [];
    final List<String> risks = [];
    final List<String> actions = [];

    if (currentAllocation['Equity']! > 30.0) {
      strengths.add(
        'Substantial equity foundation capturing long-term compounding growth.',
      );
    }
    if (currentAllocation['Debt']! >= 20.0) {
      strengths.add(
        'Fixed income component provides defensive downside volatility protection.',
      );
    }
    if (currentAllocation['Gold']! > 0.0) {
      strengths.add(
        'Hedge against geopolitical tail-risks and currency depreciation via gold allocation.',
      );
    }
    if (strengths.isEmpty) {
      strengths.add(
        'Initial asset base established with positive historical tracking.',
      );
    }

    if (needsRebalancing) {
      risks.add(
        'Asset drift detected: Your current equity/debt split deviates by >10% from your strategic target.',
      );
    }
    if (!isEmergencyFundHealthy) {
      risks.add(
        'Low defensive liquid reserves create risk of premature liquidation during market drawdowns.',
      );
    }
    if (concentrationScore < 70) {
      risks.add(
        'Single asset class concentration increases sensitivity to individual sector downturns.',
      );
    }
    if (risks.isEmpty) {
      risks.add(
        'Periodic market cycles could temporarily impact short-term portfolio valuation.',
      );
    }

    if (needsRebalancing) {
      actions.add(
        'Rebalance: Direct upcoming monthly SIP inflows into underweight asset classes (e.g. ${drift.entries.reduce((a, b) => a.value < b.value ? a : b).key}).',
      );
    } else {
      actions.add(
        'Maintain scheduled automated SIP allocations without interruption.',
      );
    }
    if (!isEmergencyFundHealthy) {
      actions.add(
        'Prioritize building 3 months of essential liquid emergency buffer.',
      );
    }
    actions.add(
      'Review portfolio asset distribution twice annually (January and July).',
    );

    return PortfolioHealthAudit(
      overallScore: overallScore,
      diversificationScore: diversificationScore,
      riskScore: riskScore,
      goalAlignmentScore: goalAlignmentScore,
      liquidityScore: liquidityScore,
      concentrationScore: concentrationScore,
      taxEfficiencyScore: taxEfficiencyScore,
      costAwarenessScore: costAwarenessScore,
      currentAllocation: currentAllocation,
      targetAllocation: targetAllocation,
      allocationDrift: drift,
      needsRebalancing: needsRebalancing,
      topStrengths: strengths,
      topRisks: risks,
      topActions: actions,
    );
  }
}
