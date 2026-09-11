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

    final double income = finance.monthlyIncome > 0 ? finance.monthlyIncome : 65000.0;
    final double expense = finance.monthlyExpense;
    final double surplus = income - expense;
    final double savingsRate = income > 0 ? ((surplus / income) * 100).clamp(-100.0, 100.0) : 0.0;
    final double liquidBalance = finance.balance > 0 ? finance.balance : (surplus * 3.0);
    final double monthlyBurn = expense > 0 ? expense : (income * 0.7);
    final double emergencyMonths = monthlyBurn > 0 ? (liquidBalance / monthlyBurn) : 2.5;

    final String currentPosition =
        'Monthly Inflows: ${CurrencyFormatter.format(income)} | Outflows: ${CurrencyFormatter.format(expense)} | Surplus: ${CurrencyFormatter.format(surplus)} | Emergency Runway: ${emergencyMonths.toStringAsFixed(1)} mo';

    switch (intent) {
      case AdvisorIntent.affordability:
      case AdvisorIntent.purchase:
      case AdvisorIntent.car:
      case AdvisorIntent.home:
      case AdvisorIntent.travel:
        final double targetPrice = entities.amount ?? (intent == AdvisorIntent.car ? 800000.0 : (intent == AdvisorIntent.home ? 5000000.0 : 45000.0));
        final String productName = entities.product ?? (intent == AdvisorIntent.car ? 'Car' : (intent == AdvisorIntent.home ? 'Home Down Payment' : 'Target Purchase'));

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
          actionRoute: affordability.verdict == DecisionVerdict.safe ? 'receipt' : 'goals',
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
          verdict: 'OVERALL SCORE: ${xray.overallScore.toStringAsFixed(0)}/100 (${xray.rating.toUpperCase()})',
          currentPosition: currentPosition,
          calculation:
              '8-Pillar Score Average: ${xray.overallScore.toStringAsFixed(1)} | Cash Flow: ${xray.pillars[0].score.toStringAsFixed(0)} | Savings: ${xray.pillars[1].score.toStringAsFixed(0)} | Debt: ${xray.pillars[2].score.toStringAsFixed(0)} | Safety: ${xray.pillars[7].score.toStringAsFixed(0)}',
          reasoning:
              'Your financial foundation demonstrates ${xray.topStrengths.first}. Primary area for optimization: ${xray.priorityVulnerabilities.first}.',
          risks:
              'Concentration risk in cash vs investments, or low emergency runway if unexpected income disruptions occur.',
          recommendation:
              'Follow the 8-pillar audit: Automate savings on salary credit day and direct at least 20% into long-term compounding assets.',
          alternatives:
              'Prioritize building a strict 3-month emergency fund before initiating aggressive non-liquid investments.',
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
          alternatives:
              'Extend lower-priority goal deadlines by 90 days to eliminate monthly cash flow friction.',
          nextAction: 'Allocate funds to "${opt.bestNextGoalTitle}".',
          actionRoute: 'goals',
          cardType: AdvisorCardType.goalOptimization,
          cardPayload: opt.toJson(),
          timestamp: DateTime.now(),
        );

      case AdvisorIntent.futureSimulation:
        final double incomeDelta = entities.amount != null && query.toLowerCase().contains('increase') ? entities.amount! : 15000.0;
        final sim = WhatIfService.simulateScenario(
          finance: finance,
          incomeDelta: incomeDelta,
          scenarioDescription: 'Projected Monthly Income Hike (+${CurrencyFormatter.format(incomeDelta)})',
        );

        return AdvisorResponse(
          id: const Uuid().v4(),
          userQuery: query,
          intent: intent,
          verdict: 'SCENARIO PROJECTION: +${CurrencyFormatter.format(sim.monthlyDelta)}/MONTH SURPLUS',
          currentPosition: currentPosition,
          calculation:
              'Current Savings: ${CurrencyFormatter.format(sim.baselineMonthlySavings)} (${sim.baselineSavingsRate.toStringAsFixed(0)}%) \u2192 Projected Savings: ${CurrencyFormatter.format(sim.projectedMonthlySavings)} (${sim.projectedSavingsRate.toStringAsFixed(0)}%)',
          reasoning: sim.strategicInsight,
          risks:
              'Lifestyle inflation: Ensure increased earnings are routed to automated investments before expanding discretionary budget lines.',
          recommendation: sim.goalImpactSummary,
          alternatives:
              'Split the extra surplus 50% into index investing and 50% into accelerating your top priority goal.',
          nextAction: 'Open What-If Simulator for custom adjustments.',
          actionRoute: 'simulator',
          cardType: AdvisorCardType.whatIf,
          cardPayload: sim.toJson(),
          timestamp: DateTime.now(),
        );

      case AdvisorIntent.investment:
      case AdvisorIntent.portfolio:
        final report = InvestmentReasoningService.evaluateStrategy(
          finance: finance,
          investments: investments,
        );

        return AdvisorResponse(
          id: const Uuid().v4(),
          userQuery: query,
          intent: intent,
          verdict: 'RECOMMENDED SIP: ${CurrencyFormatter.format(report.recommendedMonthlySip)}/MONTH',
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
          verdict: 'DEBT STRATEGY: AVALANCHE METHOD',
          currentPosition: currentPosition,
          calculation:
              'Discretionary Surplus: ${CurrencyFormatter.format(surplus)} | Clear high-APR balances (> 15%) before funding non-emergency investments.',
          reasoning:
              'Credit card debt and personal loans carry compounding interest charges of 18% to 42% APR. Eliminating them delivers a guaranteed, tax-free return equal to the interest rate saved.',
          risks:
              'Paying only minimum dues leads to interest compounding spirals that prolong repayment for years.',
          recommendation:
              'Allocate 60% of monthly surplus to extinguishing highest-interest debt first, while making minimum payments on the rest.',
          alternatives:
              'For low-interest home loans (< 8.5%), continue standard monthly payments while investing excess capital in index equity funds.',
          nextAction: 'Review recurring expenses in Budget.',
          actionRoute: 'budget',
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
          risks:
              'Unchecked lifestyle creep will erode monthly savings rate and delay goal achievement by several quarters.',
          recommendation:
              'Implement a category budget cap for Food & Shopping to lock in your planned savings rate.',
          alternatives:
              'Use the 48-hour rule for non-essential online purchases above ₹2,000 to minimize impulse buying.',
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
          verdict: emergencyMonths >= 6.0 ? 'FULLY SECURED' : (emergencyMonths >= 3.0 ? 'SUFFICIENT' : 'VULNERABLE'),
          currentPosition: currentPosition,
          calculation:
              'Current Liquid Reserve: ${CurrencyFormatter.format(liquidBalance)} (${emergencyMonths.toStringAsFixed(1)} months) | 6-Month Target: ${CurrencyFormatter.format(targetFund)} | Shortfall: ${CurrencyFormatter.format(shortfall)}',
          reasoning:
              'An emergency fund preserves your financial independence without forcing premature asset liquidation or credit borrowing during unexpected job transitions or health needs.',
          risks:
              'Holding under 3 months liquid coverage leaves you vulnerable to sudden medical or income emergencies.',
          recommendation:
              'Park your emergency reserves in high-yield liquid mutual funds or flexible bank fixed deposits for instant accessibility.',
          alternatives:
              'Save ${CurrencyFormatter.format(shortfall / 6)}/month over the next 6 months to reach your full 6-month safety moat.',
          nextAction: 'Create Emergency Fund Goal.',
          actionRoute: 'goals',
          cardType: AdvisorCardType.none,
          timestamp: DateTime.now(),
        );

      default:
        // General financial advisory query
        final dna = FinancialDNAService.evaluateDNA(
          finance: finance,
          goals: goals,
          investments: investments,
        );

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
          risks:
              'Failing to regularly audit discretionary spending can quietly compound into long-term wealth drag.',
          recommendation:
              'Growth Opportunity: ${dna.growthOpportunity}. Maintain at least a 20% savings velocity.',
          alternatives:
              'Explore "Analyze My Finances" or "Can I Afford This?" for instant deep-dive calculations.',
          nextAction: 'Run Financial X-Ray.',
          actionRoute: 'xray',
          cardType: AdvisorCardType.financialDNA,
          cardPayload: dna.toJson(),
          timestamp: DateTime.now(),
        );
    }
  }
}
