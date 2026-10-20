import 'package:uuid/uuid.dart';

import '../../models/advisor_models.dart';
import '../../providers/finance_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/goal_provider.dart';
import '../../providers/investment_provider.dart';
import '../../providers/financial_health_provider.dart';
import '../../utils/currency_formatter.dart';
import 'advisor_intent_service.dart';
import 'affordability_service.dart';
import 'financial_xray_service.dart';
import 'goal_optimizer_service.dart';
import 'what_if_service.dart';
import 'financial_dna_service.dart';
import 'investment_reasoning_service.dart';

class AdvisorEngine {
  final AdvisorIntentService _intentService = AdvisorIntentService();

  AdvisorResponse evaluate({
    required String query,
    required FinanceProvider finance,
    required BudgetProvider budget,
    required GoalProvider goals,
    required InvestmentProvider investments,
    required FinancialHealthProvider health,
  }) {
    final intent = _intentService.detectIntent(query);
    final entities = _intentService.extractEntities(query);

    final double income = finance.monthlyIncome > 0
        ? finance.monthlyIncome
        : 65000.0;
    final double expense = finance.monthlyExpense;
    final double surplus = income - expense;
    final double savingsRate = income > 0
        ? ((surplus / income) * 100).clamp(-100.0, 100.0)
        : 0.0;
    final double liquidBalance = finance.balance > 0
        ? finance.balance
        : (surplus * 3.0);
    final double monthlyBurn = expense > 0 ? expense : (income * 0.7);
    final double emergencyMonths = monthlyBurn > 0
        ? (liquidBalance / monthlyBurn)
        : 2.5;

    final String currentPosition =
        'Monthly Inflows: ${CurrencyFormatter.format(income)} | Outflows: ${CurrencyFormatter.format(expense)} | Surplus: ${CurrencyFormatter.format(surplus)} | Emergency Runway: ${emergencyMonths.toStringAsFixed(1)} mo';

    switch (intent) {
      case AdvisorIntent.affordability:
      case AdvisorIntent.purchase:
      case AdvisorIntent.car:
      case AdvisorIntent.home:
      case AdvisorIntent.travel:
        final double targetPrice =
            entities.amount ??
            (intent == AdvisorIntent.car
                ? 800000.0
                : (intent == AdvisorIntent.home ? 5000000.0 : 45000.0));
        final String productName =
            entities.product ??
            (intent == AdvisorIntent.car
                ? 'Car'
                : (intent == AdvisorIntent.home
                      ? 'Home Down Payment'
                      : 'Target Purchase'));

        final affordability = AffordabilityService.evaluatePurchase(
          product: productName,
          price: targetPrice,
          timeframe: entities.timeframe,
          finance: finance,
          budget: budget,
          goals: goals,
        );

        String verdictStr;
        switch (affordability.verdict) {
          case DecisionVerdict.safe:
            verdictStr = 'SAFE TO BUY';
            break;
          case DecisionVerdict.good:
            verdictStr = 'APPROVED WITH PACING';
            break;
          case DecisionVerdict.possible:
            verdictStr = 'POSSIBLE (SAVE FIRST)';
            break;
          case DecisionVerdict.tight:
            verdictStr = 'TIGHT BUDGET';
            break;
          case DecisionVerdict.notRecommended:
            verdictStr = 'NOT RECOMMENDED';
            break;
        }

        return AdvisorResponse(
          id: const Uuid().v4(),
          userQuery: query,
          intent: intent,
          verdict: verdictStr,
          currentPosition: currentPosition,
          calculation:
              'Purchase Cost: ${CurrencyFormatter.format(targetPrice)} | Affordability Score: ${affordability.affordabilityScore.toStringAsFixed(0)}/100 | Post-Purchase Runway: ${affordability.remainingEmergencyMonths.toStringAsFixed(1)} months | Budget Impact: ${affordability.budgetImpactPercentage.toStringAsFixed(0)}%',
          reasoning: affordability.reasoning,
          risks: affordability.remainingEmergencyMonths < 3.0
              ? 'Draws defensive liquid reserves below the 3-month threshold. Vulnerable to sudden unexpected liabilities.'
              : 'Minimal downside risk. Maintain standard monthly allocation to active savings targets.',
          recommendation: affordability.recommendedAction,
          alternatives: affordability.alternative,
          nextAction: affordability.verdict == DecisionVerdict.safe
              ? 'Record expense in Smart Receipt once purchased.'
              : 'Create a dedicated savings goal to fund this without liquidity erosion.',
          actionRoute: affordability.verdict == DecisionVerdict.safe
              ? 'receipt'
              : 'goals',
          cardType: AdvisorCardType.affordability,
          cardPayload: affordability.toJson(),
          timestamp: DateTime.now(),
        );

      case AdvisorIntent.financialHealth:
        final xray = FinancialXRayService.analyzeFinances(
          finance: finance,
          budget: budget,
          goals: goals,
          investments: investments,
        );

        return AdvisorResponse(
          id: const Uuid().v4(),
          userQuery: query,
          intent: intent,
          verdict:
              'OVERALL SCORE: ${xray.overallScore.toStringAsFixed(0)}/100 (${xray.rating.toUpperCase()})',
          currentPosition: currentPosition,
          calculation:
              '8-Pillar Score Average: ${xray.overallScore.toStringAsFixed(1)} | Cash Flow: ${xray.pillars[0].score.toStringAsFixed(0)} | Savings: ${xray.pillars[1].score.toStringAsFixed(0)} | Debt: ${xray.pillars[2].score.toStringAsFixed(0)} | Safety: ${xray.pillars[7].score.toStringAsFixed(0)}',
          reasoning:
              'Your financial foundation demonstrates ${xray.topStrengths.first}. Primary area for optimization: ${xray.priorityVulnerabilities.first}.',
          risks: 'Concentration risk in cash vs investments, or low emergency runway if unexpected income disruptions occur.',
          recommendation: 'Follow the 8-pillar audit: Automate savings on salary credit day and direct at least 20% into long-term compounding assets.',
          alternatives: 'Prioritize building a strict 3-month emergency fund before initiating aggressive non-liquid investments.',
          nextAction: 'Review full Financial X-Ray pillar metrics.',
          actionRoute: 'xray',
          cardType: AdvisorCardType.financialXRay,
          cardPayload: xray.toJson(),
          timestamp: DateTime.now(),
        );

      case AdvisorIntent.goalOptimization:
      case AdvisorIntent.goal:
        final opt = GoalOptimizerService.optimizeGoals(
          goalProvider: goals,
          finance: finance,
        );

        return AdvisorResponse(
          id: const Uuid().v4(),
          userQuery: query,
          intent: intent,
          verdict: 'BEST NEXT GOAL: "${opt.bestNextGoalTitle.toUpperCase()}"',
          currentPosition: currentPosition,
          calculation:
              'Total Monthly Target Requirement: ${CurrencyFormatter.format(opt.totalMonthlyRequired)} | Available Surplus: ${CurrencyFormatter.format(opt.availableMonthlySurplus)} | ${opt.monthlyDeficitOrSurplus >= 0 ? 'Surplus Headroom: +' : 'Funding Gap: '}${CurrencyFormatter.format(opt.monthlyDeficitOrSurplus)}',
          reasoning: opt.bestNextGoalReason,
          risks: opt.monthlyDeficitOrSurplus < 0
              ? 'Attempting to fund all goals simultaneously spreads capital too thin, risking missed deadlines across all milestones.'
              : 'All goals are mathematically viable within current cash flow velocity.',
          recommendation: opt.strategicAdvice,
          alternatives: 'Extend lower-priority goal deadlines by 90 days to eliminate monthly cash flow friction.',
          nextAction: 'Allocate funds to "${opt.bestNextGoalTitle}".',
          actionRoute: 'goals',
          cardType: AdvisorCardType.goalOptimization,
          cardPayload: opt.toJson(),
          timestamp: DateTime.now(),
        );

      case AdvisorIntent.futureSimulation:
        final double incomeDelta =
            entities.amount != null && query.toLowerCase().contains('increase')
            ? entities.amount!
            : 15000.0;
        final sim = WhatIfService.simulateScenario(
          finance: finance,
          incomeDelta: incomeDelta,
          scenarioDescription:
              'Projected Monthly Income Hike (+${CurrencyFormatter.format(incomeDelta)})',
        );

        return AdvisorResponse(
          id: const Uuid().v4(),
          userQuery: query,
          intent: intent,
          verdict:
              'SCENARIO PROJECTION: +${CurrencyFormatter.format(sim.monthlyDelta)}/MONTH SURPLUS',
          currentPosition: currentPosition,
          calculation:
              'Current Savings: ${CurrencyFormatter.format(sim.baselineMonthlySavings)} (${sim.baselineSavingsRate.toStringAsFixed(0)}%) \u2192 Projected Savings: ${CurrencyFormatter.format(sim.projectedMonthlySavings)} (${sim.projectedSavingsRate.toStringAsFixed(0)}%)',
          reasoning: sim.strategicInsight,
          risks: 'Lifestyle inflation: Ensure increased earnings are routed to automated investments before expanding discretionary budget lines.',
          recommendation: sim.goalImpactSummary,
          alternatives: 'Split the extra surplus 50% into index investing and 50% into accelerating your top priority goal.',
          nextAction: 'Open What-If Simulator for custom adjustments.',
          actionRoute: 'simulator',
          cardType: AdvisorCardType.whatIf,
          cardPayload: sim.toJson(),
          timestamp: DateTime.now(),
        );

      case AdvisorIntent.investment:
      case AdvisorIntent.portfolio:
        if (entities.amount != null && entities.amount! >= 1000) {
          final lumpSumReport =
              InvestmentReasoningService.evaluateLumpSumStrategy(
            lumpSum: entities.amount!,
            finance: finance,
            investments: investments,
          );

          final summaryBuffer = StringBuffer();
          summaryBuffer.writeln(
              '### **PORTFOLIO DEPLOYMENT: ${CurrencyFormatter.format(lumpSumReport.principal)}**');
          summaryBuffer.writeln();
          summaryBuffer.writeln(lumpSumReport.emergencyFundStatus);
          summaryBuffer.writeln();
          summaryBuffer.writeln('**Suitable Investment Categories by Horizon:**');
          summaryBuffer.writeln(lumpSumReport.suitableCategories);
          summaryBuffer.writeln();
          summaryBuffer.writeln(
              '**Compound Growth Scenarios (over ${lumpSumReport.durationYears} Years - Formula: FV = P × (1+r)^t):**');
          summaryBuffer.writeln(
              '• **Conservative (${lumpSumReport.pessimisticRate}% p.a. - Debt/FD):** Estimated Ending Value: **${CurrencyFormatter.format(lumpSumReport.pessimisticCorpus)}** (+${CurrencyFormatter.format(lumpSumReport.pessimisticGain)})');
          summaryBuffer.writeln(
              '• **Illustrative (${lumpSumReport.illustrativeRate}% p.a. - Nifty 50 Index / Hybrid):** Estimated Ending Value: **${CurrencyFormatter.format(lumpSumReport.illustrativeCorpus)}** (+${CurrencyFormatter.format(lumpSumReport.illustrativeGain)})');
          summaryBuffer.writeln(
              '• **Optimistic (${lumpSumReport.optimisticRate}% p.a. - Diversified Equity):** Estimated Ending Value: **${CurrencyFormatter.format(lumpSumReport.optimisticCorpus)}** (+${CurrencyFormatter.format(lumpSumReport.optimisticGain)})');
          summaryBuffer.writeln();
          summaryBuffer.writeln('**Suggested Asset Allocation:**');
          lumpSumReport.suggestedAllocation.forEach((asset, pct) {
            summaryBuffer.writeln(
                '• $asset: **${pct.toStringAsFixed(0)}%** (${CurrencyFormatter.format(lumpSumReport.principal * pct / 100.0)})');
          });
          summaryBuffer.writeln();
          summaryBuffer.writeln('**Tax Considerations:**');
          summaryBuffer.writeln(lumpSumReport.taxImplications);
          summaryBuffer.writeln();
          summaryBuffer.writeln('**Next Steps & Implementation:**');
          summaryBuffer.writeln(lumpSumReport.nextSteps);
          summaryBuffer.writeln();
          summaryBuffer.writeln('*${lumpSumReport.educationalDisclaimer}*');

          return AdvisorResponse(
            id: const Uuid().v4(),
            userQuery: query,
            intent: intent,
            verdict:
                'INVESTMENT OUTCOME: ${CurrencyFormatter.format(lumpSumReport.principal)} DEPLOYMENT',
            currentPosition: currentPosition,
            calculation:
                'Pessimistic (${lumpSumReport.pessimisticRate}%): ${CurrencyFormatter.format(lumpSumReport.pessimisticCorpus)} | Illustrative (${lumpSumReport.illustrativeRate}%): ${CurrencyFormatter.format(lumpSumReport.illustrativeCorpus)} | Optimistic (${lumpSumReport.optimisticRate}%): ${CurrencyFormatter.format(lumpSumReport.optimisticCorpus)}',
            reasoning: summaryBuffer.toString(),
            risks:
                'Market volatility, inflation risk, and sequence of returns risk. Short-term values fluctuate. Ensure emergency funds are held before committing non-liquid capital.',
            recommendation:
                'Deploy via a Systematic Transfer Plan (STP) over 6 to 10 months rather than an impulsive single-day lump sum purchase.',
            alternatives:
                'High-cost debt repayment offers guaranteed post-tax return outperforming market equities.',
            nextAction: 'Explore asset breakdown in Investment Desk.',
            actionRoute: 'investments',
            cardType: AdvisorCardType.investment,
            cardPayload: {
              'principal': lumpSumReport.principal,
              'pessimistic': lumpSumReport.pessimisticCorpus,
              'illustrative': lumpSumReport.illustrativeCorpus,
              'optimistic': lumpSumReport.optimisticCorpus,
              'allocation': lumpSumReport.suggestedAllocation,
              'disclaimer': lumpSumReport.educationalDisclaimer,
            },
            timestamp: DateTime.now(),
          );
        }

        final report = InvestmentReasoningService.evaluateStrategy(
          finance: finance,
          investments: investments,
        );

        return AdvisorResponse(
          id: const Uuid().v4(),
          userQuery: query,
          intent: intent,
          verdict:
              'RECOMMENDED SIP: ${CurrencyFormatter.format(report.recommendedMonthlySip)}/MONTH',
          currentPosition: currentPosition,
          calculation:
              'Current Portfolio: ${CurrencyFormatter.format(investments.totalCurrentValue)} | Net Returns: ${CurrencyFormatter.format(investments.totalReturns)} (${investments.totalReturnPercentage.toStringAsFixed(1)}%) | Allocation Target: 70% Equity / 30% Debt & Gold',
          reasoning: report.projectionIllustration,
          risks:
              'Market risk & volatility. Equity investments fluctuate in the short-to-medium term. Maintain a 5+ year investment horizon.',
          recommendation:
              'Automate systematic investments on salary day across broad low-cost index funds and debt instruments.',
          alternatives: report.debtVsInvestAdvice,
          nextAction: 'Explore asset breakdown in Investment Desk.',
          actionRoute: 'investments',
          cardType: AdvisorCardType.investment,
          cardPayload: {
            'sip': report.recommendedMonthlySip,
            'allocation': report.assetAllocationPercentages,
            'illustration': report.projectionIllustration,
            'disclaimer': report.educationalDisclaimer,
          },
          timestamp: DateTime.now(),
        );

      case AdvisorIntent.debt:
      case AdvisorIntent.emi:
        return AdvisorResponse(
          id: const Uuid().v4(),
          userQuery: query,
          intent: intent,
          verdict: 'DEBT AUDIT: AVALANCHE & HOME LOAN SPREAD',
          currentPosition: currentPosition,
          calculation:
              'Available Discretionary Surplus: ${CurrencyFormatter.format(surplus)} | High-Cost Debt Benchmark: >12% APR (Immediate Payoff) | Low-Cost Secured Debt: 8.5% (Home Loan)',
          reasoning:
              'Chartered Accountant Debt Prioritization Framework:\n\n'
              '1. **Unsecured & Revolving Debt (Credit Cards, Personal Loans, BNPL)**: Costing 18% to 42% APR. Every rupee used to eliminate this yields an unbeatable, guaranteed, tax-free return equal to the interest rate. Deploy 100% of excess surplus via the Debt Avalanche method until zero.\n\n'
              '2. **Home Loan Prepayment vs. Equity SIP (The 8.5% vs 12% Math)**:\n'
              '   • Home loan interest: ~8.5% p.a.\n'
              '   • Equity Index expected CAGR: ~12.0% p.a. (net ~10.5% post-LTCG).\n'
              '   • Mathematical verdict: Equity investing yields a net +2% positive spread over loan prepayment over 10+ years.\n\n'
              '3. **The 1-Extra-EMI Hybrid Hack**: Pay just 1 additional EMI every calendar year, or increase your EMI by 5% annually. On a 20-year ₹50 Lakh loan, this single move cuts your repayment tenure to ~12 years and saves over ₹18 Lakhs in interest—while leaving your regular monthly surplus free to compound in mutual funds!',
          risks:
              'Prepaying low-cost home loans aggressively by draining your liquid emergency fund leaves you asset-rich but cash-poor, forcing you into expensive personal loans if an emergency strikes.',
          recommendation:
              'Apply the 1-extra-EMI hack to your long-term home loan. Route all remaining monthly surplus into broad equity index SIPs for superior compounding.',
          alternatives:
              'If you have credit card balances or personal loans, halt all equity investments temporarily until those high-APR balances are completely liquidated.',
          nextAction: 'Review Monthly Budget & Recurring EMIs.',
          actionRoute: 'budget',
          cardType: AdvisorCardType.none,
          timestamp: DateTime.now(),
        );

      case AdvisorIntent.tax:
        final annualIncome = income * 12.0;
        // Budget 2024 New Regime Math (FY 2024-25):
        // Standard Deduction: ₹75,000
        // Slabs: 0-3L 0%, 3-7L 5%, 7-10L 10%, 10-12L 15%, 12-15L 20%, >15L 30%
        // Sec 87A rebate makes taxable income <= 7.0L tax-free (Gross <= 7.75L tax-free).
        double taxableNew = (annualIncome - 75000.0).clamp(0.0, double.infinity);
        double taxNew = 0.0;
        if (taxableNew <= 700000.0) {
          taxNew = 0.0; // Sec 87A rebate
        } else {
          double remaining = taxableNew;
          if (remaining > 1500000.0) {
            taxNew += (remaining - 1500000.0) * 0.30;
            remaining = 1500000.0;
          }
          if (remaining > 1200000.0) {
            taxNew += (remaining - 1200000.0) * 0.20;
            remaining = 1200000.0;
          }
          if (remaining > 1000000.0) {
            taxNew += (remaining - 1000000.0) * 0.15;
            remaining = 1000000.0;
          }
          if (remaining > 700000.0) {
            taxNew += (remaining - 700000.0) * 0.10;
            remaining = 700000.0;
          }
          if (remaining > 300000.0) {
            taxNew += (remaining - 300000.0) * 0.05;
          }
          taxNew = taxNew * 1.04; // 4% Health & Education cess
        }

        final breakevenDeductions = annualIncome > 1500000.0 ? 425000.0 : 375000.0;

        return AdvisorResponse(
          id: const Uuid().v4(),
          userQuery: query,
          intent: intent,
          verdict: annualIncome <= 775000.0
              ? 'TAX VERDICT: NEW REGIME (100% TAX-FREE)'
              : 'TAX VERDICT: NEW REGIME RECOMMENDED',
          currentPosition: currentPosition,
          calculation:
              'Annual Gross Income: ${CurrencyFormatter.format(annualIncome)} | New Regime Tax: ${CurrencyFormatter.format(taxNew)} (incl. 4% Cess) | Standard Deduction: ₹75,000 | Deduction Breakeven: ${CurrencyFormatter.format(breakevenDeductions)}',
          reasoning:
              'Under Budget 2024 amendments (FY 2024-25):\n\n'
              '1. **New Tax Regime**: Standard deduction is increased to **₹75,000**. Slabs are adjusted (5% up to ₹7L, 10% up to ₹10L, 15% up to ₹12L, 20% up to ₹15L, 30% above ₹15L). With Section 87A rebate, gross income up to **₹7.75 Lakhs is effectively 100% tax-free**.\n\n'
              '2. **Old vs New Breakeven**: Unless your total eligible deductions under Sec 80C (₹1.5L), 80D (Health Insurance), HRA, and Sec 24(b) (Home loan interest) exceed **${CurrencyFormatter.format(breakevenDeductions)}**, the **New Tax Regime saves you more net cash** with zero lock-in hassle.\n\n'
              '3. **Capital Gains Update**: Equity LTCG above ₹1.25 Lakhs is taxed at 12.5% (held > 12 months); STCG is taxed at 20%.',
          risks:
              'Opting for Old Regime without verified proof (rent receipts for HRA, 80D receipts, home loan interest certificate) leads to heavy tax demands and interest under Sec 234B/234C at ITR filing.',
          recommendation:
              'Default to the New Tax Regime. Stop locking liquid capital into sub-optimal 80C products (like low-yield insurance or 5-year FDs) purely to save tax; invest the extra take-home pay in low-cost index funds instead.',
          alternatives:
              'If you pay high rent in a metro or have a running home loan interest > ₹2 Lakhs, run a side-by-side computation with your Form 16 before filing.',
          nextAction: 'Review Monthly Budget & Cash Flow.',
          actionRoute: 'budget',
          cardType: AdvisorCardType.none,
          timestamp: DateTime.now(),
        );

      case AdvisorIntent.retirement:
        final annualBurn = monthlyBurn * 12.0;
        final targetCorpusToday = annualBurn * 30.0;
        final futureCorpus20Yr = targetCorpusToday * 3.207;
        final requiredSip = (futureCorpus20Yr * 0.01) / 8.992;

        return AdvisorResponse(
          id: const Uuid().v4(),
          userQuery: query,
          intent: intent,
          verdict: 'FIRE NUMBER: ${CurrencyFormatter.format(targetCorpusToday)} (30× ANNUAL EXPENSES)',
          currentPosition: currentPosition,
          calculation:
              'Current Annual Living Expenses: ${CurrencyFormatter.format(annualBurn)} | Today\'s Target Corpus (30× Rule): ${CurrencyFormatter.format(targetCorpusToday)} | 20-Yr Inflation-Adjusted Corpus (at 6%): ${CurrencyFormatter.format(futureCorpus20Yr)} | Required SIP (at 12% CAGR): ${CurrencyFormatter.format(requiredSip)}/month',
          reasoning:
              'Authoritative Indian Retirement Math:\n\n'
              '1. **The 30× Corpus Standard**: A sustainable Safe Withdrawal Rate (SWR) in India is 3.0% - 3.33% (higher than US 4% rule due to 6% domestic healthcare & lifestyle inflation). You need 30× your annual baseline living expenses today.\n\n'
              '2. **Inflation Drag**: What costs ${CurrencyFormatter.format(annualBurn)} today will require ${CurrencyFormatter.format(annualBurn * 3.207)} annually in 20 years. Your capital must beat inflation after tax.\n\n'
              '3. **Asset Allocation Architecture**: Maintain 60% in Broad Market Equity (Nifty 50 / Flexicap), 30% in Fixed Income (EPF / PPF / Debt Index), and 10% in Sovereign Gold Bonds / Gold ETF.',
          risks:
              'Holding retirement savings predominantly in Fixed Deposits or traditional endowment policies guarantees wealth erosion, as post-tax real returns are negative (-1% to 0% after 6% inflation).',
          recommendation:
              'Automate an SIP of at least ${CurrencyFormatter.format(requiredSip)}/month into broad equity index funds, stepping it up by 10% annually with salary increments (Step-Up SIP).',
          alternatives:
              'Utilize Voluntary Provident Fund (VPF) and PPF for the guaranteed debt portion, and Tier-1 NPS for an extra ₹50,000 deduction under Sec 80CCD(1B) if on Old Regime.',
          nextAction: 'Explore Investment Desk to set up automated SIP.',
          actionRoute: 'investments',
          cardType: AdvisorCardType.none,
          timestamp: DateTime.now(),
        );

      case AdvisorIntent.insurance:
        final annualIncome = income * 12.0;
        final targetTermCoverMin = annualIncome * 15.0;
        final targetTermCoverMax = annualIncome * 20.0;

        return AdvisorResponse(
          id: const Uuid().v4(),
          userQuery: query,
          intent: intent,
          verdict: 'INSURANCE AUDIT: PURE RISK PROTECTION ONLY',
          currentPosition: currentPosition,
          calculation:
              'Target Term Life Cover (15–20× Annual Income): ${CurrencyFormatter.format(targetTermCoverMin)} to ${CurrencyFormatter.format(targetTermCoverMax)} | Base Health Moat: ₹10L–₹15L | Super Top-Up Moat: ₹50L to ₹1 Cr',
          reasoning:
              'Non-Negotiable CA Risk Management Rules:\n\n'
              '1. **Never Mix Insurance and Investment**: Terminate or avoid ULIPs, endowment policies, and money-back plans. Their internal rate of return (IRR) is a dismal 4.5% - 5.5%, barely matching inflation, while burdening you with high upfront commissions.\n\n'
              '2. **Pure Term Life Cover**: Buy pure term insurance covering till age 60 or 65. Avoid return-of-premium (TROP) riders—they cost 2× to 3× more for negligible economic benefit.\n\n'
              '3. **Comprehensive Health Moat**: Corporate health insurance terminates the day you leave your job. Take an individual/family floater with ₹10 Lakhs base + ₹50 Lakhs to ₹1 Crore Super Top-Up (with ₹10L deductible) for cost-effective massive medical security.',
          risks:
              'Under-insuring leaves dependents exposed to catastrophic liabilities. Relying solely on corporate group mediclaim is the #1 medical bankruptcy cause during career gaps.',
          recommendation:
              'Secure a pure term policy of ${CurrencyFormatter.format(targetTermCoverMin)} immediately. Buy directly online from an insurer with > 98% Claim Settlement Ratio (CSR).',
          alternatives:
              'If you currently hold traditional LIC endowment policies with poor returns, calculate paid-up value and redirect premium into equity index SIPs.',
          nextAction: 'Review Emergency Fund & Liquid Reserves.',
          actionRoute: 'goals',
          cardType: AdvisorCardType.none,
          timestamp: DateTime.now(),
        );

      case AdvisorIntent.education:
        final targetEdu = entities.amount ?? 2000000.0;
        return AdvisorResponse(
          id: const Uuid().v4(),
          userQuery: query,
          intent: intent,
          verdict: 'HIGHER EDUCATION CAPITAL PLANNING: ${CurrencyFormatter.format(targetEdu)}',
          currentPosition: currentPosition,
          calculation:
              'Target Corpus: ${CurrencyFormatter.format(targetEdu)} | Education Inflation Benchmark: 10% p.a. | Sec 80E Tax Deduction: 100% interest deductible for 8 years (Old Regime)',
          reasoning:
              '1. **Education Inflation**: Higher education costs in India and abroad inflate at 8% to 10% annually, doubling every 7-8 years.\n\n'
              '2. **Funding Ladder**:\n'
              '   • Horizon > 5 Years: Multi-cap and Flexi-cap equity index funds.\n'
              '   • Horizon 2–4 Years: Balanced Advantage / Conservative Hybrid funds.\n'
              '   • Horizon < 2 Years: Short-term debt funds / Bank FDs to preserve nominal capital.\n\n'
              '3. **Education Loan Leverage**: If on the Old Tax Regime, Section 80E provides an unlimited deduction on interest paid on education loans for up to 8 years, reducing effective borrowing cost to ~6.5%.',
          risks:
              'Taking high-interest uncollateralized NBFC education loans (> 13% APR) without clear job placement visibility creates severe early-career cash drag.',
          recommendation:
              'Build a dedicated education goal in FinPilot with a monthly automated allocation.',
          alternatives:
              'Compare nationalized bank loans (SBI Student Loan Scheme) against private lenders for substantially lower rates and moratorium benefits.',
          nextAction: 'Create Education Savings Goal.',
          actionRoute: 'goals',
          cardType: AdvisorCardType.none,
          timestamp: DateTime.now(),
        );

      case AdvisorIntent.budget:
      case AdvisorIntent.expense:
      case AdvisorIntent.cashFlow:
        final foodSpend = finance.monthlyCategorySpent['Food'] ?? 0.0;
        final shoppingSpend = finance.monthlyCategorySpent['Shopping'] ?? 0.0;
        return AdvisorResponse(
          id: const Uuid().v4(),
          userQuery: query,
          intent: intent,
          verdict: surplus >= 0 ? 'HEALTHY SURPLUS' : 'DEFICIT ALERT',
          currentPosition: currentPosition,
          calculation:
              'Monthly Outflows: ${CurrencyFormatter.format(expense)} | Food & Dining: ${CurrencyFormatter.format(foodSpend)} | Shopping: ${CurrencyFormatter.format(shoppingSpend)} | Savings Rate: ${savingsRate.toStringAsFixed(0)}%',
          reasoning:
              'Your discretionary outflows represent a meaningful portion of total monthly spend. Trimming discretionary orders by 15% would immediately yield ~${CurrencyFormatter.format((foodSpend + shoppingSpend) * 0.15)} in extra monthly cash.',
          risks: 'Unchecked lifestyle creep will erode monthly savings rate and delay goal achievement by several quarters.',
          recommendation: 'Implement a category budget cap for Food & Shopping to lock in your planned savings rate.',
          alternatives: 'Use the 48-hour rule for non-essential online purchases above ₹2,000 to minimize impulse buying.',
          nextAction: 'Review and set category caps in Budget Screen.',
          actionRoute: 'budget',
          cardType: AdvisorCardType.none,
          timestamp: DateTime.now(),
        );

      case AdvisorIntent.emergencyFund:
        final targetFund = monthlyBurn * 6.0;
        final shortfall = (targetFund - liquidBalance).clamp(0.0, 5000000.0);
        return AdvisorResponse(
          id: const Uuid().v4(),
          userQuery: query,
          intent: intent,
          verdict: emergencyMonths >= 6.0
              ? 'FULLY SECURED'
              : (emergencyMonths >= 3.0 ? 'SUFFICIENT' : 'VULNERABLE'),
          currentPosition: currentPosition,
          calculation:
              'Current Liquid Reserve: ${CurrencyFormatter.format(liquidBalance)} (${emergencyMonths.toStringAsFixed(1)} months) | 6-Month Target: ${CurrencyFormatter.format(targetFund)} | Shortfall: ${CurrencyFormatter.format(shortfall)}',
          reasoning: 'An emergency fund preserves your financial independence without forcing premature asset liquidation or credit borrowing during unexpected job transitions or health needs.',
          risks: 'Holding under 3 months liquid coverage leaves you vulnerable to sudden medical or income emergencies.',
          recommendation: 'Park your emergency reserves in high-yield liquid mutual funds or flexible bank fixed deposits for instant accessibility.',
          alternatives:
              'Save ${CurrencyFormatter.format(shortfall / 6)}/month over the next 6 months to reach your full 6-month safety moat.',
          nextAction: 'Create Emergency Fund Goal.',
          actionRoute: 'goals',
          cardType: AdvisorCardType.none,
          timestamp: DateTime.now(),
        );

      default:
        // General financial advisory query or greeting
        final dna = FinancialDNAService.evaluateDNA(
          finance: finance,
          goals: goals,
          investments: investments,
        );

        final lowerQ = query.toLowerCase().trim();
        final isGreeting = [
          'hi',
          'hello',
          'hey',
          'greetings',
          'who are you',
          'help',
          'what can you do',
          'good morning',
          'good evening',
          'start',
        ].any((w) =>
            lowerQ == w ||
            lowerQ.startsWith('$w ') ||
            lowerQ.endsWith(' $w') ||
            lowerQ.contains(' $w '));

        if (isGreeting) {
          return AdvisorResponse(
            id: const Uuid().v4(),
            userQuery: query,
            intent: intent,
            verdict: 'EXECUTIVE FINANCIAL AUDIT & WEALTH DESK',
            currentPosition: currentPosition,
            calculation:
                'Monthly Inflows: ${CurrencyFormatter.format(income)} | Outflows: ${CurrencyFormatter.format(expense)} | Monthly Surplus: ${CurrencyFormatter.format(surplus)} | Emergency Runway: ${emergencyMonths.toStringAsFixed(1)} mo | Savings Rate: ${savingsRate.toStringAsFixed(0)}%',
            reasoning:
                'I am your **FinPilot AI Coach & Chartered Wealth Architect**. I provide authoritative, mathematically backed personal finance and tax strategy grounded in your live financial numbers.\n\n'
                '**Your Immediate Financial Health Summary:**\n'
                '• **Cash Flow**: You generate **${CurrencyFormatter.format(surplus)}/month** in investable surplus.\n'
                '• **Defensive Runway**: You have **${emergencyMonths.toStringAsFixed(1)} months** of living expenses in liquid buffer (benchmark: 6.0 months).\n'
                '• **Savings Velocity**: Current savings rate is **${savingsRate.toStringAsFixed(0)}%** (target: ≥ 20%).\n\n'
                '**How can I assist your balance sheet today?**\n'
                '1. *"Which tax regime should I choose (Old vs New)?"*\n'
                '2. *"Should I prepay my home loan or invest in mutual funds?"*\n'
                '3. *"How much do I need to retire (FIRE number)?"*\n'
                '4. *"Can I afford to buy an iPhone for ₹80,000?"*\n'
                '5. *"Analyze my finances (Run Financial X-Ray)"*',
            risks: emergencyMonths < 3.0
                ? 'Your liquid emergency runway is below 3 months. Priority should be building a ${CurrencyFormatter.format(monthlyBurn * 3)} buffer before illiquid commitments.'
                : 'Maintain discipline against discretionary lifestyle inflation.',
            recommendation:
                'Review your asset allocation or run a full Financial X-Ray to audit all 8 pillars of your net worth.',
            alternatives:
                'Ask any specific tax, debt, investment, or purchase question for an exact mathematical verdict.',
            nextAction: 'Run 8-Pillar Financial X-Ray.',
            actionRoute: 'xray',
            cardType: AdvisorCardType.financialDNA,
            cardPayload: dna.toJson(),
            timestamp: DateTime.now(),
          );
        }

        return AdvisorResponse(
          id: const Uuid().v4(),
          userQuery: query,
          intent: intent,
          verdict: 'FINANCIAL DNA: ${dna.archetype.toUpperCase()}',
          currentPosition: currentPosition,
          calculation:
              'Discipline Score: ${dna.financialDisciplineScore.toStringAsFixed(0)}/100 | Core Archetype: ${dna.archetype} | Secondary: ${dna.secondaryArchetype}',
          reasoning:
              'Based on your actual records: ${dna.evidencePoints.first} ${dna.coreTrait}.',
          risks: 'Failing to regularly audit discretionary spending can quietly compound into long-term wealth drag.',
          recommendation:
              'Growth Opportunity: ${dna.growthOpportunity}. Maintain at least a 20% savings velocity.',
          alternatives: 'Explore "Analyze My Finances" or "Can I Afford This?" for instant deep-dive calculations.',
          nextAction: 'Run Financial X-Ray.',
          actionRoute: 'xray',
          cardType: AdvisorCardType.financialDNA,
          cardPayload: dna.toJson(),
          timestamp: DateTime.now(),
        );
    }
  }
}
