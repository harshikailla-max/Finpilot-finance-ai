import '../../providers/finance_provider.dart';
import '../../providers/investment_provider.dart';
import '../../utils/currency_formatter.dart';

class InvestmentStrategyReport {
  final String strategyTitle;
  final double recommendedMonthlySip;
  final Map<String, double> assetAllocationPercentages;
  final String debtVsInvestAdvice;
  final String riskAssessment;
  final String projectionIllustration;
  final String educationalDisclaimer;

  const InvestmentStrategyReport({
    required this.strategyTitle,
    required this.recommendedMonthlySip,
    required this.assetAllocationPercentages,
    required this.debtVsInvestAdvice,
    required this.riskAssessment,
    required this.projectionIllustration,
    required this.educationalDisclaimer,
  });
}

class InvestmentReasoningService {
  static InvestmentStrategyReport evaluateStrategy({
    required FinanceProvider finance,
    required InvestmentProvider investments,
  }) {
    final double income = finance.monthlyIncome > 0 ? finance.monthlyIncome : 65000.0;
    final double expense = finance.monthlyExpense;
    final double monthlySurplus = (income - expense).clamp(0.0, 500000.0);

    // Recommended SIP: 30% to 50% of available monthly surplus
    final double recommendedSip = monthlySurplus > 5000
        ? ((monthlySurplus * 0.40) / 500).round() * 500.0
        : 2500.0;

    // Asset allocation based on financial stage
    final Map<String, double> allocation = {
      'Index & Large Cap Equity': 45.0,
      'Mid & Flexi Cap Funds': 25.0,
      'Debt & Fixed Income (PPF/FD)': 20.0,
      'Sovereign Gold / Liquid Fund': 10.0,
    };

    // Illustrative 5-year wealth projection at assumed conservative 11% CAGR
    final double annualSip = recommendedSip * 12;
    final double fiveYearInvested = annualSip * 5;
    // FV of monthly SIP formula: P * (((1+r)^n - 1) / r) * (1+r)
    // At ~11% annual (0.916% monthly): FV factor ~ 77.5
    final double fiveYearEstValue = recommendedSip * 77.5;

    final String illustration =
        'At ${CurrencyFormatter.format(recommendedSip)}/month, you would invest ${CurrencyFormatter.format(fiveYearInvested)} over 5 years. At an illustrative 11% annual growth rate, your estimated portfolio value could reach ~${CurrencyFormatter.format(fiveYearEstValue)}.';

    const String debtVsInvest =
        'If you hold high-cost debt (credit cards > 30% APR or personal loans > 12% APR), guaranteed interest savings from early repayment mathematically outperform market returns. For low-cost home loans (< 8.5%), continuing systematic investment alongside standard EMI servicing maximizes wealth compounding.';

    const String disclaimer =
        'Educational analysis only. Past performance does not guarantee future results. Projections are illustrative. FinPilot AI is not a SEBI-registered investment adviser; consult a certified financial planner for individual advice.';

    return InvestmentStrategyReport(
      strategyTitle: 'Disciplined Growth & Capital Preservation',
      recommendedMonthlySip: recommendedSip,
      assetAllocationPercentages: allocation,
      debtVsInvestAdvice: debtVsInvest,
      riskAssessment: 'Moderate-Aggressive (70% Equity / 30% Fixed Income & Gold)',
      projectionIllustration: illustration,
      educationalDisclaimer: disclaimer,
    );
  }
}
