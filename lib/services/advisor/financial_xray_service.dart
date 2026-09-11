import '../../models/advisor_models.dart';
import '../../providers/finance_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/goal_provider.dart';
import '../../providers/investment_provider.dart';
import '../../utils/currency_formatter.dart';

class FinancialXRayService {
  static FinancialXRayReport analyzeFinances({
    required FinanceProvider finance,
    required BudgetProvider budget,
    required GoalProvider goals,
    required InvestmentProvider investments,
  }) {
    final double income = finance.monthlyIncome > 0 ? finance.monthlyIncome : 65000.0;
    final double expense = finance.monthlyExpense;
    final double surplus = income - expense;
    final double savingsRate = income > 0 ? ((surplus / income) * 100).clamp(-100.0, 100.0) : 0.0;
    final double liquidBalance = finance.balance > 0 ? finance.balance : surplus;
    final double monthlyBurn = expense > 0 ? expense : (income * 0.7);

    // 1. Cash Flow Pillar (0-100)
    final double cashFlowRatio = income > 0 ? (surplus / income) : 0;
    double cashFlowScore = 50.0;
    String cashFlowStatus = 'Moderate';
    String cashFlowDesc = 'Net monthly cash flow is balanced.';
    if (cashFlowRatio >= 0.30) {
      cashFlowScore = 95.0;
      cashFlowStatus = 'Optimal';
      cashFlowDesc = 'Surplus is ${cashFlowRatio > 0 ? (cashFlowRatio * 100).toStringAsFixed(0) : 0}% of income. Exceptional cash flow stability.';
    } else if (cashFlowRatio >= 0.15) {
      cashFlowScore = 80.0;
      cashFlowStatus = 'Healthy';
      cashFlowDesc = 'Positive monthly surplus of ${CurrencyFormatter.format(surplus)}. Healthy operating cash flow.';
    } else if (cashFlowRatio > 0) {
      cashFlowScore = 65.0;
      cashFlowStatus = 'Narrow';
      cashFlowDesc = 'Positive cash flow, but operating margin is narrow. Tight room for unexpected shocks.';
    } else {
      cashFlowScore = 30.0;
      cashFlowStatus = 'Deficit Risk';
      cashFlowDesc = 'Outflows currently match or exceed monthly inflows. Immediate expense pacing required.';
    }

    // 2. Savings Pillar (0-100)
    double savingsScore = (savingsRate / 25.0 * 100.0).clamp(20.0, 100.0);
    String savingsStatus = savingsRate >= 25 ? 'Excellent' : (savingsRate >= 15 ? 'Good' : 'Needs Improvement');

    // 3. Debt Burden Pillar (0-100)
    // Identify debt payments from category 'Bills' or transactions containing 'emi' / 'loan'
    final double debtPayments = finance.transactions
        .where((t) =>
            t.type.name == 'expense' &&
            (t.title.toLowerCase().contains('emi') ||
                t.title.toLowerCase().contains('loan') ||
                t.merchant.toLowerCase().contains('loan')))
        .fold(0.0, (s, t) => s + t.amount);

    final double dti = income > 0 ? (debtPayments / income) * 100 : 0.0;
    double debtScore = 95.0;
    String debtStatus = 'Low Risk';
    String debtDesc = 'Minimal to no high-interest debt burden detected.';
    if (dti > 40) {
      debtScore = 40.0;
      debtStatus = 'Heavy Burden';
      debtDesc = 'Debt obligations exceed 40% of net monthly income. Aggressive repayment recommended.';
    } else if (dti > 20) {
      debtScore = 70.0;
      debtStatus = 'Moderate';
      debtDesc = 'EMI and loans account for ${dti.toStringAsFixed(0)}% of income. Within manageable limits.';
    }

    // 4. Goals Health Pillar (0-100)
    double goalScore = 60.0;
    String goalStatus = 'Average';
    String goalDesc = 'Active goals tracked in your plan.';
    if (goals.goals.isEmpty) {
      goalScore = 40.0;
      goalStatus = 'Unconfigured';
      goalDesc = 'No active savings goals configured. Add structured targets to accelerate milestone funding.';
    } else {
      final double totalTarget = goals.goals.fold(0.0, (s, g) => s + g.targetAmount);
      final double totalSaved = goals.goals.fold(0.0, (s, g) => s + g.currentAmount);
      final double overallFunding = totalTarget > 0 ? (totalSaved / totalTarget) * 100 : 0;
      goalScore = (overallFunding * 0.5 + 50.0).clamp(40.0, 95.0);
      goalStatus = overallFunding >= 50 ? 'Strong Progress' : 'In Progress';
      goalDesc = '${goals.goals.length} active goals tracked. Total funded: ${overallFunding.toStringAsFixed(0)}%.';
    }

    // 5. Investments Pillar (0-100)
    final double investedTotal = investments.totalCurrentValue;
    double investScore = 55.0;
    String investStatus = 'Developing';
    String investDesc = 'Building long-term wealth portfolio.';
    if (investedTotal > income * 6) {
      investScore = 95.0;
      investStatus = 'Wealth Builder';
      investDesc = 'Portfolio value exceeds 6 months of gross income (${CurrencyFormatter.format(investedTotal)}).';
    } else if (investedTotal > income * 2) {
      investScore = 80.0;
      investStatus = 'Healthy';
      investDesc = 'Consistent investment assets accumulating in diverse holdings.';
    } else if (investedTotal > 0) {
      investScore = 65.0;
      investStatus = 'Emerging';
      investDesc = 'Active holdings present (${CurrencyFormatter.format(investedTotal)}). Consider scaling regular monthly SIPs.';
    }

    // 6. Emergency Fund Pillar (0-100)
    final double emergencyMonths = monthlyBurn > 0 ? (liquidBalance / monthlyBurn) : 1.0;
    double emergencyScore = (emergencyMonths / 6.0 * 100.0).clamp(20.0, 100.0);
    String emergencyStatus = emergencyMonths >= 6 ? 'Bulletproof' : (emergencyMonths >= 3 ? 'Sufficient' : 'Vulnerable');
    String emergencyDesc = 'Current liquid runway covers ${emergencyMonths.toStringAsFixed(1)} months of essential living expenses.';

    // 7. Budget Discipline Pillar (0-100)
    final double budgetPercentage = budget.budgetPercentage(expense);
    double budgetScore = 75.0;
    String budgetStatus = 'Disciplined';
    String budgetDesc = 'Spending is aligned within planned limits.';
    if (budgetPercentage > 1.0) {
      budgetScore = 45.0;
      budgetStatus = 'Over Limit';
      budgetDesc = 'Current monthly spending has exceeded the established budget limit.';
    } else if (budgetPercentage > 0.85) {
      budgetScore = 65.0;
      budgetStatus = 'Near Capacity';
      budgetDesc = 'Operating at ${(budgetPercentage * 100).toStringAsFixed(0)}% of monthly budget ceiling.';
    } else {
      budgetScore = 90.0;
      budgetStatus = 'Optimal';
      budgetDesc = 'Spending strictly controlled at ${(budgetPercentage * 100).toStringAsFixed(0)}% of monthly cap.';
    }

    // 8. Financial Safety Pillar (0-100)
    final double discretionarySpend = (finance.monthlyCategorySpent['Food'] ?? 0) +
        (finance.monthlyCategorySpent['Shopping'] ?? 0) +
        (finance.monthlyCategorySpent['Entertainment'] ?? 0);
    final double discretionaryRatio = expense > 0 ? (discretionarySpend / expense) : 0.3;
    double safetyScore = 80.0;
    String safetyStatus = 'Secure';
    String safetyDesc = 'Discretionary buffer is well regulated.';
    if (discretionaryRatio > 0.50) {
      safetyScore = 50.0;
      safetyStatus = 'Elevated';
      safetyDesc = 'Discretionary wants exceed 50% of monthly outflows. Vulnerable to sudden income changes.';
    } else if (emergencyMonths < 2) {
      safetyScore = 55.0;
      safetyStatus = 'Low Runway';
      safetyDesc = 'Emergency liquidity is below 2 months. Immediate defensive reserve building advised.';
    }

    // Compile pillars
    final pillars = [
      XRayPillarScore(
        name: 'Cash Flow',
        score: cashFlowScore,
        status: cashFlowStatus,
        description: cashFlowDesc,
        calculationDetails: 'Net surplus: ${CurrencyFormatter.format(surplus)} / ${CurrencyFormatter.format(income)} income',
      ),
      XRayPillarScore(
        name: 'Savings Rate',
        score: savingsScore,
        status: savingsStatus,
        description: 'Saving ${savingsRate.toStringAsFixed(0)}% of net monthly earnings.',
        calculationDetails: 'Target >= 25.0%. Current: ${savingsRate.toStringAsFixed(1)}%',
      ),
      XRayPillarScore(
        name: 'Debt Control',
        score: debtScore,
        status: debtStatus,
        description: debtDesc,
        calculationDetails: 'Debt-to-income: ${dti.toStringAsFixed(1)}%',
      ),
      XRayPillarScore(
        name: 'Goal Funding',
        score: goalScore,
        status: goalStatus,
        description: goalDesc,
        calculationDetails: '${goals.goals.length} target goals tracked',
      ),
      XRayPillarScore(
        name: 'Investments',
        score: investScore,
        status: investStatus,
        description: investDesc,
        calculationDetails: 'Portfolio: ${CurrencyFormatter.format(investedTotal)}',
      ),
      XRayPillarScore(
        name: 'Emergency Fund',
        score: emergencyScore,
        status: emergencyStatus,
        description: emergencyDesc,
        calculationDetails: 'Coverage: ${emergencyMonths.toStringAsFixed(1)} months reserve',
      ),
      XRayPillarScore(
        name: 'Budget Pacing',
        score: budgetScore,
        status: budgetStatus,
        description: budgetDesc,
        calculationDetails: 'Budget utilization: ${(budgetPercentage * 100).toStringAsFixed(0)}%',
      ),
      XRayPillarScore(
        name: 'Financial Safety',
        score: safetyScore,
        status: safetyStatus,
        description: safetyDesc,
        calculationDetails: 'Discretionary ratio: ${(discretionaryRatio * 100).toStringAsFixed(0)}%',
      ),
    ];

    // Compute composite score weighted by core pillars
    final double overallScore = (cashFlowScore * 0.18 +
            savingsScore * 0.18 +
            debtScore * 0.14 +
            emergencyScore * 0.16 +
            budgetScore * 0.12 +
            investScore * 0.10 +
            goalScore * 0.08 +
            safetyScore * 0.04)
        .clamp(0.0, 100.0);

    String rating = 'Fair';
    if (overallScore >= 85) {
      rating = 'Pinnacle Elite';
    } else if (overallScore >= 75) {
      rating = 'Very Strong';
    } else if (overallScore >= 60) {
      rating = 'Healthy & Stable';
    } else if (overallScore >= 45) {
      rating = 'Fair (Optimization Needed)';
    } else {
      rating = 'High Vulnerability';
    }

    final topStrengths = <String>[];
    final vulnerabilities = <String>[];

    for (final p in pillars) {
      if (p.score >= 80) topStrengths.add('${p.name}: ${p.status}');
      if (p.score < 65) vulnerabilities.add('${p.name}: ${p.description}');
    }

    if (topStrengths.isEmpty) topStrengths.add('Steady foundation ready for accelerated compounding');
    if (vulnerabilities.isEmpty) vulnerabilities.add('Maintain existing disciplined asset allocation pace');

    return FinancialXRayReport(
      overallScore: double.parse(overallScore.toStringAsFixed(1)),
      rating: rating,
      summary: 'Comprehensive audit scored your overall financial health at ${overallScore.toStringAsFixed(0)}/100 ($rating).',
      pillars: pillars,
      topStrengths: topStrengths,
      priorityVulnerabilities: vulnerabilities,
    );
  }
}
