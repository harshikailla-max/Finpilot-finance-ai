import '../models/investment_command_models.dart';

/// Configurable tax slab representation
class TaxSlab {
  final double minIncome;
  final double maxIncome; // double.infinity for upper bound
  final double taxRatePercent;

  const TaxSlab({
    required this.minIncome,
    required this.maxIncome,
    required this.taxRatePercent,
  });
}

/// Dynamic deduction rule specification
class TaxDeductionRule {
  final String section;
  final String title;
  final double maxLimit;
  final List<String> eligibleInstruments;
  final String lockInPeriod;
  final RiskometerLevel riskLevel;
  final String taxTreatment;
  final String eligibilityNotes;
  final bool availableUnderNewRegime;

  const TaxDeductionRule({
    required this.section,
    required this.title,
    required this.maxLimit,
    required this.eligibleInstruments,
    required this.lockInPeriod,
    required this.riskLevel,
    required this.taxTreatment,
    required this.eligibilityNotes,
    this.availableUnderNewRegime = false,
  });
}

/// Dynamic financial year tax configuration
class FinancialYearTaxConfig {
  final String financialYear; // e.g., '2024-2025' or '2025-2026'
  final double standardDeductionOld;
  final double standardDeductionNew;
  final double rebateLimitNew; // Section 87A rebate threshold
  final double cessPercent;
  final List<TaxSlab> oldRegimeSlabs;
  final List<TaxSlab> newRegimeSlabs;
  final List<TaxDeductionRule> deductionRules;
  final List<String> educationalWarnings;

  const FinancialYearTaxConfig({
    required this.financialYear,
    required this.standardDeductionOld,
    required this.standardDeductionNew,
    required this.rebateLimitNew,
    this.cessPercent = 4.0,
    required this.oldRegimeSlabs,
    required this.newRegimeSlabs,
    required this.deductionRules,
    required this.educationalWarnings,
  });
}

/// Dynamic Tax Rules Engine allowing updates and multi-year configurations
class TaxRulesService {
  static final Map<String, FinancialYearTaxConfig> _yearConfigs = {
    '2024-2025': const FinancialYearTaxConfig(
      financialYear: '2024-2025',
      standardDeductionOld: 50000.0,
      standardDeductionNew: 75000.0,
      rebateLimitNew: 700000.0,
      cessPercent: 4.0,
      oldRegimeSlabs: [
        TaxSlab(minIncome: 0, maxIncome: 250000, taxRatePercent: 0),
        TaxSlab(minIncome: 250000, maxIncome: 500000, taxRatePercent: 5),
        TaxSlab(minIncome: 500000, maxIncome: 1000000, taxRatePercent: 20),
        TaxSlab(minIncome: 1000000, maxIncome: double.infinity, taxRatePercent: 30),
      ],
      newRegimeSlabs: [
        TaxSlab(minIncome: 0, maxIncome: 300000, taxRatePercent: 0),
        TaxSlab(minIncome: 300000, maxIncome: 700000, taxRatePercent: 5),
        TaxSlab(minIncome: 700000, maxIncome: 1000000, taxRatePercent: 10),
        TaxSlab(minIncome: 1000000, maxIncome: 1200000, taxRatePercent: 15),
        TaxSlab(minIncome: 1200000, maxIncome: 1500000, taxRatePercent: 20),
        TaxSlab(minIncome: 1500000, maxIncome: double.infinity, taxRatePercent: 30),
      ],
      deductionRules: [
        TaxDeductionRule(
          section: '80C',
          title: 'Life Insurance, ELSS & Provident Funds',
          maxLimit: 150000.0,
          eligibleInstruments: ['ELSS Mutual Funds', 'PPF', 'EPF', 'Sukanya Samriddhi', 'Term Insurance'],
          lockInPeriod: '3 Years (ELSS) to 15 Years (PPF)',
          riskLevel: RiskometerLevel.moderatelyHigh,
          taxTreatment: 'EEE for PPF; LTCG > 1.25L taxed at 12.5% for ELSS',
          eligibilityNotes: 'Available to Individual and HUF taxpayers under Old Regime only.',
        ),
        TaxDeductionRule(
          section: '80D',
          title: 'Health Insurance Premium (Self & Family)',
          maxLimit: 50000.0,
          eligibleInstruments: ['Individual Health Cover', 'Family Floater', 'Senior Citizen Parents Top-up'],
          lockInPeriod: 'Annual Premium (No lock-in)',
          riskLevel: RiskometerLevel.low,
          taxTreatment: 'Direct deduction against taxable income under Old Regime',
          eligibilityNotes: 'Up to ₹25k for self/family, additional ₹25k/₹50k for parents.',
        ),
        TaxDeductionRule(
          section: '80CCD(1B)',
          title: 'National Pension System (NPS Additional)',
          maxLimit: 50000.0,
          eligibleInstruments: ['NPS Tier 1 Account'],
          lockInPeriod: 'Until Age 60',
          riskLevel: RiskometerLevel.moderate,
          taxTreatment: '60% tax-free lump sum at age 60; 40% mandatory annuity',
          eligibilityNotes: 'Over and above the ₹1.5L limit of Section 80C.',
        ),
        TaxDeductionRule(
          section: 'Section 24(b)',
          title: 'Home Loan Self-Occupied Interest',
          maxLimit: 200000.0,
          eligibleInstruments: ['Home Loan Interest Payment'],
          lockInPeriod: 'Mortgage Duration',
          riskLevel: RiskometerLevel.low,
          taxTreatment: 'Deduction from Income from House Property',
          eligibilityNotes: 'Property must be self-occupied; construction completed within 5 years.',
        ),
      ],
      educationalWarnings: [
        'Tax calculations are simulated for educational planning only and do not constitute formal tax advice.',
        'Surcharge applies for taxable income exceeding ₹50 Lakhs.',
        'Health & Education Cess at 4% is added to the base tax liability.',
        'Please consult a certified Chartered Accountant or tax consultant before filing your ITR.',
      ],
    ),
    '2025-2026': const FinancialYearTaxConfig(
      financialYear: '2025-2026',
      standardDeductionOld: 50000.0,
      standardDeductionNew: 75000.0,
      rebateLimitNew: 700000.0,
      cessPercent: 4.0,
      oldRegimeSlabs: [
        TaxSlab(minIncome: 0, maxIncome: 250000, taxRatePercent: 0),
        TaxSlab(minIncome: 250000, maxIncome: 500000, taxRatePercent: 5),
        TaxSlab(minIncome: 500000, maxIncome: 1000000, taxRatePercent: 20),
        TaxSlab(minIncome: 1000000, maxIncome: double.infinity, taxRatePercent: 30),
      ],
      newRegimeSlabs: [
        TaxSlab(minIncome: 0, maxIncome: 300000, taxRatePercent: 0),
        TaxSlab(minIncome: 300000, maxIncome: 700000, taxRatePercent: 5),
        TaxSlab(minIncome: 700000, maxIncome: 1000000, taxRatePercent: 10),
        TaxSlab(minIncome: 1000000, maxIncome: 1200000, taxRatePercent: 15),
        TaxSlab(minIncome: 1200000, maxIncome: 1500000, taxRatePercent: 20),
        TaxSlab(minIncome: 1500000, maxIncome: double.infinity, taxRatePercent: 30),
      ],
      deductionRules: [
        TaxDeductionRule(
          section: '80C',
          title: 'Life Insurance, ELSS & Provident Funds',
          maxLimit: 150000.0,
          eligibleInstruments: ['ELSS Mutual Funds', 'PPF', 'EPF', 'Sukanya Samriddhi', 'Term Insurance'],
          lockInPeriod: '3 Years (ELSS) to 15 Years (PPF)',
          riskLevel: RiskometerLevel.moderatelyHigh,
          taxTreatment: 'EEE for PPF; LTCG > 1.25L taxed at 12.5% for ELSS',
          eligibilityNotes: 'Available to Individual and HUF taxpayers under Old Regime only.',
        ),
        TaxDeductionRule(
          section: '80D',
          title: 'Health Insurance Premium (Self & Family)',
          maxLimit: 50000.0,
          eligibleInstruments: ['Individual Health Cover', 'Family Floater', 'Senior Citizen Parents Top-up'],
          lockInPeriod: 'Annual Premium (No lock-in)',
          riskLevel: RiskometerLevel.low,
          taxTreatment: 'Direct deduction against taxable income under Old Regime',
          eligibilityNotes: 'Up to ₹25k for self/family, additional ₹25k/₹50k for parents.',
        ),
        TaxDeductionRule(
          section: '80CCD(1B)',
          title: 'National Pension System (NPS Additional)',
          maxLimit: 50000.0,
          eligibleInstruments: ['NPS Tier 1 Account'],
          lockInPeriod: 'Until Age 60',
          riskLevel: RiskometerLevel.moderate,
          taxTreatment: '60% tax-free lump sum at age 60; 40% mandatory annuity',
          eligibilityNotes: 'Over and above the ₹1.5L limit of Section 80C.',
        ),
        TaxDeductionRule(
          section: 'Section 24(b)',
          title: 'Home Loan Self-Occupied Interest',
          maxLimit: 200000.0,
          eligibleInstruments: ['Home Loan Interest Payment'],
          lockInPeriod: 'Mortgage Duration',
          riskLevel: RiskometerLevel.low,
          taxTreatment: 'Deduction from Income from House Property',
          eligibilityNotes: 'Property must be self-occupied; construction completed within 5 years.',
        ),
      ],
      educationalWarnings: [
        'Tax calculations are simulated for educational planning only and do not constitute formal tax advice.',
        'Surcharge applies for taxable income exceeding ₹50 Lakhs.',
        'Health & Education Cess at 4% is added to the base tax liability.',
        'Please consult a certified Chartered Accountant or tax consultant before filing your ITR.',
      ],
    ),
  };

  static String defaultYear = '2024-2025';

  static FinancialYearTaxConfig getConfig([String? year]) {
    return _yearConfigs[year ?? defaultYear] ?? _yearConfigs['2024-2025']!;
  }

  static List<String> getAvailableYears() {
    return _yearConfigs.keys.toList();
  }
}
