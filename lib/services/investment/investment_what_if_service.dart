import '../../utils/currency_formatter.dart';
import 'investment_calculation_service.dart';

class InvestmentWhatIfScenarioCard {
  final String title;
  final String description;
  final double corpusDifference;
  final double projectedCorpus;
  final String strategicImpact;

  const InvestmentWhatIfScenarioCard({
    required this.title,
    required this.description,
    required this.corpusDifference,
    required this.projectedCorpus,
    required this.strategicImpact,
  });
}

class InvestmentWhatIfService {
  /// Evaluates 4 quick sensitivity scenarios against a baseline SIP plan
  static List<InvestmentWhatIfScenarioCard> evaluateSensitivityScenarios({
    required double baseMonthlySip,
    required int baseYears,
    required double baseAnnualReturn,
    double baseStartingCorpus = 0.0,
  }) {
    final baseResult = InvestmentCalculationService.calculateSip(
      monthlySip: baseMonthlySip,
      durationYears: baseYears,
      annualReturnRate: baseAnnualReturn,
      startingInvestment: baseStartingCorpus,
    );
    final double baselineCorpus = baseResult.estimatedCorpus;

    // 1. Scenario: +₹5,000 / month
    final sipPlus5k = InvestmentCalculationService.calculateSip(
      monthlySip: baseMonthlySip + 5000.0,
      durationYears: baseYears,
      annualReturnRate: baseAnnualReturn,
      startingInvestment: baseStartingCorpus,
    );
    final double diff5k = sipPlus5k.estimatedCorpus - baselineCorpus;

    // 2. Scenario: +₹10,000 / month
    final sipPlus10k = InvestmentCalculationService.calculateSip(
      monthlySip: baseMonthlySip + 10000.0,
      durationYears: baseYears,
      annualReturnRate: baseAnnualReturn,
      startingInvestment: baseStartingCorpus,
    );
    final double diff10k = sipPlus10k.estimatedCorpus - baselineCorpus;

    // 3. Scenario: +1 Year Horizon (Compounding Extension)
    final sipPlus1Year = InvestmentCalculationService.calculateSip(
      monthlySip: baseMonthlySip,
      durationYears: baseYears + 1,
      annualReturnRate: baseAnnualReturn,
      startingInvestment: baseStartingCorpus,
    );
    final double diff1Year = sipPlus1Year.estimatedCorpus - baselineCorpus;

    // 4. Scenario: -1 Year Horizon (Accelerated Target)
    final int minusYearDuration = (baseYears - 1).clamp(1, 50);
    final sipMinus1Year = InvestmentCalculationService.calculateSip(
      monthlySip: baseMonthlySip,
      durationYears: minusYearDuration,
      annualReturnRate: baseAnnualReturn,
      startingInvestment: baseStartingCorpus,
    );
    final double diffMinusYear = sipMinus1Year.estimatedCorpus - baselineCorpus;

    return [
      InvestmentWhatIfScenarioCard(
        title: '+₹5,000 Monthly SIP Step-Up',
        description:
            'Increase monthly contribution from ${CurrencyFormatter.format(baseMonthlySip)} to ${CurrencyFormatter.format(baseMonthlySip + 5000)}.',
        corpusDifference: diff5k,
        projectedCorpus: sipPlus5k.estimatedCorpus,
        strategicImpact:
            'Adds ~${CurrencyFormatter.format(diff5k)} in extra wealth over $baseYears years at ${baseAnnualReturn.toStringAsFixed(1)}% p.a.',
      ),
      InvestmentWhatIfScenarioCard(
        title: '+₹10,000 Aggressive Step-Up',
        description:
            'Increase monthly contribution from ${CurrencyFormatter.format(baseMonthlySip)} to ${CurrencyFormatter.format(baseMonthlySip + 10000)}.',
        corpusDifference: diff10k,
        projectedCorpus: sipPlus10k.estimatedCorpus,
        strategicImpact:
            'Accelerates capital accumulation by ~${CurrencyFormatter.format(diff10k)} with dramatic compounding effect.',
      ),
      InvestmentWhatIfScenarioCard(
        title: '+1 Year Time Extension',
        description:
            'Extend goal deadline from $baseYears to ${baseYears + 1} years.',
        corpusDifference: diff1Year,
        projectedCorpus: sipPlus1Year.estimatedCorpus,
        strategicImpact:
            'Gives compounding 1 additional year, yielding ~${CurrencyFormatter.format(diff1Year)} more without increasing monthly savings.',
      ),
      InvestmentWhatIfScenarioCard(
        title: '-1 Year Accelerated Timeline',
        description:
            'Withdraw milestone 1 year earlier ($minusYearDuration years total).',
        corpusDifference: diffMinusYear,
        projectedCorpus: sipMinus1Year.estimatedCorpus,
        strategicImpact:
            'Early liquidation reduces final corpus by ~${CurrencyFormatter.format(-diffMinusYear)}. Requires higher monthly SIP to offset.',
      ),
    ];
  }
}
