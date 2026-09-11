import '../../models/investment_command_models.dart';
import '../../utils/currency_formatter.dart';
import 'investment_calculation_service.dart';

class DebtInvestmentService {
  /// Compares Debt Repayment vs Market Investment vs Split Strategy
  static DebtVsInvestReport evaluateDebtVsInvest({
    required double outstandingLoan,
    required double loanInterestRate,
    required double currentEmi,
    required double monthlyCapacity,
    double expectedInvestmentReturn = 12.0,
    int periodYears = 5,
  }) {
    // Scenario A: 100% into Debt Prepayment
    // Direct guaranteed interest saved = extra payment * (loanInterestRate / 100) * years
    final double totalPrepaymentPaid = monthlyCapacity * 12 * periodYears;
    final double debtPaidA = totalPrepaymentPaid.clamp(0.0, outstandingLoan);
    // Approximate interest saved based on amortized balance reduction
    final double interestSavedA = (debtPaidA * (loanInterestRate / 100.0) * (periodYears / 2.0));
    final double netBenefitA = interestSavedA;

    final scenarioRepay = DebtVsInvestScenario(
      name: 'Scenario A: Aggressive Debt Repayment',
      description: 'Channel 100% of monthly surplus (${CurrencyFormatter.format(monthlyCapacity)}) into prepaying loan principal.',
      totalDebtPaidInPeriod: debtPaidA,
      totalInterestSaved: interestSavedA,
      totalWealthAccumulated: 0.0,
      netFinancialBenefit: netBenefitA,
      tradeOffNote: 'Guaranteed ${loanInterestRate.toStringAsFixed(1)}% risk-free return through interest savings. Boosts peace of mind and frees future cash flow completely.',
    );

    // Scenario B: 100% into Market Investment (Pay minimum EMI)
    final sipResultB = InvestmentCalculationService.calculateSip(
      monthlySip: monthlyCapacity,
      durationYears: periodYears,
      annualReturnRate: expectedInvestmentReturn,
    );
    final double netBenefitB = sipResultB.estimatedGain;

    final scenarioInvest = DebtVsInvestScenario(
      name: 'Scenario B: 100% Market Investment',
      description: 'Pay regular EMI only; channel 100% of monthly surplus into systematic index/equity funds.',
      totalDebtPaidInPeriod: 0.0,
      totalInterestSaved: 0.0,
      totalWealthAccumulated: sipResultB.estimatedCorpus,
      netFinancialBenefit: netBenefitB,
      tradeOffNote: 'Capitalizes on equity compounding (~${expectedInvestmentReturn.toStringAsFixed(1)}% p.a.). However, debt obligation remains and returns are volatile.',
    );

    // Scenario C: 50 / 50 Balanced Split
    final double halfCapacity = monthlyCapacity * 0.5;
    final double debtPaidC = (halfCapacity * 12 * periodYears).clamp(0.0, outstandingLoan);
    final double interestSavedC = (debtPaidC * (loanInterestRate / 100.0) * (periodYears / 2.0));
    final sipResultC = InvestmentCalculationService.calculateSip(
      monthlySip: halfCapacity,
      durationYears: periodYears,
      annualReturnRate: expectedInvestmentReturn,
    );
    final double netBenefitC = interestSavedC + sipResultC.estimatedGain;

    final scenarioSplit = DebtVsInvestScenario(
      name: 'Scenario C: 50/50 Balanced Split',
      description: 'Prepay ₹${halfCapacity.toStringAsFixed(0)}/mo against loan while investing ₹${halfCapacity.toStringAsFixed(0)}/mo in market SIP.',
      totalDebtPaidInPeriod: debtPaidC,
      totalInterestSaved: interestSavedC,
      totalWealthAccumulated: sipResultC.estimatedCorpus,
      netFinancialBenefit: netBenefitC,
      tradeOffNote: 'Combines guaranteed debt reduction with simultaneous wealth compounding habit. Highly recommended for sustainable psychological balance.',
    );

    // Decision Logic
    String recommendation;
    String reasoning;

    if (loanInterestRate >= 13.0) {
      recommendation = 'Scenario A: Aggressive Debt Repayment';
      reasoning =
          'Your loan carries an interest rate of ${loanInterestRate.toStringAsFixed(1)}%. Mathematically, saving guaranteed ${loanInterestRate.toStringAsFixed(1)}% tax-free interest consistently beats market risk. Eliminate this high-cost liability before aggressive investing.';
    } else if (loanInterestRate <= 8.5) {
      recommendation = 'Scenario B or C: Invest or Split';
      reasoning =
          'At a low interest rate of ${loanInterestRate.toStringAsFixed(1)}% (e.g., subsidized home loan), long-term diversified equity returns historically surpass borrowing costs by 3-4% p.a. A 50/50 split ensures you build assets while chipping down debt.';
    } else {
      recommendation = 'Scenario C: 50/50 Balanced Split';
      reasoning =
          'Your interest rate of ${loanInterestRate.toStringAsFixed(1)}% is in the moderate range. Splitting surplus 50/50 shields you from opportunity cost while steadily accelerating your debt-free timeline.';
    }

    return DebtVsInvestReport(
      outstandingLoan: outstandingLoan,
      loanInterestRate: loanInterestRate,
      currentEmi: currentEmi,
      monthlyCapacity: monthlyCapacity,
      expectedInvestmentReturn: expectedInvestmentReturn,
      scenarioRepay: scenarioRepay,
      scenarioInvest: scenarioInvest,
      scenarioSplit: scenarioSplit,
      bestChoiceRecommendation: recommendation,
      reasoningWhy: reasoning,
    );
  }
}
