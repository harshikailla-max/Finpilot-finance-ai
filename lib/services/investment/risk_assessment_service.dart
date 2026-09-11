import '../../models/investment_command_models.dart';

class RiskQuestion {
  final int id;
  final String question;
  final List<RiskOption> options;

  const RiskQuestion({
    required this.id,
    required this.question,
    required this.options,
  });
}

class RiskOption {
  final String text;
  final int score; // 1 to 4 or 5
  final String subtext;

  const RiskOption({
    required this.text,
    required this.score,
    required this.subtext,
  });
}

class RiskAssessmentService {
  /// The 6 institutional risk profiling questions
  static List<RiskQuestion> get standardQuestions => [
        const RiskQuestion(
          id: 1,
          question: 'How would you react if your portfolio declined by 20% over 3 months?',
          options: [
            RiskOption(
              text: 'Panic and sell all remaining investments to prevent further losses.',
              score: 1,
              subtext: 'High loss aversion',
            ),
            RiskOption(
              text: 'Feel distressed and move a significant portion to bank fixed deposits.',
              score: 2,
              subtext: 'Defensive orientation',
            ),
            RiskOption(
              text: 'Stay calm, don’t sell anything, and wait patiently for market recovery.',
              score: 3,
              subtext: 'Balanced resilience',
            ),
            RiskOption(
              text: 'View it as a buying opportunity and allocate more capital into discounted assets.',
              score: 4,
              subtext: 'Opportunistic growth mindset',
            ),
          ],
        ),
        const RiskQuestion(
          id: 2,
          question: 'How long can you comfortably keep the majority of your capital invested?',
          options: [
            RiskOption(
              text: 'Less than 12 months (Immediate liquidity needed)',
              score: 1,
              subtext: 'Ultra-short horizon',
            ),
            RiskOption(
              text: '1 to 3 years (Short to medium milestones)',
              score: 2,
              subtext: 'Short-medium horizon',
            ),
            RiskOption(
              text: '3 to 7 years (Flexible multi-year goals)',
              score: 3,
              subtext: 'Medium-long horizon',
            ),
            RiskOption(
              text: '7+ years or until retirement (No near-term withdrawals needed)',
              score: 4,
              subtext: 'Extended compounding horizon',
            ),
          ],
        ),
        const RiskQuestion(
          id: 3,
          question: 'Do you anticipate needing to liquidate investments for unexpected emergencies?',
          options: [
            RiskOption(
              text: 'Yes, likely within the next 6 to 12 months because savings are low.',
              score: 1,
              subtext: 'High liquidity dependency',
            ),
            RiskOption(
              text: 'Possibly, if an unexpected job change or major expense occurs.',
              score: 2,
              subtext: 'Moderate liquidity dependency',
            ),
            RiskOption(
              text: 'Unlikely, I maintain an independent 3-month cash buffer.',
              score: 3,
              subtext: 'Adequate emergency moat',
            ),
            RiskOption(
              text: 'Extremely unlikely; emergency fund & health coverage are fully established.',
              score: 4,
              subtext: 'Bulletproof defense',
            ),
          ],
        ),
        const RiskQuestion(
          id: 4,
          question: 'How predictable and secure is your primary income stream?',
          options: [
            RiskOption(
              text: 'Highly volatile (Commission, irregular freelance, or cyclical income)',
              score: 1,
              subtext: 'Low income predictability',
            ),
            RiskOption(
              text: 'Somewhat variable with moderate fluctuation across quarters',
              score: 2,
              subtext: 'Moderate stability',
            ),
            RiskOption(
              text: 'Stable regular salary or dependable recurring cash flow',
              score: 3,
              subtext: 'Predictable cash flow',
            ),
            RiskOption(
              text: 'Very secure employment / established business plus secondary income streams',
              score: 4,
              subtext: 'High cash surplus reliability',
            ),
          ],
        ),
        const RiskQuestion(
          id: 5,
          question: 'What is the maximum temporary drawdown you can psychologically stomach in a year?',
          options: [
            RiskOption(
              text: '0% — Capital preservation is paramount; cannot accept negative returns',
              score: 1,
              subtext: 'Zero tolerance',
            ),
            RiskOption(
              text: 'Up to 5% — Tolerates tiny fluctuations for inflation protection',
              score: 2,
              subtext: 'Low tolerance',
            ),
            RiskOption(
              text: 'Up to 15% — Understands market cycles and accepts temporary dips',
              score: 3,
              subtext: 'Moderate tolerance',
            ),
            RiskOption(
              text: '20% to 35% — Comfortable with steep volatility for outsized long-term gains',
              score: 4,
              subtext: 'High tolerance',
            ),
          ],
        ),
        const RiskQuestion(
          id: 6,
          question: 'What is your prior experience with market-linked investment instruments?',
          options: [
            RiskOption(
              text: 'First-time beginner (Only kept money in savings accounts / FDs)',
              score: 1,
              subtext: 'Novice',
            ),
            RiskOption(
              text: 'Basic familiarity (Have explored tax-saving ELSS or small recurring deposits)',
              score: 2,
              subtext: 'Familiar beginner',
            ),
            RiskOption(
              text: 'Active investor (Regular SIPs in index/mutual funds for 2+ years)',
              score: 3,
              subtext: 'Intermediate',
            ),
            RiskOption(
              text: 'Experienced investor (Understands asset classes, equities, and market valuation)',
              score: 4,
              subtext: 'Advanced',
            ),
          ],
        ),
      ];

  /// Evaluates responses and derives Capacity, Tolerance, Requirement and Classification
  static RiskScoreBreakdown evaluateAssessment({
    required Map<int, int> selectedOptions, // questionId -> score (1..4)
    double emergencyRunwayMonths = 3.0,
    double savingsRate = 20.0,
    double targetHorizonYears = 5.0,
  }) {
    // 1. Psychological Tolerance: questions 1, 5, 6
    final int q1 = selectedOptions[1] ?? 2;
    final int q5 = selectedOptions[5] ?? 2;
    final int q6 = selectedOptions[6] ?? 2;
    final double toleranceRaw = ((q1 + q5 + q6) / 12.0) * 100.0;

    // 2. Financial Capacity: questions 2, 3, 4 + real app runway & savings rate
    final int q2 = selectedOptions[2] ?? 2;
    final int q3 = selectedOptions[3] ?? 2;
    final int q4 = selectedOptions[4] ?? 2;
    double capacityRaw = ((q2 + q3 + q4) / 12.0) * 100.0;

    // Modulate capacity with actual financial facts
    if (emergencyRunwayMonths >= 6.0) {
      capacityRaw += 10.0;
    } else if (emergencyRunwayMonths < 2.0) {
      capacityRaw -= 15.0;
    }

    if (savingsRate >= 30.0) {
      capacityRaw += 10.0;
    } else if (savingsRate < 10.0) {
      capacityRaw -= 10.0;
    }

    final int capacityScore = capacityRaw.clamp(10.0, 95.0).round();
    final int toleranceScore = toleranceRaw.clamp(10.0, 95.0).round();

    // 3. Return Requirement: based on goal horizon
    int requirementScore;
    if (targetHorizonYears < 2) {
      requirementScore = 30; // only needs capital safety
    } else if (targetHorizonYears <= 5) {
      requirementScore = 60; // needs balanced 8-10%
    } else {
      requirementScore = 80; // needs aggressive compounding 12%+
    }

    // Overall composite risk score (Capacity is weighted 45%, Tolerance 40%, Requirement 15%)
    final double compositeScore =
        (capacityScore * 0.45) + (toleranceScore * 0.40) + (requirementScore * 0.15);

    RiskProfileType profile;
    String explanation;

    if (compositeScore < 35) {
      profile = RiskProfileType.conservative;
      explanation =
          'You prioritize capital security over aggressive growth. Low risk tolerance combined with near-term liquidity needs means capital preservation in debt and liquid assets is best suited.';
    } else if (compositeScore < 52) {
      profile = RiskProfileType.moderatelyConservative;
      explanation =
          'You prefer stability with modest inflation protection. A conservative allocation (30% equity / 70% debt) provides steady compounding without uncomfortable drawdown anxiety.';
    } else if (compositeScore < 76) {
      profile = RiskProfileType.moderate;
      explanation =
          'You have a balanced risk profile. You are prepared to accept reasonable market fluctuations in exchange for 10-12% long-term compounded growth through balanced index & hybrid funds.';
    } else if (compositeScore < 88) {
      profile = RiskProfileType.moderatelyAggressive;
      explanation =
          'You possess healthy financial capacity and comfortable volatility resilience. You can comfortably ride multi-year equity cycles to maximize long-term wealth compounding.';
    } else {
      profile = RiskProfileType.aggressive;
      explanation =
          'You have high risk tolerance, solid liquidity reserves, and an extended investment horizon. You can deploy capital aggressively into equity funds for maximum compounding upside.';
    }

    return RiskScoreBreakdown(
      capacityScore: capacityScore,
      toleranceScore: toleranceScore,
      requirementScore: requirementScore,
      profileType: profile,
      explanation: explanation,
    );
  }
}
