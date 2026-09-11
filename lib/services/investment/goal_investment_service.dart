import '../../models/goal_model.dart';
import '../../models/investment_command_models.dart';
import '../../utils/currency_formatter.dart';
import 'investment_calculation_service.dart';

class PresetGoalTemplate {
  final String title;
  final String category;
  final double defaultTarget;
  final int defaultMonths;
  final String iconName;

  const PresetGoalTemplate({
    required this.title,
    required this.category,
    required this.defaultTarget,
    required this.defaultMonths,
    required this.iconName,
  });
}

class GoalInvestmentService {
  /// Preset goal templates for instant goal planning
  static List<PresetGoalTemplate> get presetGoals => const [
        PresetGoalTemplate(
          title: 'Emergency Fund',
          category: 'Emergency Fund',
          defaultTarget: 250000,
          defaultMonths: 12,
          iconName: 'security',
        ),
        PresetGoalTemplate(
          title: 'Car Purchase',
          category: 'Vehicle',
          defaultTarget: 800000,
          defaultMonths: 36,
          iconName: 'directions_car',
        ),
        PresetGoalTemplate(
          title: 'Bike Upgrade',
          category: 'Vehicle',
          defaultTarget: 180000,
          defaultMonths: 18,
          iconName: 'two_wheeler',
        ),
        PresetGoalTemplate(
          title: 'Higher Education / MBA',
          category: 'Education',
          defaultTarget: 1500000,
          defaultMonths: 48,
          iconName: 'school',
        ),
        PresetGoalTemplate(
          title: 'Dream Wedding',
          category: 'Marriage',
          defaultTarget: 1000000,
          defaultMonths: 30,
          iconName: 'favorite',
        ),
        PresetGoalTemplate(
          title: 'International Vacation',
          category: 'Travel',
          defaultTarget: 250000,
          defaultMonths: 14,
          iconName: 'flight_takeoff',
        ),
        PresetGoalTemplate(
          title: 'Home Down Payment',
          category: 'Home',
          defaultTarget: 2500000,
          defaultMonths: 60,
          iconName: 'home',
        ),
        PresetGoalTemplate(
          title: 'Retirement Nest Egg',
          category: 'Retirement',
          defaultTarget: 20000000,
          defaultMonths: 240,
          iconName: 'elderly',
        ),
        PresetGoalTemplate(
          title: 'Wealth Creation (1 Crore)',
          category: 'Wealth Creation',
          defaultTarget: 10000000,
          defaultMonths: 120,
          iconName: 'trending_up',
        ),
        PresetGoalTemplate(
          title: 'Tax-Saving Corpus (80C)',
          category: 'Tax Saving',
          defaultTarget: 150000,
          defaultMonths: 12,
          iconName: 'account_balance',
        ),
        PresetGoalTemplate(
          title: 'Child Education Fund',
          category: 'Child Education',
          defaultTarget: 3000000,
          defaultMonths: 144,
          iconName: 'child_care',
        ),
        PresetGoalTemplate(
          title: 'Custom Financial Goal',
          category: 'Other',
          defaultTarget: 500000,
          defaultMonths: 24,
          iconName: 'star',
        ),
      ];

  /// Deeply analyzes a financial goal and generates 3 tailored investment strategies
  static GoalInvestmentAnalysisReport analyzeGoal({
    required GoalModel goal,
    required double monthlyCapacity,
    required RiskProfileType userRiskProfile,
    required bool isEmergencyFundHealthy,
  }) {
    final double remaining = (goal.targetAmount - goal.currentAmount).clamp(0.0, goal.targetAmount);
    final int days = goal.daysRemaining;
    final int months = (days / 30.4).ceil().clamp(1, 600);
    final double years = (months / 12.0).clamp(0.1, 50.0);

    // Baseline illustrative return based on horizon
    double illustrativeRate;
    if (years < 2.0) {
      illustrativeRate = 6.5; // Liquid/Arbitrage/FD
    } else if (years <= 5.0) {
      illustrativeRate = 9.5; // Balanced Advantage / Hybrid
    } else {
      illustrativeRate = 12.0; // Equity Index / Diversified
    }

    final goalSip = InvestmentCalculationService.calculateGoalSipRequirement(
      targetCorpus: goal.targetAmount,
      currentCorpus: goal.currentAmount,
      durationYears: years.ceil(),
      annualReturnRate: illustrativeRate,
      availableMonthlyCapacity: monthlyCapacity,
    );

    final double requiredMonthly = goalSip.requiredMonthlyInvestment;

    GoalFeasibility feasibility;
    String reasoning;

    if (monthlyCapacity >= requiredMonthly * 1.2) {
      feasibility = GoalFeasibility.good;
      reasoning =
          'Your available monthly surplus of ${CurrencyFormatter.format(monthlyCapacity)} comfortably covers the required SIP of ${CurrencyFormatter.format(requiredMonthly)} with a 20%+ cash flow buffer. You are in prime position to fund this milestone seamlessly.';
    } else if (monthlyCapacity >= requiredMonthly * 0.85) {
      feasibility = GoalFeasibility.tight;
      reasoning =
          'Your monthly capacity (${CurrencyFormatter.format(monthlyCapacity)}) is slightly constrained relative to the required ${CurrencyFormatter.format(requiredMonthly)}. A small budget optimization of ₹${((requiredMonthly - monthlyCapacity)).toStringAsFixed(0)}/mo or a minor milestone extension will guarantee completion.';
    } else {
      feasibility = GoalFeasibility.atRisk;
      reasoning =
          'Targeting ${CurrencyFormatter.format(goal.targetAmount)} in $months months requires ${CurrencyFormatter.format(requiredMonthly)}/month, which exceeds your current capacity of ${CurrencyFormatter.format(monthlyCapacity)} by ${CurrencyFormatter.format(requiredMonthly - monthlyCapacity)}. Consider extending the timeline by 6-12 months or injecting a lump sum.';
    }

    // 3 Strategies tailored to this specific goal
    final strategies = _generateThreeStrategies(
      goalCategory: goal.category,
      years: years,
      userRiskProfile: userRiskProfile,
    );

    // Progressive De-risking Guidance
    String deRisking;
    if (years > 4.0) {
      deRisking =
          'Horizon > 4 Years: Keep aggressive equity focus (70-80%) to maximize compounding. When 2 years remain, systematically transfer 15-20% annually into short-duration debt to insulate your gains from late-stage market downturns.';
    } else if (years > 2.0) {
      deRisking =
          'Horizon 2 to 4 Years: Maintain a balanced 50/50 stance. Initiate a Systematic Transfer Plan (STP) into capital-protection funds once within 12 months of the milestone.';
    } else if (years > 1.0) {
      deRisking =
          'Horizon 1 to 2 Years: Capital preservation is now higher priority than growth. Shift 70%+ of corpus into banking & PSU debt or arbitrage funds.';
    } else {
      deRisking =
          'Horizon < 12 Months: Final milestone proximity! Hold 90-100% in liquid/ultra-short duration funds or high-yield savings to eliminate market volatility risk entirely.';
    }

    return GoalInvestmentAnalysisReport(
      goalId: goal.id,
      goalTitle: goal.title,
      targetAmount: goal.targetAmount,
      currentAmount: goal.currentAmount,
      remainingAmount: remaining,
      monthsRemaining: months,
      monthlyCapacity: monthlyCapacity,
      requiredMonthlyInvestment: requiredMonthly,
      feasibility: feasibility,
      detailedReasoning: reasoning,
      strategies: strategies,
      deRiskingGuidance: deRisking,
    );
  }

  static List<StrategyOption> _generateThreeStrategies({
    required String goalCategory,
    required double years,
    required RiskProfileType userRiskProfile,
  }) {
    int consMatch = 80;
    int balMatch = 92;
    int groMatch = 84;

    if (years < 2.0) {
      consMatch = 95;
      balMatch = 75;
      groMatch = 45;
    } else if (years > 5.0) {
      consMatch = 65;
      balMatch = 88;
      groMatch = 96;
    }

    return [
      StrategyOption(
        name: 'CONSERVATIVE',
        goalMatchPercentage: consMatch,
        riskLevel: RiskometerLevel.lowToModerate,
        timeHorizonLabel: '1 - 3 Years',
        liquidity: 'High (T+1 days)',
        illustrativeReturnRate: 7.0,
        volatilityDescription: 'Low to Negligible. Strong focus on principal safety.',
        assetAllocation: const {
          'Debt Funds & FDs': 65.0,
          'Liquid & Arbitrage': 25.0,
          'Conservative Hybrid': 10.0,
        },
        whyItFits: 'Prioritizes certainty and capital stability so your target funds remain intact regardless of market conditions.',
        whyItMayNotFit: 'Lower return assumption means you must contribute a higher monthly amount to beat inflation.',
      ),
      StrategyOption(
        name: 'BALANCED',
        goalMatchPercentage: balMatch,
        riskLevel: RiskometerLevel.moderate,
        timeHorizonLabel: '3 - 5 Years',
        liquidity: 'Medium (T+2 days)',
        illustrativeReturnRate: 10.5,
        volatilityDescription: 'Moderate. Combines equity upside with debt downside cushions.',
        assetAllocation: const {
          'Large Cap & Index Equities': 45.0,
          'Corporate Bond / Debt': 35.0,
          'Sovereign Gold / Liquid': 20.0,
        },
        whyItFits: 'Sweet spot of wealth accumulation and downside mitigation over multi-year horizons.',
        whyItMayNotFit: 'Subject to moderate drawdowns during cyclical economic corrections.',
      ),
      StrategyOption(
        name: 'GROWTH',
        goalMatchPercentage: groMatch,
        riskLevel: RiskometerLevel.veryHigh,
        timeHorizonLabel: '5+ Years',
        liquidity: 'Low to Medium',
        illustrativeReturnRate: 13.0,
        volatilityDescription: 'Elevated volatility with high potential for compounding wealth.',
        assetAllocation: const {
          'Flexi Cap & Mid Cap Funds': 55.0,
          'Nifty 50 Index Fund': 25.0,
          'International / Sectoral': 10.0,
          'Dynamic Debt / Gold': 10.0,
        },
        whyItFits: 'Harnesses full market power to compound aggressive returns and reduce required monthly cash outlay.',
        whyItMayNotFit: 'Unsuitable for near-term milestones due to substantial equity drawdown risk.',
      ),
    ];
  }
}
