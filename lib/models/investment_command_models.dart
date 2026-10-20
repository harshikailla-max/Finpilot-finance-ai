import 'package:flutter/material.dart';

/// Standard risk profiling categories
enum RiskProfileType {
  conservative,
  moderatelyConservative,
  moderate,
  moderatelyAggressive,
  aggressive,
}

extension RiskProfileTypeExt on RiskProfileType {
  String get label {
    switch (this) {
      case RiskProfileType.conservative:
        return 'Conservative';
      case RiskProfileType.moderatelyConservative:
        return 'Moderately Conservative';
      case RiskProfileType.moderate:
        return 'Moderate';
      case RiskProfileType.moderatelyAggressive:
        return 'Moderately Aggressive';
      case RiskProfileType.aggressive:
        return 'Aggressive';
    }
  }

  Color get color {
    switch (this) {
      case RiskProfileType.conservative:
        return const Color(0xFF2DD4A8);
      case RiskProfileType.moderatelyConservative:
        return const Color(0xFF4CC9F0);
      case RiskProfileType.moderate:
        return const Color(0xFFFFC857);
      case RiskProfileType.moderatelyAggressive:
        return const Color(0xFFFF9F1C);
      case RiskProfileType.aggressive:
        return const Color(0xFFFF6B6B);
    }
  }
}

/// Standard SEBI-style visual riskometer levels
enum RiskometerLevel {
  low,
  lowToModerate,
  moderate,
  moderatelyHigh,
  high,
  veryHigh,
}

extension RiskometerLevelExt on RiskometerLevel {
  String get label {
    switch (this) {
      case RiskometerLevel.low:
        return 'Low';
      case RiskometerLevel.lowToModerate:
        return 'Low to Moderate';
      case RiskometerLevel.moderate:
        return 'Moderate';
      case RiskometerLevel.moderatelyHigh:
        return 'Moderately High';
      case RiskometerLevel.high:
        return 'High';
      case RiskometerLevel.veryHigh:
        return 'Very High';
    }
  }

  Color get color {
    switch (this) {
      case RiskometerLevel.low:
        return const Color(0xFF2DD4A8);
      case RiskometerLevel.lowToModerate:
        return const Color(0xFF4CC9F0);
      case RiskometerLevel.moderate:
        return const Color(0xFFFFC857);
      case RiskometerLevel.moderatelyHigh:
        return const Color(0xFFFF9F1C);
      case RiskometerLevel.high:
        return const Color(0xFFFF6B81);
      case RiskometerLevel.veryHigh:
        return const Color(0xFFD90429);
    }
  }
}

/// Breakdown of distinct risk dimensions
class RiskScoreBreakdown {
  final int capacityScore; // 0-100: Objective financial ability to bear loss
  final int toleranceScore; // 0-100: Psychological comfort with volatility
  final int requirementScore; // 0-100: Return rate needed to reach goals
  final RiskProfileType profileType;
  final String explanation;

  const RiskScoreBreakdown({
    required this.capacityScore,
    required this.toleranceScore,
    required this.requirementScore,
    required this.profileType,
    required this.explanation,
  });
}

/// 9-point investment readiness report
class InvestmentReadinessReport {
  final int readinessScore; // 0-100
  final bool isEmergencyFundHealthy;
  final String emergencyFundStatusText;
  final bool isDebtManageable;
  final String debtStatusText;
  final double monthlySurplus;
  final double investmentCapacity;
  final List<InvestmentChecklistItem> checklist;

  const InvestmentReadinessReport({
    required this.readinessScore,
    required this.isEmergencyFundHealthy,
    required this.emergencyFundStatusText,
    required this.isDebtManageable,
    required this.debtStatusText,
    required this.monthlySurplus,
    required this.investmentCapacity,
    required this.checklist,
  });
}

class InvestmentChecklistItem {
  final String title;
  final bool isPassed;
  final String detail;

  const InvestmentChecklistItem({
    required this.title,
    required this.isPassed,
    required this.detail,
  });
}

/// 3 distinct strategy choices for any major financial goal
class StrategyOption {
  final String name; // Conservative, Balanced, Growth
  final int goalMatchPercentage;
  final RiskometerLevel riskLevel;
  final String timeHorizonLabel;
  final String liquidity;
  final double illustrativeReturnRate;
  final String volatilityDescription;
  final Map<String, double>
  assetAllocation; // e.g., {'Equity': 60, 'Debt': 30, ...}
  final String whyItFits;
  final String whyItMayNotFit;

  const StrategyOption({
    required this.name,
    required this.goalMatchPercentage,
    required this.riskLevel,
    required this.timeHorizonLabel,
    required this.liquidity,
    required this.illustrativeReturnRate,
    required this.volatilityDescription,
    required this.assetAllocation,
    required this.whyItFits,
    required this.whyItMayNotFit,
  });
}

/// Goal Feasibility Rating
enum GoalFeasibility { good, tight, atRisk }

extension GoalFeasibilityExt on GoalFeasibility {
  String get label {
    switch (this) {
      case GoalFeasibility.good:
        return 'GOOD';
      case GoalFeasibility.tight:
        return 'TIGHT';
      case GoalFeasibility.atRisk:
        return 'AT RISK';
    }
  }

  Color get color {
    switch (this) {
      case GoalFeasibility.good:
        return const Color(0xFF2DD4A8);
      case GoalFeasibility.tight:
        return const Color(0xFFFFC857);
      case GoalFeasibility.atRisk:
        return const Color(0xFFFF6B81);
    }
  }
}

/// Detailed Goal Analysis Report
class GoalInvestmentAnalysisReport {
  final String goalId;
  final String goalTitle;
  final double targetAmount;
  final double currentAmount;
  final double remainingAmount;
  final int monthsRemaining;
  final double monthlyCapacity;
  final double requiredMonthlyInvestment;
  final GoalFeasibility feasibility;
  final String detailedReasoning;
  final List<StrategyOption> strategies;
  final String deRiskingGuidance;

  const GoalInvestmentAnalysisReport({
    required this.goalId,
    required this.goalTitle,
    required this.targetAmount,
    required this.currentAmount,
    required this.remainingAmount,
    required this.monthsRemaining,
    required this.monthlyCapacity,
    required this.requiredMonthlyInvestment,
    required this.feasibility,
    required this.detailedReasoning,
    required this.strategies,
    required this.deRiskingGuidance,
  });
}

/// SIP and Lump Sum Milestone Calculation Results
class SipMilestone {
  final int year;
  final double totalInvested;
  final double estimatedCorpus;
  final double estimatedGain;

  const SipMilestone({
    required this.year,
    required this.totalInvested,
    required this.estimatedCorpus,
    required this.estimatedGain,
  });
}

class SipCalculationResult {
  final double monthlySip;
  final int durationYears;
  final double annualReturnRate;
  final double startingInvestment;
  final double totalInvested;
  final double estimatedGain;
  final double estimatedCorpus;
  final double conservativeCorpus; // at -3% rate
  final double optimisticCorpus; // at +3% rate
  final List<SipMilestone> milestones;

  const SipCalculationResult({
    required this.monthlySip,
    required this.durationYears,
    required this.annualReturnRate,
    required this.startingInvestment,
    required this.totalInvested,
    required this.estimatedGain,
    required this.estimatedCorpus,
    required this.conservativeCorpus,
    required this.optimisticCorpus,
    required this.milestones,
  });
}

class LumpSumCalculationResult {
  final double initialInvestment;
  final int durationYears;
  final double annualReturnRate;
  final double totalInvested;
  final double estimatedGain;
  final double estimatedCorpus;
  final double sipEquivalentMonthly; // What monthly SIP would yield same corpus

  const LumpSumCalculationResult({
    required this.initialInvestment,
    required this.durationYears,
    required this.annualReturnRate,
    required this.totalInvested,
    required this.estimatedGain,
    required this.estimatedCorpus,
    required this.sipEquivalentMonthly,
  });
}

class GoalSipRequirementResult {
  final double targetCorpus;
  final double currentCorpus;
  final int durationYears;
  final double annualReturnRate;
  final double requiredMonthlyInvestment;
  final double availableMonthlyCapacity;
  final double
  gap; // capacity - required (positive = surplus, negative = deficit)
  final bool isAchievable;
  final List<String> strategicAlternatives;

  const GoalSipRequirementResult({
    required this.targetCorpus,
    required this.currentCorpus,
    required this.durationYears,
    required this.annualReturnRate,
    required this.requiredMonthlyInvestment,
    required this.availableMonthlyCapacity,
    required this.gap,
    required this.isAchievable,
    required this.strategicAlternatives,
  });
}

/// Tax Planning Models
enum TaxRegime { oldRegime, newRegime }

class TaxDeductionCategory {
  final String code; // e.g., '80C', '80D', '80CCD(1B)'
  final String title;
  final double maxAllowedLimit;
  final double currentUtilized;
  final List<String> eligibleInstruments;
  final String lockInPeriod;
  final RiskometerLevel riskLevel;
  final String taxTreatment;

  double get remainingPotential =>
      (maxAllowedLimit - currentUtilized).clamp(0.0, maxAllowedLimit);

  const TaxDeductionCategory({
    required this.code,
    required this.title,
    required this.maxAllowedLimit,
    required this.currentUtilized,
    required this.eligibleInstruments,
    required this.lockInPeriod,
    required this.riskLevel,
    required this.taxTreatment,
  });
}

class TaxRegimeComparisonReport {
  final double annualGrossIncome;
  final double oldRegimeTotalDeductions;
  final double oldRegimeTaxableIncome;
  final double oldRegimeEstimatedTax;
  final double newRegimeTaxableIncome;
  final double newRegimeEstimatedTax;
  final TaxRegime recommendedRegime;
  final double taxSavingsWithRecommendation;
  final List<TaxDeductionCategory> deductionBreakdown;
  final String summaryAdvice;

  const TaxRegimeComparisonReport({
    required this.annualGrossIncome,
    required this.oldRegimeTotalDeductions,
    required this.oldRegimeTaxableIncome,
    required this.oldRegimeEstimatedTax,
    required this.newRegimeTaxableIncome,
    required this.newRegimeEstimatedTax,
    required this.recommendedRegime,
    required this.taxSavingsWithRecommendation,
    required this.deductionBreakdown,
    required this.summaryAdvice,
  });
}

/// Retirement Command Center Report
class RetirementPlanReport {
  final int currentAge;
  final int retirementAge;
  final int lifeExpectancy;
  final double currentMonthlyExpense;
  final double assumedInflationRate;
  final double assumedPreRetirementReturn;
  final double assumedPostRetirementReturn;
  final double existingInvestments;
  final double currentMonthlyInvestment;

  final double projectedMonthlyExpenseAtRetirement;
  final double requiredRetirementCorpus;
  final double projectedExistingInvestmentsAtRetirement;
  final double corpusGap;
  final double requiredMonthlyInvestment;
  final double monthlyCapacityShortfallOrSurplus;
  final bool isOnTrack;
  final List<String> milestoneActionPoints;

  const RetirementPlanReport({
    required this.currentAge,
    required this.retirementAge,
    required this.lifeExpectancy,
    required this.currentMonthlyExpense,
    required this.assumedInflationRate,
    required this.assumedPreRetirementReturn,
    required this.assumedPostRetirementReturn,
    required this.existingInvestments,
    required this.currentMonthlyInvestment,
    required this.projectedMonthlyExpenseAtRetirement,
    required this.requiredRetirementCorpus,
    required this.projectedExistingInvestmentsAtRetirement,
    required this.corpusGap,
    required this.requiredMonthlyInvestment,
    required this.monthlyCapacityShortfallOrSurplus,
    required this.isOnTrack,
    required this.milestoneActionPoints,
  });
}

/// Debt vs Investment Trade-off Report
class DebtVsInvestScenario {
  final String name; // Repay Debt, Invest in Market, 50-50 Split
  final String description;
  final double totalDebtPaidInPeriod;
  final double totalInterestSaved;
  final double totalWealthAccumulated;
  final double netFinancialBenefit;
  final String tradeOffNote;

  const DebtVsInvestScenario({
    required this.name,
    required this.description,
    required this.totalDebtPaidInPeriod,
    required this.totalInterestSaved,
    required this.totalWealthAccumulated,
    required this.netFinancialBenefit,
    required this.tradeOffNote,
  });
}

class DebtVsInvestReport {
  final double outstandingLoan;
  final double loanInterestRate;
  final double currentEmi;
  final double monthlyCapacity;
  final double expectedInvestmentReturn;
  final DebtVsInvestScenario scenarioRepay;
  final DebtVsInvestScenario scenarioInvest;
  final DebtVsInvestScenario scenarioSplit;
  final String bestChoiceRecommendation;
  final String reasoningWhy;

  const DebtVsInvestReport({
    required this.outstandingLoan,
    required this.loanInterestRate,
    required this.currentEmi,
    required this.monthlyCapacity,
    required this.expectedInvestmentReturn,
    required this.scenarioRepay,
    required this.scenarioInvest,
    required this.scenarioSplit,
    required this.bestChoiceRecommendation,
    required this.reasoningWhy,
  });
}

/// Portfolio Health & Rebalancing Audit
class PortfolioHealthAudit {
  final int overallScore; // 0-100
  final int diversificationScore;
  final int riskScore;
  final int goalAlignmentScore;
  final int liquidityScore;
  final int concentrationScore;
  final int taxEfficiencyScore;
  final int costAwarenessScore;

  final Map<String, double> currentAllocation; // Percentages
  final Map<String, double> targetAllocation; // Percentages
  final Map<String, double> allocationDrift; // Current - Target

  final bool needsRebalancing;
  final List<String> topStrengths;
  final List<String> topRisks;
  final List<String> topActions;

  const PortfolioHealthAudit({
    required this.overallScore,
    required this.diversificationScore,
    required this.riskScore,
    required this.goalAlignmentScore,
    required this.liquidityScore,
    required this.concentrationScore,
    required this.taxEfficiencyScore,
    required this.costAwarenessScore,
    required this.currentAllocation,
    required this.targetAllocation,
    required this.allocationDrift,
    required this.needsRebalancing,
    required this.topStrengths,
    required this.topRisks,
    required this.topActions,
  });
}

/// Investment Category Education
class AssetCategoryEducation {
  final String name;
  final String categoryGroup; // Equity, Debt, Hybrid, Commodities, Retirement
  final RiskometerLevel risk;
  final String purpose;
  final String suitableHorizon;
  final String liquidity;
  final String potentialRole;
  final List<String> importantRisks;
  final String taxConsiderations;
  final IconData icon;

  const AssetCategoryEducation({
    required this.name,
    required this.categoryGroup,
    required this.risk,
    required this.purpose,
    required this.suitableHorizon,
    required this.liquidity,
    required this.potentialRole,
    required this.importantRisks,
    required this.taxConsiderations,
    required this.icon,
  });
}

/// Market Academy Topic
class MarketTopic {
  final String title;
  final String summary;
  final String keyTakeaway;
  final String example;
  final IconData icon;

  const MarketTopic({
    required this.title,
    required this.summary,
    required this.keyTakeaway,
    required this.example,
    required this.icon,
  });
}
