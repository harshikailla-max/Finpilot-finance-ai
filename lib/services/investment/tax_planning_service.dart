import '../../models/investment_command_models.dart';

class TaxPlanningService {
  /// Evaluates Old vs New Tax Regimes and calculates optimal deduction strategy
  static TaxRegimeComparisonReport compareRegimesAndOptimize({
    required double annualGrossIncome,
    double utilized80C = 0.0,
    double utilized80D = 0.0,
    double utilizedNps = 0.0,
    double homeLoanInterest = 0.0,
  }) {
    // 1. Standard Deductions
    const double oldStdDeduction = 50000.0;
    const double newStdDeduction = 75000.0;

    // 2. Old Regime Deductions
    final double clamped80C = utilized80C.clamp(0.0, 150000.0);
    final double clamped80D = utilized80D.clamp(0.0, 50000.0);
    final double clampedNps = utilizedNps.clamp(0.0, 50000.0);
    final double clampedHomeLoan = homeLoanInterest.clamp(0.0, 200000.0);

    final double totalOldDeductions =
        oldStdDeduction +
        clamped80C +
        clamped80D +
        clampedNps +
        clampedHomeLoan;

    final double oldTaxableIncome = (annualGrossIncome - totalOldDeductions)
        .clamp(0.0, double.infinity);
    final double newTaxableIncome = (annualGrossIncome - newStdDeduction).clamp(
      0.0,
      double.infinity,
    );

    // 3. Tax Liability Calculations
    final double oldTax = _calculateOldRegimeTax(oldTaxableIncome);
    final double newTax = _calculateNewRegimeTax(newTaxableIncome);

    TaxRegime recommended;
    double taxSavings;
    String advice;

    if (newTax < oldTax) {
      recommended = TaxRegime.newRegime;
      taxSavings = oldTax - newTax;
      advice =
          'The New Tax Regime is more tax-efficient for your profile, saving ~₹${taxSavings.toStringAsFixed(0)} without requiring you to lock in capital into eligible 80C instruments.';
    } else if (oldTax < newTax) {
      recommended = TaxRegime.oldRegime;
      taxSavings = newTax - oldTax;
      advice =
          'The Old Tax Regime yields superior savings (~₹${taxSavings.toStringAsFixed(0)} less tax) due to your substantial utilization of Section 80C, 80D, and home loan exemptions.';
    } else {
      recommended = TaxRegime.newRegime;
      taxSavings = 0.0;
      advice = 'Both regimes result in equal tax liability. The New Regime is generally preferred for simpler compliance without mandatory lock-ins.';
    }

    final deductionBreakdown = [
      TaxDeductionCategory(
        code: '80C',
        title: 'Life Insurance, ELSS & Provident Funds',
        maxAllowedLimit: 150000.0,
        currentUtilized: clamped80C,
        eligibleInstruments: const [
          'ELSS Mutual Funds',
          'PPF',
          'EPF',
          'Sukanya Samriddhi',
          'Term Insurance',
        ],
        lockInPeriod: '3 Years (ELSS) to 15 Years (PPF)',
        riskLevel: RiskometerLevel.moderatelyHigh,
        taxTreatment: 'EEE (Exempt-Exempt-Exempt) for PPF; LTCG > 1.25L taxed at 12.5% for ELSS',
      ),
      TaxDeductionCategory(
        code: '80D',
        title: 'Health Insurance Premium (Self & Parents)',
        maxAllowedLimit: 50000.0,
        currentUtilized: clamped80D,
        eligibleInstruments: const [
          'Individual Health Cover',
          'Family Floater',
          'Senior Citizen Parents Top-up',
        ],
        lockInPeriod: 'Annual Premium (No lock-in)',
        riskLevel: RiskometerLevel.low,
        taxTreatment:
            'Direct deduction against taxable income under Old Regime',
      ),
      TaxDeductionCategory(
        code: '80CCD(1B)',
        title: 'National Pension System (NPS Additional)',
        maxAllowedLimit: 50000.0,
        currentUtilized: clampedNps,
        eligibleInstruments: const ['NPS Tier 1 Account'],
        lockInPeriod: 'Until Age 60',
        riskLevel: RiskometerLevel.moderate,
        taxTreatment: '60% tax-free lump sum at age 60; 40% mandatory annuity',
      ),
      TaxDeductionCategory(
        code: 'Section 24(b)',
        title: 'Home Loan Self-Occupied Interest',
        maxAllowedLimit: 200000.0,
        currentUtilized: clampedHomeLoan,
        eligibleInstruments: const ['Home Loan Interest Payment'],
        lockInPeriod: 'Mortgage Duration',
        riskLevel: RiskometerLevel.low,
        taxTreatment: 'Deduction from Income from House Property',
      ),
    ];

    return TaxRegimeComparisonReport(
      annualGrossIncome: annualGrossIncome,
      oldRegimeTotalDeductions: totalOldDeductions,
      oldRegimeTaxableIncome: oldTaxableIncome,
      oldRegimeEstimatedTax: oldTax,
      newRegimeTaxableIncome: newTaxableIncome,
      newRegimeEstimatedTax: newTax,
      recommendedRegime: recommended,
      taxSavingsWithRecommendation: taxSavings,
      deductionBreakdown: deductionBreakdown,
      summaryAdvice: advice,
    );
  }

  static double _calculateOldRegimeTax(double taxable) {
    if (taxable <= 500000) return 0.0; // Section 87A rebate

    double tax = 0.0;
    if (taxable > 1000000) {
      tax += (taxable - 1000000) * 0.30;
      tax += 500000 * 0.20;
      tax += 250000 * 0.05;
    } else if (taxable > 500000) {
      tax += (taxable - 500000) * 0.20;
      tax += 250000 * 0.05;
    } else if (taxable > 250000) {
      tax += (taxable - 250000) * 0.05;
    }

    // 4% Health & Education Cess
    return tax * 1.04;
  }

  static double _calculateNewRegimeTax(double taxable) {
    if (taxable <= 700000) return 0.0; // Section 87A rebate up to 7L

    double tax = 0.0;
    if (taxable > 1500000) {
      tax += (taxable - 1500000) * 0.30;
      tax += 300000 * 0.20; // 12L-15L
      tax += 300000 * 0.15; // 9L-12L
      tax += 300000 * 0.10; // 6L-9L
      tax += 300000 * 0.05; // 3L-6L
    } else if (taxable > 1200000) {
      tax += (taxable - 1200000) * 0.20;
      tax += 300000 * 0.15;
      tax += 300000 * 0.10;
      tax += 300000 * 0.05;
    } else if (taxable > 900000) {
      tax += (taxable - 900000) * 0.15;
      tax += 300000 * 0.10;
      tax += 300000 * 0.05;
    } else if (taxable > 600000) {
      tax += (taxable - 600000) * 0.10;
      tax += 300000 * 0.05;
    } else if (taxable > 300000) {
      tax += (taxable - 300000) * 0.05;
    }

    // 4% Health & Education Cess
    return tax * 1.04;
  }
}
