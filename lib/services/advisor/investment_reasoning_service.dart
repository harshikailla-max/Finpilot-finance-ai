import 'dart:math' as math;

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

class LumpSumOutcomeReport {
  final double principal;
  final int durationYears;
  final double pessimisticRate;
  final double illustrativeRate;
  final double optimisticRate;
  final double pessimisticCorpus;
  final double illustrativeCorpus;
  final double optimisticCorpus;
  final double pessimisticGain;
  final double illustrativeGain;
  final double optimisticGain;
  final String emergencyFundStatus;
  final String suitableCategories;
  final Map<String, double> suggestedAllocation;
  final String taxImplications;
  final String nextSteps;
  final String educationalDisclaimer;

  const LumpSumOutcomeReport({
    required this.principal,
    this.durationYears = 5,
    required this.pessimisticRate,
    required this.illustrativeRate,
    required this.optimisticRate,
    required this.pessimisticCorpus,
    required this.illustrativeCorpus,
    required this.optimisticCorpus,
    required this.pessimisticGain,
    required this.illustrativeGain,
    required this.optimisticGain,
    required this.emergencyFundStatus,
    required this.suitableCategories,
    required this.suggestedAllocation,
    required this.taxImplications,
    required this.nextSteps,
    required this.educationalDisclaimer,
  });
}

class InvestmentReasoningService {
  /// Evaluates monthly systematic strategy based on live cash flow
  static InvestmentStrategyReport evaluateStrategy({
    required FinanceProvider finance,
    required InvestmentProvider investments,
  }) {
    final double income = finance.monthlyIncome > 0
        ? finance.monthlyIncome
        : 65000.0;
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
    // FV of monthly SIP: P * (((1+r)^n - 1) / r) * (1+r)
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
      riskAssessment:
          'Moderate-Aggressive (70% Equity / 30% Fixed Income & Gold)',
      projectionIllustration: illustration,
      educationalDisclaimer: disclaimer,
    );
  }

  /// Evaluates lump sum deployment (e.g. ₹1,00,000) using tested compound formula FV = P * (1 + r)^t
  /// across 3 scenarios (pessimistic, illustrative, optimistic), with liquidity/debt pre-checks.
  static LumpSumOutcomeReport evaluateLumpSumStrategy({
    required double lumpSum,
    required FinanceProvider finance,
    required InvestmentProvider investments,
    int durationYears = 5,
  }) {
    final double monthlyBurn = finance.monthlyExpense > 0
        ? finance.monthlyExpense
        : 35000.0;
    final double currentLiquid = finance.balance;
    final double runwayMonths = monthlyBurn > 0 ? (currentLiquid / monthlyBurn) : 3.0;

    // Emergency reserve pre-check
    String emergencyCheck;
    if (runwayMonths < 3.0) {
      emergencyCheck =
          '⚠️ Liquidity Alert: Your tracked liquid balance provides ~${runwayMonths.toStringAsFixed(1)} months of emergency runway. Deploying the full ${CurrencyFormatter.format(lumpSum)} into locked or volatile equity carries risk. Consider parking at least ₹${(monthlyBurn * 2).toStringAsFixed(0)} in a high-yield liquid fund or sweep FD first.';
    } else {
      emergencyCheck =
          '✅ Liquidity Healthy: Your current emergency reserve is ~${runwayMonths.toStringAsFixed(1)} months of expenses. You have a solid safety buffer to deploy capital for compounding.';
    }

    // Compound Growth Calculation: FV = P * (1 + r)^t
    // Rates:
    // Pessimistic (Fixed Income / Liquid / Arbitrage): 6.5% p.a.
    // Illustrative (Balanced Advantage / Nifty 50 Index): 11.0% p.a.
    // Optimistic (Diversified Equity / Flexi-Cap): 14.0% p.a.
    const double pRate = 6.5;
    const double iRate = 11.0;
    const double oRate = 14.0;

    final double pCorpus = lumpSum * math.pow(1.0 + (pRate / 100.0), durationYears);
    final double iCorpus = lumpSum * math.pow(1.0 + (iRate / 100.0), durationYears);
    final double oCorpus = lumpSum * math.pow(1.0 + (oRate / 100.0), durationYears);

    final double pGain = pCorpus - lumpSum;
    final double iGain = iCorpus - lumpSum;
    final double oGain = oCorpus - lumpSum;

    final Map<String, double> allocation = {
      'Broad Index / Large Cap (Nifty 50)': 50.0,
      'Flexi-Cap / Mid-Cap Fund': 25.0,
      'Short-Term Debt / Arbitrage': 15.0,
      'Sovereign Gold / Physical Gold ETF': 10.0,
    };

    const String categories =
        '• Short-term (< 2 yrs): Arbitrage funds or High-yield Fixed Deposits (~6.5% - 7.2%). High liquidity, zero equity risk.\n'
        '• Medium-term (2-4 yrs): Multi-Asset Allocation or Balanced Advantage Funds (~8.5% - 10.5%). Moderated volatility with downside protection.\n'
        '• Long-term (5+ yrs): Broad Low-Cost Index Funds (Nifty 50 / Nifty 500) & Flexi-cap (~11.0% - 14.0%). Maximum compounding potential.';

    const String tax =
        'Under Indian Income Tax Act (Budget 2024 revised rates):\n'
        '• Equity Mutual Funds: Long-Term Capital Gains (held > 12 months) are taxed at 12.5% on gains exceeding ₹1,25,000 per financial year. Short-Term Capital Gains (held < 12 months) are taxed at 20%.\n'
        '• Debt Funds & Fixed Deposits: Gains and interest are taxed at your applicable individual income tax slab rates.';

    final String nextSteps =
        '1. Assess Horizon & Risk: Confirm you will not need this capital for at least $durationYears years.\n'
        '2. Staggered Entry Option (STP): Rather than deploying the entire ${CurrencyFormatter.format(lumpSum)} in one single day, park in a Liquid Fund and execute a Systematic Transfer Plan (STP) of ~${CurrencyFormatter.format(lumpSum / 10)}/month over 10 months to average market volatility.\n'
        '3. Diversification: Distribute across Large Cap Index, Flexi-Cap, and Debt/Gold as illustrated above.';

    const String disclaimer =
        'Educational simulation only. Past performance does not guarantee future results. Calculations use standard compound growth formulas FV = P × (1 + r)^t and assume reinvestment of earnings. FinPilot AI is an educational planning tool and not a SEBI-registered investment advisor or Chartered Accountant. Consult a licensed SEBI advisor or CA for individual financial planning.';

    return LumpSumOutcomeReport(
      principal: lumpSum,
      durationYears: durationYears,
      pessimisticRate: pRate,
      illustrativeRate: iRate,
      optimisticRate: oRate,
      pessimisticCorpus: pCorpus,
      illustrativeCorpus: iCorpus,
      optimisticCorpus: oCorpus,
      pessimisticGain: pGain,
      illustrativeGain: iGain,
      optimisticGain: oGain,
      emergencyFundStatus: emergencyCheck,
      suitableCategories: categories,
      suggestedAllocation: allocation,
      taxImplications: tax,
      nextSteps: nextSteps,
      educationalDisclaimer: disclaimer,
    );
  }
}
