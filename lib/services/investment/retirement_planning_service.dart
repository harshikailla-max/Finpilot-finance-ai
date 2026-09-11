import 'dart:math' as math;
import '../../models/investment_command_models.dart';
import '../../utils/currency_formatter.dart';
import 'investment_calculation_service.dart';

class RetirementPlanningService {
  /// Analyzes retirement preparedness, inflation-adjusted needs, and SIP requirements
  static RetirementPlanReport calculateRetirementPlan({
    int currentAge = 28,
    int retirementAge = 60,
    int lifeExpectancy = 85,
    double currentMonthlyExpense = 45000.0,
    double assumedInflationRate = 6.0,
    double assumedPreRetirementReturn = 12.0,
    double assumedPostRetirementReturn = 7.5,
    double existingInvestments = 150000.0,
    double currentMonthlyInvestment = 10000.0,
  }) {
    final int yearsToRetirement = (retirementAge - currentAge).clamp(1, 60);
    final int retirementDurationYears = (lifeExpectancy - retirementAge).clamp(5, 50);

    // 1. Inflation-adjusted expense at age of retirement
    final double inflationFraction = assumedInflationRate / 100.0;
    final double projectedMonthlyExpense = currentMonthlyExpense *
        math.pow(1.0 + inflationFraction, yearsToRetirement);
    final double firstYearAnnualExpense = projectedMonthlyExpense * 12.0;

    // 2. Real rate of return in retirement (post-tax return minus inflation)
    final double postReturnFraction = assumedPostRetirementReturn / 100.0;
    final double realRate =
        ((1.0 + postReturnFraction) / (1.0 + inflationFraction)) - 1.0;

    // Present value of growing annuity for retirement duration
    double requiredCorpus = 0.0;
    if (realRate.abs() > 0.001) {
      requiredCorpus = firstYearAnnualExpense *
          ((1.0 - math.pow(1.0 + realRate, -retirementDurationYears)) / realRate);
    } else {
      requiredCorpus = firstYearAnnualExpense * retirementDurationYears;
    }

    // 3. Projected growth of current existing investments until retirement
    final double preReturnFraction = assumedPreRetirementReturn / 100.0;
    final double projectedExistingInvestments = existingInvestments *
        math.pow(1.0 + preReturnFraction, yearsToRetirement);

    // 4. Net Corpus Gap
    final double corpusGap =
        (requiredCorpus - projectedExistingInvestments).clamp(0.0, requiredCorpus);

    // 5. Required Monthly SIP to build the gap
    final goalSip = InvestmentCalculationService.calculateGoalSipRequirement(
      targetCorpus: corpusGap,
      currentCorpus: 0.0,
      durationYears: yearsToRetirement,
      annualReturnRate: assumedPreRetirementReturn,
      availableMonthlyCapacity: currentMonthlyInvestment,
    );

    final double requiredMonthly = goalSip.requiredMonthlyInvestment;
    final double shortfallOrSurplus = currentMonthlyInvestment - requiredMonthly;
    final bool isOnTrack = shortfallOrSurplus >= 0;

    final List<String> actions = [];
    if (isOnTrack) {
      actions.add('Your current monthly contribution of ${CurrencyFormatter.format(currentMonthlyInvestment)} is on track to meet your retirement milestone.');
      actions.add('Step up your SIP annually by 5-10% to create a longevity bonus buffer.');
      actions.add('Consolidate long-term holdings in low-cost index funds and EPF/PPF/NPS.');
    } else {
      actions.add('Increase your retirement SIP by ${CurrencyFormatter.format(-shortfallOrSurplus)}/month to bridge the future corpus shortfall.');
      actions.add('Optimize asset allocation to target 70% equity in your accumulation phase (next 10-15 years).');
      actions.add('Delaying retirement by just 2 years reduces the required nest egg significantly due to 2 extra compounding years.');
    }

    return RetirementPlanReport(
      currentAge: currentAge,
      retirementAge: retirementAge,
      lifeExpectancy: lifeExpectancy,
      currentMonthlyExpense: currentMonthlyExpense,
      assumedInflationRate: assumedInflationRate,
      assumedPreRetirementReturn: assumedPreRetirementReturn,
      assumedPostRetirementReturn: assumedPostRetirementReturn,
      existingInvestments: existingInvestments,
      currentMonthlyInvestment: currentMonthlyInvestment,
      projectedMonthlyExpenseAtRetirement: projectedMonthlyExpense,
      requiredRetirementCorpus: requiredCorpus,
      projectedExistingInvestmentsAtRetirement: projectedExistingInvestments,
      corpusGap: corpusGap,
      requiredMonthlyInvestment: requiredMonthly,
      monthlyCapacityShortfallOrSurplus: shortfallOrSurplus,
      isOnTrack: isOnTrack,
      milestoneActionPoints: actions,
    );
  }
}
