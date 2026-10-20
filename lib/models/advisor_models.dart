enum AdvisorIntent {
  generalFinance,
  affordability,
  purchase,
  goal,
  saving,
  budget,
  expense,
  investment,
  portfolio,
  debt,
  emi,
  retirement,
  tax,
  emergencyFund,
  cashFlow,
  financialHealth,
  futureSimulation,
  goalOptimization,
  risk,
  insurance,
  travel,
  home,
  car,
  education,
}

enum DecisionVerdict { safe, good, possible, tight, notRecommended }

enum AdvisorCardType {
  none,
  affordability,
  goalOptimization,
  financialXRay,
  whatIf,
  investment,
  financialDNA,
  safetyAlert,
}

class MoneyMove {
  final String id;
  final String title;
  final String category;
  final String reason;
  final String impact;
  final String actionLabel;
  final String? actionRoute;

  const MoneyMove({
    required this.id,
    required this.title,
    required this.category,
    required this.reason,
    required this.impact,
    required this.actionLabel,
    this.actionRoute,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'category': category,
    'reason': reason,
    'impact': impact,
    'actionLabel': actionLabel,
    'actionRoute': actionRoute,
  };

  factory MoneyMove.fromJson(Map<String, dynamic> json) => MoneyMove(
    id: json['id'] as String,
    title: json['title'] as String,
    category: json['category'] as String,
    reason: json['reason'] as String,
    impact: json['impact'] as String,
    actionLabel: json['actionLabel'] as String,
    actionRoute: json['actionRoute'] as String?,
  );
}

class XRayPillarScore {
  final String name;
  final double score; // 0 to 100
  final String status;
  final String description;
  final String calculationDetails;

  const XRayPillarScore({
    required this.name,
    required this.score,
    required this.status,
    required this.description,
    required this.calculationDetails,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'score': score,
    'status': status,
    'description': description,
    'calculationDetails': calculationDetails,
  };

  factory XRayPillarScore.fromJson(Map<String, dynamic> json) =>
      XRayPillarScore(
        name: json['name'] as String,
        score: (json['score'] as num).toDouble(),
        status: json['status'] as String,
        description: json['description'] as String,
        calculationDetails: json['calculationDetails'] as String,
      );
}

class FinancialXRayReport {
  final double overallScore;
  final String rating;
  final String summary;
  final List<XRayPillarScore> pillars;
  final List<String> topStrengths;
  final List<String> priorityVulnerabilities;

  const FinancialXRayReport({
    required this.overallScore,
    required this.rating,
    required this.summary,
    required this.pillars,
    required this.topStrengths,
    required this.priorityVulnerabilities,
  });

  Map<String, dynamic> toJson() => {
    'overallScore': overallScore,
    'rating': rating,
    'summary': summary,
    'pillars': pillars.map((p) => p.toJson()).toList(),
    'topStrengths': topStrengths,
    'priorityVulnerabilities': priorityVulnerabilities,
  };

  factory FinancialXRayReport.fromJson(Map<String, dynamic> json) =>
      FinancialXRayReport(
        overallScore: (json['overallScore'] as num).toDouble(),
        rating: json['rating'] as String,
        summary: json['summary'] as String,
        pillars: (json['pillars'] as List<dynamic>)
            .map((p) => XRayPillarScore.fromJson(p as Map<String, dynamic>))
            .toList(),
        topStrengths: List<String>.from(json['topStrengths'] as List),
        priorityVulnerabilities: List<String>.from(
          json['priorityVulnerabilities'] as List,
        ),
      );
}

class AffordabilityAnalysis {
  final String product;
  final double price;
  final DecisionVerdict verdict;
  final double affordabilityScore; // 0 to 100
  final double monthlyImpact;
  final double budgetImpactPercentage;
  final double emergencyFundImpactMonths;
  final double remainingEmergencyMonths;
  final String goalImpact;
  final String reasoning;
  final String alternative;
  final String recommendedAction;

  const AffordabilityAnalysis({
    required this.product,
    required this.price,
    required this.verdict,
    required this.affordabilityScore,
    required this.monthlyImpact,
    required this.budgetImpactPercentage,
    required this.emergencyFundImpactMonths,
    required this.remainingEmergencyMonths,
    required this.goalImpact,
    required this.reasoning,
    required this.alternative,
    required this.recommendedAction,
  });

  Map<String, dynamic> toJson() => {
    'product': product,
    'price': price,
    'verdict': verdict.name,
    'affordabilityScore': affordabilityScore,
    'monthlyImpact': monthlyImpact,
    'budgetImpactPercentage': budgetImpactPercentage,
    'emergencyFundImpactMonths': emergencyFundImpactMonths,
    'remainingEmergencyMonths': remainingEmergencyMonths,
    'goalImpact': goalImpact,
    'reasoning': reasoning,
    'alternative': alternative,
    'recommendedAction': recommendedAction,
  };

  factory AffordabilityAnalysis.fromJson(Map<String, dynamic> json) =>
      AffordabilityAnalysis(
        product: json['product'] as String,
        price: (json['price'] as num).toDouble(),
        verdict: DecisionVerdict.values.byName(json['verdict'] as String),
        affordabilityScore: (json['affordabilityScore'] as num).toDouble(),
        monthlyImpact: (json['monthlyImpact'] as num).toDouble(),
        budgetImpactPercentage: (json['budgetImpactPercentage'] as num)
            .toDouble(),
        emergencyFundImpactMonths: (json['emergencyFundImpactMonths'] as num)
            .toDouble(),
        remainingEmergencyMonths: (json['remainingEmergencyMonths'] as num)
            .toDouble(),
        goalImpact: json['goalImpact'] as String,
        reasoning: json['reasoning'] as String,
        alternative: json['alternative'] as String,
        recommendedAction: json['recommendedAction'] as String,
      );
}

class GoalRankItem {
  final String goalId;
  final String title;
  final double targetAmount;
  final double currentAmount;
  final double monthlyRequired;
  final double fundingGap;
  final int priorityRank;
  final bool isConflict;
  final String reason;

  const GoalRankItem({
    required this.goalId,
    required this.title,
    required this.targetAmount,
    required this.currentAmount,
    required this.monthlyRequired,
    required this.fundingGap,
    required this.priorityRank,
    required this.isConflict,
    required this.reason,
  });

  Map<String, dynamic> toJson() => {
    'goalId': goalId,
    'title': title,
    'targetAmount': targetAmount,
    'currentAmount': currentAmount,
    'monthlyRequired': monthlyRequired,
    'fundingGap': fundingGap,
    'priorityRank': priorityRank,
    'isConflict': isConflict,
    'reason': reason,
  };

  factory GoalRankItem.fromJson(Map<String, dynamic> json) => GoalRankItem(
    goalId: json['goalId'] as String,
    title: json['title'] as String,
    targetAmount: (json['targetAmount'] as num).toDouble(),
    currentAmount: (json['currentAmount'] as num).toDouble(),
    monthlyRequired: (json['monthlyRequired'] as num).toDouble(),
    fundingGap: (json['fundingGap'] as num).toDouble(),
    priorityRank: json['priorityRank'] as int,
    isConflict: json['isConflict'] as bool,
    reason: json['reason'] as String,
  );
}

class GoalOptimizationResult {
  final List<GoalRankItem> rankedGoals;
  final String bestNextGoalTitle;
  final String bestNextGoalReason;
  final double totalMonthlyRequired;
  final double availableMonthlySurplus;
  final double monthlyDeficitOrSurplus;
  final String strategicAdvice;

  const GoalOptimizationResult({
    required this.rankedGoals,
    required this.bestNextGoalTitle,
    required this.bestNextGoalReason,
    required this.totalMonthlyRequired,
    required this.availableMonthlySurplus,
    required this.monthlyDeficitOrSurplus,
    required this.strategicAdvice,
  });

  Map<String, dynamic> toJson() => {
    'rankedGoals': rankedGoals.map((g) => g.toJson()).toList(),
    'bestNextGoalTitle': bestNextGoalTitle,
    'bestNextGoalReason': bestNextGoalReason,
    'totalMonthlyRequired': totalMonthlyRequired,
    'availableMonthlySurplus': availableMonthlySurplus,
    'monthlyDeficitOrSurplus': monthlyDeficitOrSurplus,
    'strategicAdvice': strategicAdvice,
  };

  factory GoalOptimizationResult.fromJson(Map<String, dynamic> json) =>
      GoalOptimizationResult(
        rankedGoals: (json['rankedGoals'] as List<dynamic>)
            .map((g) => GoalRankItem.fromJson(g as Map<String, dynamic>))
            .toList(),
        bestNextGoalTitle: json['bestNextGoalTitle'] as String,
        bestNextGoalReason: json['bestNextGoalReason'] as String,
        totalMonthlyRequired: (json['totalMonthlyRequired'] as num).toDouble(),
        availableMonthlySurplus: (json['availableMonthlySurplus'] as num)
            .toDouble(),
        monthlyDeficitOrSurplus: (json['monthlyDeficitOrSurplus'] as num)
            .toDouble(),
        strategicAdvice: json['strategicAdvice'] as String,
      );
}

class WhatIfScenarioResult {
  final String scenarioTitle;
  final double baselineMonthlySavings;
  final double projectedMonthlySavings;
  final double monthlyDelta;
  final double baselineSavingsRate;
  final double projectedSavingsRate;
  final String goalImpactSummary;
  final String safetyRunwaySummary;
  final String strategicInsight;

  const WhatIfScenarioResult({
    required this.scenarioTitle,
    required this.baselineMonthlySavings,
    required this.projectedMonthlySavings,
    required this.monthlyDelta,
    required this.baselineSavingsRate,
    required this.projectedSavingsRate,
    required this.goalImpactSummary,
    required this.safetyRunwaySummary,
    required this.strategicInsight,
  });

  Map<String, dynamic> toJson() => {
    'scenarioTitle': scenarioTitle,
    'baselineMonthlySavings': baselineMonthlySavings,
    'projectedMonthlySavings': projectedMonthlySavings,
    'monthlyDelta': monthlyDelta,
    'baselineSavingsRate': baselineSavingsRate,
    'projectedSavingsRate': projectedSavingsRate,
    'goalImpactSummary': goalImpactSummary,
    'safetyRunwaySummary': safetyRunwaySummary,
    'strategicInsight': strategicInsight,
  };

  factory WhatIfScenarioResult.fromJson(Map<String, dynamic> json) =>
      WhatIfScenarioResult(
        scenarioTitle: json['scenarioTitle'] as String,
        baselineMonthlySavings: (json['baselineMonthlySavings'] as num)
            .toDouble(),
        projectedMonthlySavings: (json['projectedMonthlySavings'] as num)
            .toDouble(),
        monthlyDelta: (json['monthlyDelta'] as num).toDouble(),
        baselineSavingsRate: (json['baselineSavingsRate'] as num).toDouble(),
        projectedSavingsRate: (json['projectedSavingsRate'] as num).toDouble(),
        goalImpactSummary: json['goalImpactSummary'] as String,
        safetyRunwaySummary: json['safetyRunwaySummary'] as String,
        strategicInsight: json['strategicInsight'] as String,
      );
}

class FinancialDNAProfile {
  final String archetype; // Planner, Saver, Spender, Investor, Risk Taker
  final String secondaryArchetype;
  final double financialDisciplineScore; // 0-100
  final List<String> evidencePoints;
  final String coreTrait;
  final String growthOpportunity;

  const FinancialDNAProfile({
    required this.archetype,
    required this.secondaryArchetype,
    required this.financialDisciplineScore,
    required this.evidencePoints,
    required this.coreTrait,
    required this.growthOpportunity,
  });

  Map<String, dynamic> toJson() => {
    'archetype': archetype,
    'secondaryArchetype': secondaryArchetype,
    'financialDisciplineScore': financialDisciplineScore,
    'evidencePoints': evidencePoints,
    'coreTrait': coreTrait,
    'growthOpportunity': growthOpportunity,
  };

  factory FinancialDNAProfile.fromJson(Map<String, dynamic> json) =>
      FinancialDNAProfile(
        archetype: json['archetype'] as String,
        secondaryArchetype: json['secondaryArchetype'] as String,
        financialDisciplineScore: (json['financialDisciplineScore'] as num)
            .toDouble(),
        evidencePoints: List<String>.from(json['evidencePoints'] as List),
        coreTrait: json['coreTrait'] as String,
        growthOpportunity: json['growthOpportunity'] as String,
      );
}

class AdvisorResponse {
  final String id;
  final String userQuery;
  final AdvisorIntent intent;
  final String verdict;
  final String currentPosition;
  final String calculation;
  final String reasoning;
  final String risks;
  final String recommendation;
  final String alternatives;
  final String nextAction;
  final String? actionRoute;
  final AdvisorCardType cardType;
  final Map<String, dynamic>? cardPayload;
  final DateTime timestamp;

  const AdvisorResponse({
    required this.id,
    required this.userQuery,
    required this.intent,
    required this.verdict,
    required this.currentPosition,
    required this.calculation,
    required this.reasoning,
    required this.risks,
    required this.recommendation,
    required this.alternatives,
    required this.nextAction,
    this.actionRoute,
    this.cardType = AdvisorCardType.none,
    this.cardPayload,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'userQuery': userQuery,
    'intent': intent.name,
    'verdict': verdict,
    'currentPosition': currentPosition,
    'calculation': calculation,
    'reasoning': reasoning,
    'risks': risks,
    'recommendation': recommendation,
    'alternatives': alternatives,
    'nextAction': nextAction,
    'actionRoute': actionRoute,
    'cardType': cardType.name,
    'cardPayload': cardPayload,
    'timestamp': timestamp.toIso8601String(),
  };

  factory AdvisorResponse.fromJson(Map<String, dynamic> json) =>
      AdvisorResponse(
        id: json['id'] as String,
        userQuery: json['userQuery'] as String,
        intent: AdvisorIntent.values.byName(json['intent'] as String),
        verdict: json['verdict'] as String,
        currentPosition: json['currentPosition'] as String,
        calculation: json['calculation'] as String,
        reasoning: json['reasoning'] as String,
        risks: json['risks'] as String,
        recommendation: json['recommendation'] as String,
        alternatives: json['alternatives'] as String,
        nextAction: json['nextAction'] as String,
        actionRoute: json['actionRoute'] as String?,
        cardType: json['cardType'] != null
            ? AdvisorCardType.values.byName(json['cardType'] as String)
            : AdvisorCardType.none,
        cardPayload: json['cardPayload'] as Map<String, dynamic>?,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}
