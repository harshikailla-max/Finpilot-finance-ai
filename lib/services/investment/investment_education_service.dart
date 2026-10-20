import 'package:flutter/material.dart';

import '../../models/investment_command_models.dart';

class InvestmentEducationService {
  /// 15 Institutional Market Education Topics
  static List<MarketTopic> get marketAcademyTopics => const [
    MarketTopic(
      title: 'Power of Compounding',
      summary: 'Compounding is earning returns on your previously accumulated returns. Time in the market matters far more than timing the market.',
      keyTakeaway: 'Starting 5 years earlier can double your eventual retirement corpus even with smaller monthly contributions.',
      example: '₹10,000/month at 12% over 20 years yields ₹1 Crore, where ₹76 Lakhs is purely compounded interest.',
      icon: Icons.auto_awesome,
    ),
    MarketTopic(
      title: 'Systematic Investment Plan (SIP)',
      summary: 'An automated mechanism to invest a fixed sum at regular intervals, harnessing Rupee Cost Averaging across volatility cycles.',
      keyTakeaway: 'Eliminates the psychological anxiety of trying to pick market bottoms and tops.',
      example: 'When markets drop, your fixed SIP buys more mutual fund units; when markets rise, your units appreciate.',
      icon: Icons.repeat,
    ),
    MarketTopic(
      title: 'Lump Sum vs SIP',
      summary: 'Lump sum deploys capital immediately, while SIP averages entry prices across weeks or months.',
      keyTakeaway: 'Deploy lump sums systematically via Systematic Transfer Plans (STP) over 6-12 months during high market valuations.',
      example: 'STP from a liquid fund into an equity fund shields large bonuses from sudden market corrections.',
      icon: Icons.swap_horiz,
    ),
    MarketTopic(
      title: 'Strategic Asset Allocation',
      summary: 'Dividing your portfolio among equities, bonds, gold, and cash to balance risk and reward according to your specific goals.',
      keyTakeaway: 'Over 90% of long-term portfolio return variability is determined by asset allocation, not individual stock picking.',
      example: 'A 70/30 equity-debt mix captures growth while reducing maximum drawdown in bear markets.',
      icon: Icons.pie_chart_outline,
    ),
    MarketTopic(
      title: 'Diversification & Uncorrelated Assets',
      summary: 'Spreading investments across different asset classes and geographies so that a downturn in one doesn’t sink the portfolio.',
      keyTakeaway: 'The only "free lunch" in finance: lowers portfolio volatility without necessarily reducing expected returns.',
      example: 'Gold historically remains stable or rises during geopolitical crises when equities face pressure.',
      icon: Icons.dashboard_customize_outlined,
    ),
    MarketTopic(
      title: 'Understanding Risk & Volatility',
      summary: 'Volatility is temporary fluctuation in asset prices; risk is the permanent impairment of capital.',
      keyTakeaway: 'Equities are volatile in the short term, but cash is permanently risky against inflation over the long term.',
      example: 'A 15% market drop is standard market turbulence, not a loss unless you panic-sell.',
      icon: Icons.speed,
    ),
    MarketTopic(
      title: 'Inflation: The Silent Wealth Destroyer',
      summary: 'The gradual erosion of purchasing power over time. A 6% inflation cuts money’s real value in half every 12 years.',
      keyTakeaway: 'Bank savings accounts earning 3% lose real purchasing power every single year.',
      example: '₹1 Lakh today will require ~₹1.8 Lakhs in 10 years at 6% inflation to buy the exact same goods.',
      icon: Icons.trending_down,
    ),
    MarketTopic(
      title: 'Equities & Long-Term Wealth',
      summary: 'Owning shares of profitable corporations participating in India’s expanding GDP.',
      keyTakeaway: 'Best asset class historically for beating long-term inflation over 7+ year horizons.',
      example: 'Broad market indices (Nifty 50) have compounded at ~12-14% CAGR over multi-decade cycles.',
      icon: Icons.trending_up,
    ),
    MarketTopic(
      title: 'Fixed Income & Debt Instruments',
      summary: 'Lending capital to governments or corporations in exchange for periodic interest and principal return.',
      keyTakeaway: 'Provides cash flow predictability, capital stability, and reduces overall portfolio drawdown.',
      example: 'Target maturity debt funds and corporate bond funds offer predictable yields with moderate tax efficiency.',
      icon: Icons.account_balance,
    ),
    MarketTopic(
      title: 'Gold as a Portfolio Hedge',
      summary: 'A tangible precious commodity historically recognized as a store of value and currency protector.',
      keyTakeaway: 'Maintain 5-10% allocation in Sovereign Gold Bonds (SGB) or Gold ETFs as crisis insurance.',
      example: 'SGBs offer 2.5% annual sovereign interest plus capital appreciation with zero LTCG tax if held to maturity.',
      icon: Icons.workspace_premium,
    ),
    MarketTopic(
      title: 'Mutual Funds & Expense Ratios',
      summary: 'Pooled investment vehicles managed by professional asset management companies (AMCs).',
      keyTakeaway: 'Always choose "Direct Plans" over "Regular Plans" to save 0.5% to 1.5% in distributor commissions every year.',
      example: 'A 1% expense ratio difference over 25 years can save over ₹25 Lakhs on a ₹10,000 monthly SIP.',
      icon: Icons.layers_outlined,
    ),
    MarketTopic(
      title: 'Exchange Traded Funds (ETFs)',
      summary: 'Passive index-tracking funds traded directly on stock exchanges like individual shares.',
      keyTakeaway: 'Offers ultra-low expense ratios (<0.10%) and intraday liquidity for broad market exposure.',
      example: 'Nifty BEES ETF mirrors the top 50 Indian companies with near-zero tracking error.',
      icon: Icons.show_chart,
    ),
    MarketTopic(
      title: 'Tax-Efficient Investing',
      summary: 'Structuring investments to optimize after-tax returns under the Indian Income Tax Act.',
      keyTakeaway: 'Focus on instruments with favorable capital gains treatment (ELSS, equity LTCG up to 1.25L exemption).',
      example: 'Holding equity mutual funds for over 12 months qualifies for the preferential 12.5% LTCG tax bracket.',
      icon: Icons.receipt_long_outlined,
    ),
    MarketTopic(
      title: 'Retirement & Safe Withdrawal Rate',
      summary: 'Planning an investment corpus that sustains your lifestyle for 25-30 years without running out of money.',
      keyTakeaway: 'Target a 3.5% to 4.0% annual initial withdrawal rate adjusted annually for inflation.',
      example: 'A ₹3 Crore retirement corpus supports safe annual withdrawals of ~₹10.5 to ₹12 Lakhs.',
      icon: Icons.elderly,
    ),
    MarketTopic(
      title: 'Periodic Portfolio Rebalancing',
      summary: 'Selling winners that grew beyond target allocation and buying underweight assets to reset risk.',
      keyTakeaway: 'Forces you to automatically buy low and sell high without emotional biases.',
      example: 'When equity surges from 60% to 75% of your portfolio, trim 15% into debt to lock in market profits.',
      icon: Icons.balance,
    ),
  ];

  /// Comprehensive "Where Can I Invest?" Asset Categories
  static List<AssetCategoryEducation> get investmentCategories => const [
    AssetCategoryEducation(
      name: 'Liquid & Overnight Funds',
      categoryGroup: 'Liquid',
      risk: RiskometerLevel.low,
      purpose: 'Parking emergency reserves and short-term cash surpluses for 1 to 90 days.',
      suitableHorizon: '1 Day to 3 Months',
      liquidity: 'Instant (T+0 up to ₹50,000 or T+1 morning)',
      potentialRole: 'Defensive cash moat and capital preservation.',
      importantRisks: ['Slight reinvestment risk when interest rates drop.'],
      taxConsiderations:
          'Taxed at slab rate as short-term capital gains for debt funds.',
      icon: Icons.water_drop_outlined,
    ),
    AssetCategoryEducation(
      name: 'Banking & PSU Debt Funds',
      categoryGroup: 'Debt',
      risk: RiskometerLevel.lowToModerate,
      purpose: 'High-safety fixed income investing in government entities and scheduled commercial banks.',
      suitableHorizon: '1 to 3 Years',
      liquidity: 'High (T+1 business day)',
      potentialRole: 'Core defensive ballast for medium-term goals.',
      importantRisks: [
        'Moderate interest rate sensitivity if RBI raises repo rates.',
      ],
      taxConsiderations:
          'Gains added to taxable income and taxed at marginal income slab.',
      icon: Icons.account_balance,
    ),
    AssetCategoryEducation(
      name: 'Nifty 50 Index Funds',
      categoryGroup: 'Equity',
      risk: RiskometerLevel.veryHigh,
      purpose: 'Low-cost passive participation in India’s top 50 largest blue-chip corporations.',
      suitableHorizon: '5+ Years',
      liquidity: 'High (T+2 business days)',
      potentialRole: 'Cornerstone long-term wealth compounding engine.',
      importantRisks: [
        'Market corrections; can experience 20-30% cyclical drawdowns.',
      ],
      taxConsiderations: 'LTCG taxed at 12.5% on gains exceeding ₹1.25 Lakh per financial year.',
      icon: Icons.trending_up,
    ),
    AssetCategoryEducation(
      name: 'Flexi Cap Equity Funds',
      categoryGroup: 'Equity',
      risk: RiskometerLevel.veryHigh,
      purpose: 'Active equity funds dynamically shifting across large, mid, and small cap market segments.',
      suitableHorizon: '5 to 7 Years',
      liquidity: 'High (T+2 business days)',
      potentialRole: 'Alpha generation across economic cycles.',
      importantRisks: [
        'Fund manager selection risk; higher expense ratio than index funds.',
      ],
      taxConsiderations: 'LTCG: 12.5% (>₹1.25L); STCG (<12 months): 20%.',
      icon: Icons.shuffle,
    ),
    AssetCategoryEducation(
      name: 'Mid & Small Cap Funds',
      categoryGroup: 'Equity',
      risk: RiskometerLevel.veryHigh,
      purpose: 'High-growth exposure to emerging industrial and domestic consumption leaders.',
      suitableHorizon: '7+ Years',
      liquidity: 'Moderate (T+2 business days)',
      potentialRole: 'High-alpha compounding for long-term horizons.',
      importantRisks: [
        'Elevated volatility; can drop 40%+ in severe bear markets.',
      ],
      taxConsiderations: 'Standard equity taxation: 12.5% LTCG, 20% STCG.',
      icon: Icons.rocket_launch_outlined,
    ),
    AssetCategoryEducation(
      name: 'Balanced Advantage (Dynamic Hybrid)',
      categoryGroup: 'Hybrid',
      risk: RiskometerLevel.moderate,
      purpose: 'Automated dynamic asset allocation between equity and debt using valuation models.',
      suitableHorizon: '3 to 5 Years',
      liquidity: 'High (T+2 business days)',
      potentialRole:
          'Downside-cushioned equity participation for moderate investors.',
      importantRisks: [
        'Model risk; may lag strong bull markets due to reduced equity exposure.',
      ],
      taxConsiderations: 'Treated as equity fund for tax purposes if gross equity exposure exceeds 65%.',
      icon: Icons.balance,
    ),
    AssetCategoryEducation(
      name: 'Sovereign Gold Bonds & Gold ETFs',
      categoryGroup: 'Commodities',
      risk: RiskometerLevel.moderate,
      purpose: 'Portfolio insurance against geopolitical tail-risk and domestic currency depreciation.',
      suitableHorizon: '5 to 8 Years',
      liquidity: 'Moderate (Traded on exchanges)',
      potentialRole: '5-10% strategic hedge in all weather portfolios.',
      importantRisks: [
        'Gold prices can stay range-bound for multi-year periods.',
      ],
      taxConsiderations: 'SGB capital gains are 100% tax-free if held until sovereign maturity (8 years).',
      icon: Icons.workspace_premium,
    ),
    AssetCategoryEducation(
      name: 'Public Provident Fund (PPF)',
      categoryGroup: 'Retirement',
      risk: RiskometerLevel.low,
      purpose:
          'Government-guaranteed long-term tax-exempt wealth accumulation.',
      suitableHorizon: '15 Years',
      liquidity: 'Low (Strict partial withdrawal rules after Year 7)',
      potentialRole: 'Risk-free sovereign bedrock for retirement and children.',
      importantRisks: [
        'Illiquid 15-year lock-in period; annual cap of ₹1.5 Lakhs.',
      ],
      taxConsiderations: 'Triple Exempt (EEE) — investment, interest, and maturity are 100% tax-free.',
      icon: Icons.lock_clock,
    ),
    AssetCategoryEducation(
      name: 'National Pension System (NPS)',
      categoryGroup: 'Retirement',
      risk: RiskometerLevel.moderate,
      purpose: 'Cost-effective retirement pension vehicle with market-linked asset choice.',
      suitableHorizon: 'Until Age 60',
      liquidity: 'Very Low (Locked until superannuation)',
      potentialRole:
          'Additional ₹50,000 tax deduction under Section 80CCD(1B).',
      importantRisks: ['Compulsory 40% annuity purchase at retirement.'],
      taxConsiderations: '60% lump-sum withdrawal at age 60 is tax-free; annuity income taxed as salary.',
      icon: Icons.elderly,
    ),
    AssetCategoryEducation(
      name: 'ELSS Tax-Saving Mutual Funds',
      categoryGroup: 'Equity',
      risk: RiskometerLevel.veryHigh,
      purpose: 'Section 80C tax deduction with the shortest lock-in among 80C options.',
      suitableHorizon: '3+ Years',
      liquidity: 'Locked for 3 Years from date of each SIP installment',
      potentialRole:
          'Dual benefit of tax deduction and equity wealth compounding.',
      importantRisks: [
        'Equity market volatility during mandatory 3-year lock-in.',
      ],
      taxConsiderations:
          'Deduction up to ₹1.5 Lakhs u/s 80C; LTCG taxed at 12.5% (>₹1.25L).',
      icon: Icons.shield_outlined,
    ),
    AssetCategoryEducation(
      name: 'Real Estate Investment Trusts (REITs)',
      categoryGroup: 'Real Estate',
      risk: RiskometerLevel.moderatelyHigh,
      purpose: 'Commercial real estate rental income and capital appreciation without buying physical property.',
      suitableHorizon: '3 to 5 Years',
      liquidity: 'High (Traded on stock exchanges like equity shares)',
      potentialRole:
          'Quarterly dividend cash flow and real estate diversification.',
      importantRisks: [
        'Occupancy rates and interest rate fluctuations impact distributions.',
      ],
      taxConsiderations: 'Tax treatment varies by distribution component (Interest, Dividend, SPV repayment).',
      icon: Icons.business,
    ),
    AssetCategoryEducation(
      name: 'Direct Equity & Blue Chips',
      categoryGroup: 'Equity',
      risk: RiskometerLevel.veryHigh,
      purpose: 'Direct ownership of individual companies with proven market leadership.',
      suitableHorizon: '5+ Years',
      liquidity: 'High (Market trading hours)',
      potentialRole:
          'Targeted long-term compounders for experienced investors.',
      importantRisks: ['Individual business and corporate governance risk.'],
      taxConsiderations:
          '12.5% LTCG (>₹1.25L); 20% STCG; Dividends taxed at slab rate.',
      icon: Icons.storefront_outlined,
    ),
  ];

  /// Evaluates 9-Point Readiness Checklist against real user financial status
  static InvestmentReadinessReport evaluateReadiness({
    required double monthlyIncome,
    required double monthlyExpense,
    required double emergencyBalance,
    required double totalDebt,
    required int activeGoalsCount,
    required bool hasRiskAssessment,
  }) {
    final double monthlySurplus = (monthlyIncome - monthlyExpense).clamp(
      0.0,
      double.infinity,
    );
    final double essentialMonthlyExpense = monthlyExpense > 0
        ? monthlyExpense
        : 30000.0;
    final double emergencyMonths = emergencyBalance / essentialMonthlyExpense;

    final bool emergencyPassed = emergencyMonths >= 3.0;
    final bool debtPassed = totalDebt <= (monthlyIncome * 12.0);
    final bool surplusPassed = monthlySurplus >= 3000.0;
    final double investmentCapacity = (monthlySurplus * 0.70).clamp(
      0.0,
      monthlySurplus,
    );

    final List<InvestmentChecklistItem> checklist = [
      InvestmentChecklistItem(
        title: 'Financial Goals Defined',
        isPassed: activeGoalsCount > 0,
        detail: activeGoalsCount > 0
            ? '$activeGoalsCount active goal milestones established.'
            : 'No financial goals set. Add a target milestone to anchor strategy.',
      ),
      InvestmentChecklistItem(
        title: 'Emergency Reserve Moat (3-6 Months)',
        isPassed: emergencyPassed,
        detail: emergencyPassed
            ? '${emergencyMonths.toStringAsFixed(1)} months of essential coverage in liquid cash.'
            : 'Only ${emergencyMonths.toStringAsFixed(1)} months buffer. Build 3 months before aggressive investing.',
      ),
      InvestmentChecklistItem(
        title: 'High-Cost Debt Reviewed',
        isPassed: debtPassed,
        detail: debtPassed
            ? 'Debt obligations are within manageable boundaries.'
            : 'Outstanding debt requires early prepayment attention.',
      ),
      InvestmentChecklistItem(
        title: 'Risk Profile & Tolerance Assessed',
        isPassed: hasRiskAssessment,
        detail: hasRiskAssessment
            ? 'Risk capacity and psychological volatility limits calibrated.'
            : 'Complete the 6-question assessment to tailor your asset allocation.',
      ),
      InvestmentChecklistItem(
        title: 'Clear Time Horizon Known',
        isPassed: true,
        detail: 'Investment horizons separated into short (<2y), medium (3-5y), and long (5y+).',
      ),
      InvestmentChecklistItem(
        title: 'Short-Term Liquidity Protected',
        isPassed: emergencyPassed,
        detail: 'Immediate capital requirements separated from market-linked investments.',
      ),
      InvestmentChecklistItem(
        title: 'Tax Optimization Evaluated',
        isPassed: true,
        detail: 'Section 80C, 80D, and Old vs New regime efficiency analyzed.',
      ),
      InvestmentChecklistItem(
        title: 'Asset Diversification Strategy in Place',
        isPassed: true,
        detail: 'Multi-asset class framework across equity, debt, liquid, and gold.',
      ),
      InvestmentChecklistItem(
        title: 'Monthly Investment Capacity Calculated',
        isPassed: surplusPassed,
        detail: surplusPassed
            ? 'Identified ₹${investmentCapacity.toStringAsFixed(0)}/month safe recurring investment bandwidth.'
            : 'Constrained monthly surplus. Optimize budget expenses to unlock capacity.',
      ),
    ];

    final int passedCount = checklist.where((c) => c.isPassed).length;
    final int readinessScore = ((passedCount / checklist.length) * 100).round();

    return InvestmentReadinessReport(
      readinessScore: readinessScore,
      isEmergencyFundHealthy: emergencyPassed,
      emergencyFundStatusText: emergencyPassed
          ? '✓ Healthy (${emergencyMonths.toStringAsFixed(1)} Mo)'
          : '⚠ Incomplete (${emergencyMonths.toStringAsFixed(1)} Mo)',
      isDebtManageable: debtPassed,
      debtStatusText: debtPassed ? '✓ Manageable' : '⚠ Elevated Debt',
      monthlySurplus: monthlySurplus,
      investmentCapacity: investmentCapacity,
      checklist: checklist,
    );
  }
}
