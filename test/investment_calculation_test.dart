import 'package:flutter_test/flutter_test.dart';
import 'package:finpilot_ai/models/investment_command_models.dart';
import 'package:finpilot_ai/services/investment/investment_calculation_service.dart';
import 'package:finpilot_ai/services/investment/asset_allocation_service.dart';
import 'package:finpilot_ai/services/investment/risk_assessment_service.dart';
import 'package:finpilot_ai/services/investment/tax_planning_service.dart';
import 'package:finpilot_ai/services/investment/debt_investment_service.dart';
import 'package:finpilot_ai/services/investment/retirement_planning_service.dart';

void main() {
  group('InvestmentCalculationService Tests', () {
    test('calculateSip projects compound interest and milestones accurately', () {
      final result = InvestmentCalculationService.calculateSip(
        monthlySip: 10000.0,
        durationYears: 5,
        annualReturnRate: 12.0,
      );

      // Total invested = 10,000 * 60 = 6,00,000
      expect(result.totalInvested, equals(600000.0));
      // With 12% annual compounding, 5 yr SIP reaches ~8.24 Lakhs
      expect(result.estimatedCorpus, greaterThan(800000.0));
      expect(result.estimatedCorpus, lessThan(850000.0));
      expect(result.estimatedGain, greaterThan(200000.0));
      expect(result.milestones.length, equals(5));
      expect(result.conservativeCorpus, lessThan(result.estimatedCorpus));
      expect(result.optimisticCorpus, greaterThan(result.estimatedCorpus));
    });

    test('calculateLumpSum computes FV and SIP equivalent', () {
      final result = InvestmentCalculationService.calculateLumpSum(
        initialInvestment: 100000.0,
        durationYears: 10,
        annualReturnRate: 12.0,
      );

      // 100k * (1.12)^10 = ~3,10,584
      expect(result.totalInvested, equals(100000.0));
      expect(result.estimatedCorpus, greaterThan(310000.0));
      expect(result.estimatedCorpus, lessThan(312000.0));
      expect(result.sipEquivalentMonthly, greaterThan(1300.0));
    });

    test('calculateGoalSipRequirement determines required monthly investment', () {
      final result = InvestmentCalculationService.calculateGoalSipRequirement(
        targetCorpus: 1000000.0, // 10 Lakhs
        currentCorpus: 200000.0,  // 2 Lakhs
        durationYears: 3,
        annualReturnRate: 10.0,
        availableMonthlyCapacity: 25000.0,
      );

      // Remaining after current corpus grows is ~7.3 Lakhs
      // Required monthly SIP over 36 months at 10% is ~17.5k-18k
      expect(result.requiredMonthlyInvestment, greaterThan(16000.0));
      expect(result.requiredMonthlyInvestment, lessThan(20000.0));
      expect(result.isAchievable, isTrue);
      expect(result.gap, greaterThan(0.0));
    });
  });

  group('AssetAllocationService Tests', () {
    test('Short-term goals have 0% equity for capital protection', () {
      final result = AssetAllocationService.determineAllocation(
        goalCategory: 'Car Purchase',
        timeHorizonYears: 1.5,
        riskProfile: RiskProfileType.moderate,
        isEmergencyFundHealthy: true,
        hasHighCostDebt: false,
      );

      expect(result.allocationPercentages['Equity'], equals(0.0));
      expect(result.allocationPercentages['Debt']! + result.allocationPercentages['Liquid']!, greaterThanOrEqualTo(90.0));
    });

    test('Long-term aggressive goals have high equity exposure', () {
      final result = AssetAllocationService.determineAllocation(
        goalCategory: 'Wealth Creation',
        timeHorizonYears: 10.0,
        riskProfile: RiskProfileType.aggressive,
        isEmergencyFundHealthy: true,
        hasHighCostDebt: false,
      );

      expect(result.allocationPercentages['Equity'], greaterThanOrEqualTo(75.0));
    });
  });

  group('RiskAssessmentService Tests', () {
    test('Correctly identifies moderate risk profile', () {
      final answers = {
        1: 3, // Stay calm
        2: 3, // 3-7 years
        3: 3, // Unlikely to need money
        4: 3, // Stable salary
        5: 3, // 15% loss
        6: 3, // Active investor
      };

      final breakdown = RiskAssessmentService.evaluateAssessment(
        selectedOptions: answers,
        emergencyRunwayMonths: 4.0,
        savingsRate: 25.0,
        targetHorizonYears: 5.0,
      );

      expect(breakdown.profileType, equals(RiskProfileType.moderate));
      expect(breakdown.capacityScore, greaterThanOrEqualTo(50));
      expect(breakdown.toleranceScore, greaterThanOrEqualTo(50));
    });
  });

  group('TaxPlanningService Tests', () {
    test('Calculates and compares Old vs New regimes', () {
      final report = TaxPlanningService.compareRegimesAndOptimize(
        annualGrossIncome: 1200000.0,
        utilized80C: 150000.0,
        utilized80D: 25000.0,
        utilizedNps: 50000.0,
        homeLoanInterest: 100000.0,
      );

      expect(report.annualGrossIncome, equals(1200000.0));
      expect(report.oldRegimeTotalDeductions, greaterThan(350000.0));
      expect(report.deductionBreakdown.length, equals(4));
    });
  });

  group('DebtInvestmentService Tests', () {
    test('Recommends repaying high cost debt above 13% APR', () {
      final report = DebtInvestmentService.evaluateDebtVsInvest(
        outstandingLoan: 300000.0,
        loanInterestRate: 15.0,
        currentEmi: 10000.0,
        monthlyCapacity: 15000.0,
        expectedInvestmentReturn: 12.0,
      );

      expect(report.bestChoiceRecommendation, contains('Aggressive Debt Repayment'));
    });
  });

  group('RetirementPlanningService Tests', () {
    test('Calculates inflation-adjusted retirement corpus', () {
      final report = RetirementPlanningService.calculateRetirementPlan(
        currentAge: 30,
        retirementAge: 60,
        lifeExpectancy: 85,
        currentMonthlyExpense: 40000.0,
        assumedInflationRate: 6.0,
        existingInvestments: 200000.0,
        currentMonthlyInvestment: 15000.0,
      );

      expect(report.projectedMonthlyExpenseAtRetirement, greaterThan(200000.0));
      expect(report.requiredRetirementCorpus, greaterThan(30000000.0)); // > 3 Crore
      expect(report.milestoneActionPoints.isNotEmpty, isTrue);
    });
  });
}
