import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/goal_model.dart';
import '../models/investment_command_models.dart';
import '../models/investment_model.dart';
import '../providers/finance_provider.dart';
import '../providers/goal_provider.dart';
import '../providers/investment_provider.dart';
import '../services/investment/debt_investment_service.dart';
import '../services/investment/goal_investment_service.dart';
import '../services/investment/investment_calculation_service.dart';
import '../services/investment/investment_education_service.dart';
import '../services/investment/investment_what_if_service.dart';
import '../services/investment/portfolio_health_service.dart';
import '../services/investment/retirement_planning_service.dart';
import '../services/investment/risk_assessment_service.dart';
import '../services/investment/tax_planning_service.dart';
import '../utils/currency_formatter.dart';
import 'ai_chat_screen.dart';

class InvestmentScreen extends StatefulWidget {
  const InvestmentScreen({super.key});

  @override
  State<InvestmentScreen> createState() => _InvestmentScreenState();
}

class _InvestmentScreenState extends State<InvestmentScreen>
    with SingleTickerProviderStateMixin {
  // Command center tabs
  late TabController _tabController;

  // Selected goal state for Goal Analyzer
  String? _selectedGoalId;

  // Active risk profile state (persisted locally during session)
  RiskProfileType _userRiskProfile = RiskProfileType.moderate;
  final Map<int, int> _riskAssessmentAnswers = {
    1: 3,
    2: 3,
    3: 3,
    4: 3,
    5: 3,
    6: 3,
  };

  // SIP Calculator State
  double _sipMonthly = 10000.0;
  int _sipDurationYears = 5;
  double _sipAnnualReturn = 12.0;
  final double _sipStartingLump = 25000.0;

  // Lump Sum Calculator State
  double _lumpInitial = 100000.0;
  int _lumpDurationYears = 10;
  final double _lumpAnnualReturn = 12.0;

  // Goal SIP Calculator State
  double _goalSipTarget = 1500000.0;
  final double _goalSipCurrent = 200000.0;
  int _goalSipYears = 4;
  final double _goalSipReturn = 11.0;

  // Retirement Planner State
  final int _retireCurrentAge = 28;
  final int _retireTargetAge = 60;
  final double _retireMonthlyExpense = 45000.0;
  final double _retireInflation = 6.0;
  final double _retirePreReturn = 12.0;
  final double _retirePostReturn = 7.5;

  // Tax Center State
  final double _taxGrossAnnual = 1200000.0;
  final double _tax80C = 120000.0;
  final double _tax80D = 25000.0;
  final double _taxNps = 50000.0;
  final double _taxHomeLoan = 0.0;

  // Debt vs Invest State
  final double _debtOutstanding = 400000.0;
  final double _debtInterestRate = 11.5;
  final double _debtEmi = 12500.0;
  final double _debtSurplus = 15000.0;
  final double _debtInvestReturn = 12.0;

  // Investment Log Form Controllers
  final _assetNameController = TextEditingController();
  final _investedController = TextEditingController();
  final _currentController = TextEditingController();
  String _selectedAssetType = 'Index Fund';

  // Styling Constants
  static const Color bgDark = Color(0xFF060B18);
  static const Color cardDark = Color(0xFF0F172E);
  static const Color purpleNeon = Color(0xFF7B61FF);
  static const Color cyanNeon = Color(0xFF00E5FF);
  static const Color goldAccent = Color(0xFFFFD166);
  static const Color emeraldGreen = Color(0xFF06D6A0);
  static const Color coralRed = Color(0xFFFF6B6B);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _assetNameController.dispose();
    _investedController.dispose();
    _currentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final goalProvider = context.watch<GoalProvider>();
    final investProvider = context.watch<InvestmentProvider>();

    final monthlySurplus = (finance.monthlyIncome - finance.monthlyExpense)
        .clamp(0.0, double.infinity);
    final investmentCapacity = (monthlySurplus * 0.70).clamp(
      0.0,
      monthlySurplus,
    );

    final readiness = InvestmentEducationService.evaluateReadiness(
      monthlyIncome: finance.monthlyIncome > 0
          ? finance.monthlyIncome
          : 65000.0,
      monthlyExpense: finance.monthlyExpense > 0
          ? finance.monthlyExpense
          : 35000.0,
      emergencyBalance: finance.balance > 0 ? finance.balance : 120000.0,
      totalDebt: _debtOutstanding,
      activeGoalsCount: goalProvider.goals.length,
      hasRiskAssessment: true,
    );

    final portfolioAudit = PortfolioHealthService.auditPortfolio(
      holdings: investProvider.investments,
      userRisk: _userRiskProfile,
      isEmergencyFundHealthy: readiness.isEmergencyFundHealthy,
      hasHighCostDebt: _debtInterestRate >= 13.0,
    );

    return Scaffold(
      backgroundColor: bgDark,
      body: SafeArea(
        child: Column(
          children: [
            _buildCommandHeader(context, investProvider),
            _buildCommandTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 0: Overview & Goals Strategy
                  _buildOverviewAndGoalsTab(
                    finance,
                    goalProvider,
                    investProvider,
                    readiness,
                    investmentCapacity,
                  ),

                  // Tab 1: Calculators & Simulators
                  _buildCalculatorsTab(investmentCapacity),

                  // Tab 2: Retirement & Debt Command
                  _buildRetirementAndDebtTab(investmentCapacity),

                  // Tab 3: Tax Saving Center
                  _buildTaxSavingCenterTab(),

                  // Tab 4: Portfolio Health & Rebalancing
                  _buildPortfolioHealthTab(investProvider, portfolioAudit),

                  // Tab 5: Academy & Asset Options
                  _buildAcademyAndOptionsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: purpleNeon,
        icon: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
        label: const Text(
          'Ask FinPilot',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AIChatScreen()),
          );
        },
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildCommandHeader(
    BuildContext context,
    InvestmentProvider investProvider,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: purpleNeon.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: purpleNeon.withValues(alpha: 0.4),
                        ),
                      ),
                      child: const Text(
                        'AI WEALTH ENGINE',
                        style: TextStyle(
                          color: cyanNeon,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: _showRiskAssessmentDialog,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _userRiskProfile.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _userRiskProfile.color.withValues(
                              alpha: 0.4,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.shield_outlined,
                              color: _userRiskProfile.color,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _userRiskProfile.label,
                              style: TextStyle(
                                color: _userRiskProfile.color,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'INVESTMENT COMMAND CENTER',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Turn your financial goals into an intelligent investment strategy.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Log New Asset',
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [purpleNeon, cyanNeon]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 20),
            ),
            onPressed: () => _showAddInvestmentDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildCommandTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: purpleNeon.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: purpleNeon.withValues(alpha: 0.8)),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white.withValues(alpha: 0.5),
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        tabs: const [
          Tab(text: 'Strategy & Goals'),
          Tab(text: 'Calculators'),
          Tab(text: 'Retirement & Debt'),
          Tab(text: 'Tax Saving'),
          Tab(text: 'Portfolio & Health'),
          Tab(text: 'Academy & Options'),
        ],
      ),
    );
  }

  // ============================================================
  // TAB 0: OVERVIEW & GOALS STRATEGY
  // ============================================================

  Widget _buildOverviewAndGoalsTab(
    FinanceProvider finance,
    GoalProvider goalProvider,
    InvestmentProvider investProvider,
    InvestmentReadinessReport readiness,
    double investmentCapacity,
  ) {
    // Select active goal
    GoalModel? activeGoal;
    if (goalProvider.goals.isNotEmpty) {
      if (_selectedGoalId != null) {
        activeGoal = goalProvider.goals.firstWhere(
          (g) => g.id == _selectedGoalId,
          orElse: () => goalProvider.goals.first,
        );
      } else {
        activeGoal = goalProvider.goals.first;
      }
    } else {
      // Demo goal if none exists yet
      activeGoal = GoalModel(
        id: 'demo-goal',
        title: 'Wealth Creation (10 Lakhs)',
        targetAmount: 1000000,
        currentAmount: 250000,
        deadline: DateTime.now().add(const Duration(days: 730)),
        category: 'Wealth Creation',
        createdAt: DateTime.now(),
      );
    }

    final goalAnalysis = GoalInvestmentService.analyzeGoal(
      goal: activeGoal,
      monthlyCapacity: investmentCapacity,
      userRiskProfile: _userRiskProfile,
      isEmergencyFundHealthy: readiness.isEmergencyFundHealthy,
    );

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top Status Card: Your Investment Readiness
          _buildInvestmentReadinessCard(readiness, investmentCapacity),

          const SizedBox(height: 16),

          // 2. Hero AI Investment Intelligence Card
          _buildHeroAiInvestmentCard(
            finance,
            readiness,
            investmentCapacity,
            activeGoal,
          ),

          const SizedBox(height: 22),

          // 3. Goal Selection & Horizontal Carousel
          _buildGoalSelectionSection(goalProvider),

          const SizedBox(height: 20),

          // 4. Goal Investment Deep Analyzer
          _buildGoalAnalyzerSection(goalAnalysis),

          const SizedBox(height: 22),

          // 5. 3 Strategies: Conservative, Balanced, Growth
          _buildThreeStrategiesSection(goalAnalysis),

          const SizedBox(height: 22),

          // 6. Goal De-risking Guidance
          _buildDeRiskingGuidanceCard(goalAnalysis),

          const SizedBox(height: 22),

          // 7. Investment Action Plan
          _buildInvestmentActionPlanCard(investmentCapacity, activeGoal),

          const SizedBox(height: 60),
        ],
      ),
    );
  }

  // ============================================================
  // READINESS & HERO CARDS
  // ============================================================

  Widget _buildInvestmentReadinessCard(
    InvestmentReadinessReport report,
    double capacity,
  ) {
    return InkWell(
      onTap: () => _showReadinessChecklistSheet(report),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cardDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: emeraldGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.verified_outlined,
                        color: emeraldGreen,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'YOUR INVESTMENT READINESS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Text(
                          'Institutional 9-point financial health audit',
                          style: TextStyle(color: Colors.white54, fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: report.readinessScore >= 75
                        ? emeraldGreen.withValues(alpha: 0.2)
                        : goldAccent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: report.readinessScore >= 75
                          ? emeraldGreen
                          : goldAccent,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '${report.readinessScore} / 100',
                    style: TextStyle(
                      color: report.readinessScore >= 75
                          ? emeraldGreen
                          : goldAccent,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _buildReadinessMetric(
                    title: 'Emergency Fund',
                    value: report.emergencyFundStatusText,
                    isPositive: report.isEmergencyFundHealthy,
                  ),
                ),
                Container(width: 1, height: 35, color: Colors.white10),
                Expanded(
                  child: _buildReadinessMetric(
                    title: 'Debt Load',
                    value: report.debtStatusText,
                    isPositive: report.isDebtManageable,
                  ),
                ),
                Container(width: 1, height: 35, color: Colors.white10),
                Expanded(
                  child: _buildReadinessMetric(
                    title: 'Monthly Capacity',
                    value: CurrencyFormatter.format(capacity),
                    isPositive: capacity > 5000,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'View 9-Point Readiness Checklist',
                  style: TextStyle(
                    color: cyanNeon.withValues(alpha: 0.9),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward_ios, color: cyanNeon, size: 10),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadinessMetric({
    required String title,
    required String value,
    required bool isPositive,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isPositive ? emeraldGreen : goldAccent,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroAiInvestmentCard(
    FinanceProvider finance,
    InvestmentReadinessReport readiness,
    double capacity,
    GoalModel goal,
  ) {
    String message;
    if (!readiness.isEmergencyFundHealthy) {
      message = 'Based on your live cash flow and goals, your highest immediate priority is completing your 3-month emergency reserve before increasing high-volatility equity allocations.';
    } else if (readiness.monthlySurplus < 5000) {
      message =
          'Your emergency reserve is healthy, but current monthly surplus is tightly constrained. Prioritize budget trimming to unlock investment capacity for "${goal.title}".';
    } else {
      message =
          'Your financial foundation is in prime shape. With ${CurrencyFormatter.format(capacity)}/mo capacity and ${readiness.emergencyFundStatusText} emergency cover, you can comfortably deploy into long-term compounding strategies.';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [purpleNeon.withValues(alpha: 0.25), cardDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: purpleNeon.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: purpleNeon.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: cyanNeon,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'FINPILOT INVESTMENT INTELLIGENCE',
                style: TextStyle(
                  color: cyanNeon,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '"$message"',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: purpleNeon,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.timeline, size: 16),
                label: const Text(
                  'View Strategy',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  _tabController.animateTo(0);
                },
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: cyanNeon,
                  side: BorderSide(color: cyanNeon.withValues(alpha: 0.6)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.chat_bubble_outline, size: 16),
                label: const Text(
                  'Ask AI Advisor',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AIChatScreen()),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // GOAL SELECTION & GOAL ANALYZER
  // ============================================================

  Widget _buildGoalSelectionSection(GoalProvider goalProvider) {
    final goals = goalProvider.goals;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'WHAT ARE YOU INVESTING FOR?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            Text(
              '${goals.length} Active Goals',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: goals.isNotEmpty
                ? goals.length
                : GoalInvestmentService.presetGoals.length,
            itemBuilder: (context, index) {
              if (goals.isNotEmpty) {
                final g = goals[index];
                final isSelected =
                    (_selectedGoalId == null && index == 0) ||
                    (_selectedGoalId == g.id);
                return _buildGoalCard(
                  id: g.id,
                  title: g.title,
                  target: g.targetAmount,
                  current: g.currentAmount,
                  isSelected: isSelected,
                  onTap: () {
                    setState(() {
                      _selectedGoalId = g.id;
                    });
                  },
                );
              } else {
                final preset = GoalInvestmentService.presetGoals[index];
                return _buildPresetGoalCard(preset);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGoalCard({
    required String id,
    required String title,
    required double target,
    required double current,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final double progress = target > 0
        ? (current / target).clamp(0.0, 1.0)
        : 0.0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 170,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? purpleNeon.withValues(alpha: 0.25) : cardDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? cyanNeon : Colors.white.withValues(alpha: 0.08),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${CurrencyFormatter.format(current)} / ${CurrencyFormatter.format(target)}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isSelected ? cyanNeon : purpleNeon,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetGoalCard(PresetGoalTemplate preset) {
    return Container(
      width: 150,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            preset.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'Target: ${CurrencyFormatter.format(preset.defaultTarget)}',
            style: const TextStyle(
              color: cyanNeon,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '~${preset.defaultMonths} Months',
            style: const TextStyle(color: Colors.white54, fontSize: 9),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalAnalyzerSection(GoalInvestmentAnalysisReport report) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'GOAL ANALYSIS',
                    style: TextStyle(
                      color: cyanNeon,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    report.goalTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: report.feasibility.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: report.feasibility.color),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.circle,
                      color: report.feasibility.color,
                      size: 8,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      report.feasibility.label,
                      style: TextStyle(
                        color: report.feasibility.color,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 14),
          // 4-box metrics grid
          Row(
            children: [
              Expanded(
                child: _buildAnalyzerCell(
                  label: 'Target Corpus',
                  val: CurrencyFormatter.format(report.targetAmount),
                ),
              ),
              Expanded(
                child: _buildAnalyzerCell(
                  label: 'Current Saved',
                  val: CurrencyFormatter.format(report.currentAmount),
                ),
              ),
              Expanded(
                child: _buildAnalyzerCell(
                  label: 'Remaining Gap',
                  val: CurrencyFormatter.format(report.remainingAmount),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildAnalyzerCell(
                  label: 'Time Remaining',
                  val: '${report.monthsRemaining} Months',
                ),
              ),
              Expanded(
                child: _buildAnalyzerCell(
                  label: 'Monthly Capacity',
                  val: CurrencyFormatter.format(report.monthlyCapacity),
                ),
              ),
              Expanded(
                child: _buildAnalyzerCell(
                  label: 'Required SIP',
                  val: CurrencyFormatter.format(
                    report.requiredMonthlyInvestment,
                  ),
                  highlightColor: report.feasibility == GoalFeasibility.good
                      ? emeraldGreen
                      : coralRed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: cyanNeon, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    report.detailedReasoning,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyzerCell({
    required String label,
    required String val,
    Color? highlightColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          val,
          style: TextStyle(
            color: highlightColor ?? Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // THREE STRATEGIES SECTION
  // ============================================================

  Widget _buildThreeStrategiesSection(GoalInvestmentAnalysisReport report) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'THREE STRATEGIES FOR THIS GOAL',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Select the strategy matching your volatility tolerance',
          style: TextStyle(color: Colors.white54, fontSize: 11),
        ),
        const SizedBox(height: 12),
        Column(
          children: report.strategies
              .map((strat) => _buildStrategyCard(strat))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildStrategyCard(StrategyOption strat) {
    Color headerColor;
    if (strat.name == 'CONSERVATIVE') {
      headerColor = emeraldGreen;
    } else if (strat.name == 'BALANCED') {
      headerColor = cyanNeon;
    } else {
      headerColor = purpleNeon;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: headerColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: headerColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      strat.name,
                      style: TextStyle(
                        color: headerColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${strat.illustrativeReturnRate}% Illustrative Return',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${strat.goalMatchPercentage}% Fit',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            strat.whyItFits,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: strat.assetAllocation.entries.map((e) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${e.key}: ${e.value.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Text(
            'Trade-off: ${strat.whyItMayNotFit}',
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 10,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeRiskingGuidanceCard(GoalInvestmentAnalysisReport report) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: goldAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: goldAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: goldAccent,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'GOAL DE-RISKING GLIDEPATH',
                  style: TextStyle(
                    color: goldAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  report.deRiskingGuidance,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvestmentActionPlanCard(double capacity, GoalModel goal) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'YOUR INVESTMENT PLAN',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          _buildActionStep(
            number: '1',
            title: 'Build Emergency Buffer First',
            desc: 'Maintain 3 months of essential expenses in liquid/overnight funds.',
          ),
          _buildActionStep(
            number: '2',
            title: 'Automate SIP toward ${goal.title}',
            desc: 'Schedule auto-debit on the 2nd day of each month for disciplined compounding.',
          ),
          _buildActionStep(
            number: '3',
            title:
                'Allocate ${CurrencyFormatter.format(capacity)} Monthly Capacity',
            desc:
                'Direct surplus into low-cost index and dynamic hybrid funds.',
          ),
          _buildActionStep(
            number: '4',
            title: 'Semi-Annual Portfolio Review',
            desc: 'Check allocation drift in June and December to reset target risk.',
          ),
          _buildActionStep(
            number: '5',
            title: 'Tax-Saving Assessment Before Q4',
            desc: 'Optimize Section 80C & 80D before March 31 to prevent last-minute lock-in traps.',
          ),
        ],
      ),
    );
  }

  Widget _buildActionStep({
    required String number,
    required String title,
    required String desc,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 24,
            width: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: purpleNeon.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(color: purpleNeon.withValues(alpha: 0.6)),
            ),
            child: Text(
              number,
              style: const TextStyle(
                color: cyanNeon,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TAB 1: CALCULATORS & SIMULATORS
  // ============================================================

  Widget _buildCalculatorsTab(double investmentCapacity) {
    final sipResult = InvestmentCalculationService.calculateSip(
      monthlySip: _sipMonthly,
      durationYears: _sipDurationYears,
      annualReturnRate: _sipAnnualReturn,
      startingInvestment: _sipStartingLump,
    );

    final lumpResult = InvestmentCalculationService.calculateLumpSum(
      initialInvestment: _lumpInitial,
      durationYears: _lumpDurationYears,
      annualReturnRate: _lumpAnnualReturn,
    );

    final goalSipResult =
        InvestmentCalculationService.calculateGoalSipRequirement(
          targetCorpus: _goalSipTarget,
          currentCorpus: _goalSipCurrent,
          durationYears: _goalSipYears,
          annualReturnRate: _goalSipReturn,
          availableMonthlyCapacity: investmentCapacity,
        );

    final whatIfScenarios =
        InvestmentWhatIfService.evaluateSensitivityScenarios(
          baseMonthlySip: _sipMonthly,
          baseYears: _sipDurationYears,
          baseAnnualReturn: _sipAnnualReturn,
          baseStartingCorpus: _sipStartingLump,
        );

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. SIP Calculator
          _buildSipCalculatorSection(sipResult),

          const SizedBox(height: 24),

          // 2. Lump Sum Calculator & Comparison
          _buildLumpSumCalculatorSection(lumpResult),

          const SizedBox(height: 24),

          // 3. Goal SIP Reverse Calculator
          _buildGoalSipCalculatorSection(goalSipResult),

          const SizedBox(height: 24),

          // 4. What-If Investment Lab
          _buildWhatIfLabSection(whatIfScenarios),

          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildSipCalculatorSection(SipCalculationResult result) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'SIP WEALTH CALCULATOR',
                style: TextStyle(
                  color: cyanNeon,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: purpleNeon.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Compounding Model',
                  style: TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Sliders
          _buildSliderRow(
            label: 'Monthly Investment',
            val: CurrencyFormatter.format(_sipMonthly),
            currentValue: _sipMonthly,
            min: 500,
            max: 100000,
            divisions: 199,
            onChanged: (v) => setState(() => _sipMonthly = v),
          ),
          _buildSliderRow(
            label: 'Time Horizon',
            val: '$_sipDurationYears Years',
            currentValue: _sipDurationYears.toDouble(),
            min: 1,
            max: 30,
            divisions: 29,
            onChanged: (v) => setState(() => _sipDurationYears = v.round()),
          ),
          _buildSliderRow(
            label: 'Expected Return',
            val: '${_sipAnnualReturn.toStringAsFixed(1)}% p.a.',
            currentValue: _sipAnnualReturn,
            min: 6.0,
            max: 20.0,
            divisions: 28,
            onChanged: (v) => setState(() => _sipAnnualReturn = v),
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white12),
          const SizedBox(height: 12),
          // Result Breakdown
          Row(
            children: [
              Expanded(
                child: _buildMetricBlock(
                  'Total Invested',
                  CurrencyFormatter.format(result.totalInvested),
                  Colors.white70,
                ),
              ),
              Expanded(
                child: _buildMetricBlock(
                  'Estimated Gain',
                  CurrencyFormatter.format(result.estimatedGain),
                  emeraldGreen,
                ),
              ),
              Expanded(
                child: _buildMetricBlock(
                  'Total Corpus',
                  CurrencyFormatter.format(result.estimatedCorpus),
                  cyanNeon,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Conservative (-3%): ${CurrencyFormatter.format(result.conservativeCorpus)}',
                  style: const TextStyle(color: Colors.white38, fontSize: 9),
                ),
              ),
              Expanded(
                child: Text(
                  'Optimistic (+3%): ${CurrencyFormatter.format(result.optimisticCorpus)}',
                  textAlign: TextAlign.end,
                  style: const TextStyle(color: Colors.white38, fontSize: 9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '*Illustrative projection based on assumed return rates. Actual returns are subject to market volatility and not guaranteed.',
            style: TextStyle(
              color: Colors.white24,
              fontSize: 9,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLumpSumCalculatorSection(LumpSumCalculationResult result) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'LUMP SUM VS SIP COMPARATOR',
            style: TextStyle(
              color: goldAccent,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 14),
          _buildSliderRow(
            label: 'Initial Lump Sum',
            val: CurrencyFormatter.format(_lumpInitial),
            currentValue: _lumpInitial,
            min: 10000,
            max: 2000000,
            divisions: 199,
            onChanged: (v) => setState(() => _lumpInitial = v),
          ),
          _buildSliderRow(
            label: 'Time Horizon',
            val: '$_lumpDurationYears Years',
            currentValue: _lumpDurationYears.toDouble(),
            min: 1,
            max: 30,
            divisions: 29,
            onChanged: (v) => setState(() => _lumpDurationYears = v.round()),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricBlock(
                  'Lump Sum Future Value',
                  CurrencyFormatter.format(result.estimatedCorpus),
                  goldAccent,
                ),
              ),
              Expanded(
                child: _buildMetricBlock(
                  'Equivalent Monthly SIP',
                  CurrencyFormatter.format(result.sipEquivalentMonthly),
                  cyanNeon,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Investing ${CurrencyFormatter.format(_lumpInitial)} today yields the exact same eventual wealth as committing ${CurrencyFormatter.format(result.sipEquivalentMonthly)} every single month for $_lumpDurationYears years.',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 10,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalSipCalculatorSection(GoalSipRequirementResult result) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'GOAL SIP CALCULATOR — HOW MUCH MUST I INVEST?',
            style: TextStyle(
              color: purpleNeon,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 14),
          _buildSliderRow(
            label: 'Target Corpus Needed',
            val: CurrencyFormatter.format(_goalSipTarget),
            currentValue: _goalSipTarget,
            min: 100000,
            max: 10000000,
            divisions: 99,
            onChanged: (v) => setState(() => _goalSipTarget = v),
          ),
          _buildSliderRow(
            label: 'Target Horizon',
            val: '$_goalSipYears Years',
            currentValue: _goalSipYears.toDouble(),
            min: 1,
            max: 25,
            divisions: 24,
            onChanged: (v) => setState(() => _goalSipYears = v.round()),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricBlock(
                  'Required Monthly SIP',
                  CurrencyFormatter.format(result.requiredMonthlyInvestment),
                  cyanNeon,
                ),
              ),
              Expanded(
                child: _buildMetricBlock(
                  'Available Capacity',
                  CurrencyFormatter.format(result.availableMonthlyCapacity),
                  result.isAchievable ? emeraldGreen : coralRed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: result.isAchievable
                  ? emeraldGreen.withValues(alpha: 0.1)
                  : coralRed.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: result.isAchievable
                    ? emeraldGreen.withValues(alpha: 0.4)
                    : coralRed.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.isAchievable
                      ? '✓ Goal Fully Feasible with Current Surplus'
                      : '⚠ Monthly Surplus Shortfall Detected (₹${(-result.gap).toStringAsFixed(0)}/mo deficit)',
                  style: TextStyle(
                    color: result.isAchievable ? emeraldGreen : coralRed,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                ...result.strategicAlternatives.map(
                  (alt) => Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      '• $alt',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWhatIfLabSection(List<InvestmentWhatIfScenarioCard> scenarios) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'INVESTMENT WHAT-IF LAB',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Instant sensitivity analysis for contribution and horizon changes',
          style: TextStyle(color: Colors.white54, fontSize: 11),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.25,
          children: scenarios.map((s) => _buildWhatIfCard(s)).toList(),
        ),
      ],
    );
  }

  Widget _buildWhatIfCard(InvestmentWhatIfScenarioCard s) {
    final bool isPositive = s.corpusDifference >= 0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            s.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '${isPositive ? '+' : ''}${CurrencyFormatter.format(s.corpusDifference)}',
            style: TextStyle(
              color: isPositive ? emeraldGreen : coralRed,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            s.strategicImpact,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 9,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderRow({
    required String label,
    required String val,
    required double currentValue,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
            Text(
              val,
              style: const TextStyle(
                color: cyanNeon,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: purpleNeon,
            inactiveTrackColor: Colors.white12,
            thumbColor: cyanNeon,
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          ),
          child: Slider(
            value: currentValue.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricBlock(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 10),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // TAB 2: RETIREMENT & DEBT COMMAND
  // ============================================================

  Widget _buildRetirementAndDebtTab(double investmentCapacity) {
    final retirementReport = RetirementPlanningService.calculateRetirementPlan(
      currentAge: _retireCurrentAge,
      retirementAge: _retireTargetAge,
      currentMonthlyExpense: _retireMonthlyExpense,
      assumedInflationRate: _retireInflation,
      assumedPreRetirementReturn: _retirePreReturn,
      assumedPostRetirementReturn: _retirePostReturn,
      currentMonthlyInvestment: investmentCapacity,
    );

    final debtReport = DebtInvestmentService.evaluateDebtVsInvest(
      outstandingLoan: _debtOutstanding,
      loanInterestRate: _debtInterestRate,
      currentEmi: _debtEmi,
      monthlyCapacity: _debtSurplus,
      expectedInvestmentReturn: _debtInvestReturn,
    );

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Retirement Command Center
          _buildRetirementCommandCard(retirementReport),

          const SizedBox(height: 24),

          // 2. Debt vs Investment Optimizer
          _buildDebtVsInvestCard(debtReport),

          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildRetirementCommandCard(RetirementPlanReport report) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'RETIREMENT COMMAND CENTER',
                style: TextStyle(
                  color: cyanNeon,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: report.isOnTrack
                      ? emeraldGreen.withValues(alpha: 0.15)
                      : coralRed.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  report.isOnTrack ? 'ON TRACK' : 'CORPUS GAP',
                  style: TextStyle(
                    color: report.isOnTrack ? emeraldGreen : coralRed,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildMetricBlock(
                  'Future Monthly Expense',
                  CurrencyFormatter.format(
                    report.projectedMonthlyExpenseAtRetirement,
                  ),
                  Colors.white70,
                ),
              ),
              Expanded(
                child: _buildMetricBlock(
                  'Target Nest Egg',
                  CurrencyFormatter.format(report.requiredRetirementCorpus),
                  goldAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricBlock(
                  'Required Monthly SIP',
                  CurrencyFormatter.format(report.requiredMonthlyInvestment),
                  cyanNeon,
                ),
              ),
              Expanded(
                child: _buildMetricBlock(
                  'Current Monthly Surplus',
                  CurrencyFormatter.format(report.currentMonthlyInvestment),
                  report.isOnTrack ? emeraldGreen : coralRed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white12),
          const SizedBox(height: 10),
          const Text(
            'Strategic Milestones & Actions:',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          ...report.milestoneActionPoints.map(
            (pt) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '• $pt',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 10,
                  height: 1.35,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDebtVsInvestCard(DebtVsInvestReport report) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'INVEST OR REPAY DEBT?',
            style: TextStyle(
              color: goldAccent,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Mathematical trade-off between loan prepayment and market compounding',
            style: TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 14),
          // Recommendation Highlight
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: purpleNeon.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: purpleNeon.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recommendation: ${report.bestChoiceRecommendation}',
                  style: const TextStyle(
                    color: cyanNeon,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  report.reasoningWhy,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _buildScenarioRow(report.scenarioRepay),
          _buildScenarioRow(report.scenarioInvest),
          _buildScenarioRow(report.scenarioSplit),
        ],
      ),
    );
  }

  Widget _buildScenarioRow(DebtVsInvestScenario s) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                s.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Benefit: ${CurrencyFormatter.format(s.netFinancialBenefit)}',
                style: const TextStyle(
                  color: emeraldGreen,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            s.tradeOffNote,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 10,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TAB 3: TAX SAVING CENTER
  // ============================================================

  Widget _buildTaxSavingCenterTab() {
    final taxReport = TaxPlanningService.compareRegimesAndOptimize(
      annualGrossIncome: _taxGrossAnnual,
      utilized80C: _tax80C,
      utilized80D: _tax80D,
      utilizedNps: _taxNps,
      homeLoanInterest: _taxHomeLoan,
    );

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Regime Comparison Card
          _buildTaxRegimeCard(taxReport),

          const SizedBox(height: 20),

          // 2. Deduction Optimizer Breakdown
          const Text(
            'TAX SAVING OPTIMIZER',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Maximize Section 80C, 80D and NPS deductions without unnecessary lock-in traps',
            style: TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 12),

          ...taxReport.deductionBreakdown.map(
            (cat) => _buildDeductionCard(cat),
          ),

          const SizedBox(height: 12),
          const Text(
            '*Tax regulations and slab structures are subject to official Finance Act amendments. Consult a certified chartered accountant or tax professional before filing returns.',
            style: TextStyle(
              color: Colors.white24,
              fontSize: 9,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildTaxRegimeCard(TaxRegimeComparisonReport report) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'OLD VS NEW TAX REGIME',
                style: TextStyle(
                  color: cyanNeon,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: emeraldGreen.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  report.recommendedRegime == TaxRegime.newRegime
                      ? 'NEW REGIME SUITS'
                      : 'OLD REGIME SUITS',
                  style: const TextStyle(
                    color: emeraldGreen,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildMetricBlock(
                  'Old Regime Estimated Tax',
                  CurrencyFormatter.format(report.oldRegimeEstimatedTax),
                  report.recommendedRegime == TaxRegime.oldRegime
                      ? emeraldGreen
                      : Colors.white70,
                ),
              ),
              Expanded(
                child: _buildMetricBlock(
                  'New Regime Estimated Tax',
                  CurrencyFormatter.format(report.newRegimeEstimatedTax),
                  report.recommendedRegime == TaxRegime.newRegime
                      ? emeraldGreen
                      : Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.savings_outlined, color: goldAccent, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    report.summaryAdvice,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeductionCard(TaxDeductionCategory cat) {
    final double progress = (cat.currentUtilized / cat.maxAllowedLimit).clamp(
      0.0,
      1.0,
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Section ${cat.code}',
                style: const TextStyle(
                  color: cyanNeon,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Cap: ${CurrencyFormatter.format(cat.maxAllowedLimit)}',
                style: const TextStyle(color: Colors.white54, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            cat.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(
                progress >= 1.0 ? emeraldGreen : purpleNeon,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Utilized: ${CurrencyFormatter.format(cat.currentUtilized)}',
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              ),
              Text(
                'Remaining: ${CurrencyFormatter.format(cat.remainingPotential)}',
                style: const TextStyle(
                  color: goldAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Eligible: ${cat.eligibleInstruments.join(", ")} | Lock-in: ${cat.lockInPeriod}',
            style: const TextStyle(color: Colors.white38, fontSize: 9),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TAB 4: PORTFOLIO HEALTH & REBALANCING
  // ============================================================

  Widget _buildPortfolioHealthTab(
    InvestmentProvider investProvider,
    PortfolioHealthAudit audit,
  ) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Overall Health Score Card
          _buildPortfolioScoreCard(investProvider, audit),

          const SizedBox(height: 20),

          // 2. Target vs Current Allocation
          _buildAllocationComparisonCard(audit),

          const SizedBox(height: 20),

          // 3. Rebalancing Center
          _buildRebalancingCenterCard(audit),

          const SizedBox(height: 20),

          // 4. Holdings List & Management
          _buildHoldingsSection(investProvider),

          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildPortfolioScoreCard(
    InvestmentProvider investProvider,
    PortfolioHealthAudit audit,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PORTFOLIO HEALTH AUDIT',
                    style: TextStyle(
                      color: cyanNeon,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Total Value: ${CurrencyFormatter.format(investProvider.totalCurrentValue)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: audit.overallScore >= 75
                      ? emeraldGreen.withValues(alpha: 0.2)
                      : goldAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: audit.overallScore >= 75 ? emeraldGreen : goldAccent,
                  ),
                ),
                child: Text(
                  '${audit.overallScore} / 100',
                  style: TextStyle(
                    color: audit.overallScore >= 75 ? emeraldGreen : goldAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 7 Dimensions
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildDimensionTag('Diversification', audit.diversificationScore),
              _buildDimensionTag('Risk Alignment', audit.riskScore),
              _buildDimensionTag('Goal Alignment', audit.goalAlignmentScore),
              _buildDimensionTag('Liquidity Buffer', audit.liquidityScore),
              _buildDimensionTag('Concentration', audit.concentrationScore),
              _buildDimensionTag('Tax Efficiency', audit.taxEfficiencyScore),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Colors.white12),
          const SizedBox(height: 10),
          const Text(
            'Top Strengths:',
            style: TextStyle(
              color: emeraldGreen,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          ...audit.topStrengths.map(
            (s) => Text(
              '✓ $s',
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Risk Alerts:',
            style: TextStyle(
              color: coralRed,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          ...audit.topRisks.map(
            (r) => Text(
              '⚠ $r',
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDimensionTag(String label, int score) {
    final bool isGood = score >= 70;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $score',
        style: TextStyle(
          color: isGood ? Colors.white70 : goldAccent,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildAllocationComparisonCard(PortfolioHealthAudit audit) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TARGET VS CURRENT ASSET ALLOCATION',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 14),
          ...audit.currentAllocation.keys.map((key) {
            final curr = audit.currentAllocation[key] ?? 0.0;
            final target = audit.targetAllocation[key] ?? 0.0;
            final drift = audit.allocationDrift[key] ?? 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        key,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Current: ${curr.toStringAsFixed(0)}% | Target: ${target.toStringAsFixed(0)}% (Drift: ${drift > 0 ? '+' : ''}${drift.toStringAsFixed(0)}%)',
                        style: TextStyle(
                          color: drift.abs() >= 10
                              ? goldAccent
                              : Colors.white54,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Stack(
                    children: [
                      Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: (curr / 100.0).clamp(0.0, 1.0),
                        child: Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: purpleNeon,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRebalancingCenterCard(PortfolioHealthAudit audit) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: audit.needsRebalancing
              ? goldAccent.withValues(alpha: 0.4)
              : Colors.white12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.balance,
                color: audit.needsRebalancing ? goldAccent : emeraldGreen,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                audit.needsRebalancing
                    ? 'REBALANCING RECOMMENDED'
                    : 'PORTFOLIO IN BALANCE',
                style: TextStyle(
                  color: audit.needsRebalancing ? goldAccent : emeraldGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Rebalancing resets your portfolio to target risk without triggering unnecessary taxes. Direct upcoming monthly SIP inflows into underweight assets before considering liquidations.',
            style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.4),
          ),
          const SizedBox(height: 10),
          ...audit.topActions.map(
            (act) => Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                '• $act',
                style: const TextStyle(
                  color: cyanNeon,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHoldingsSection(InvestmentProvider investProvider) {
    final holdings = investProvider.investments;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'LOGGED HOLDINGS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            Text(
              '${holdings.length} Assets',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (holdings.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cardDark,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'No investment assets logged yet. Tap "+" at top right to log holdings.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          )
        else
          Column(
            children: holdings
                .map((asset) => _buildHoldingTile(asset, investProvider))
                .toList(),
          ),
      ],
    );
  }

  Widget _buildHoldingTile(
    InvestmentModel asset,
    InvestmentProvider investProvider,
  ) {
    final isGain = asset.totalReturns >= 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  asset.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${asset.type} • Invested: ${CurrencyFormatter.format(asset.investedAmount)}',
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyFormatter.format(asset.currentValue),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${isGain ? '+' : ''}${CurrencyFormatter.format(asset.totalReturns)} (${asset.returnPercentage.toStringAsFixed(1)}%)',
                style: TextStyle(
                  color: isGain ? emeraldGreen : coralRed,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              color: Colors.white30,
              size: 18,
            ),
            onPressed: () => investProvider.deleteInvestment(asset.id),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TAB 5: ACADEMY & ASSET OPTIONS
  // ============================================================

  Widget _buildAcademyAndOptionsTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Where Can I Invest?
          const Text(
            'WHERE CAN I INVEST? — REGULATED ASSET CATEGORIES',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Detailed objective analysis of purpose, risk, and tax treatment',
            style: TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 12),

          ...InvestmentEducationService.investmentCategories.map(
            (cat) => _buildAssetOptionCard(cat),
          ),

          const SizedBox(height: 24),

          // 2. 15 Market Academy Topics
          const Text(
            'FINPILOT WEALTH ACADEMY',
            style: TextStyle(
              color: cyanNeon,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),

          ...InvestmentEducationService.marketAcademyTopics.map(
            (top) => _buildAcademyTopicCard(top),
          ),

          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildAssetOptionCard(AssetCategoryEducation cat) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(cat.icon, color: cyanNeon, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    cat.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: cat.risk.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: cat.risk.color.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  'Risk: ${cat.risk.label}',
                  style: TextStyle(
                    color: cat.risk.color,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            cat.purpose,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                'Horizon: ${cat.suitableHorizon}',
                style: const TextStyle(color: Colors.white54, fontSize: 10),
              ),
              Text(
                '• Liquidity: ${cat.liquidity}',
                style: const TextStyle(color: Colors.white54, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Tax: ${cat.taxConsiderations}',
            style: const TextStyle(color: goldAccent, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildAcademyTopicCard(MarketTopic top) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(top.icon, color: purpleNeon, size: 18),
              const SizedBox(width: 8),
              Text(
                top.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            top.summary,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Example: ${top.example}',
              style: const TextStyle(
                color: cyanNeon,
                fontSize: 10,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MODALS & DIALOGS
  // ============================================================

  void _showRiskAssessmentDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: bgDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'RISK PROFILER ASSESSMENT',
                            style: TextStyle(
                              color: cyanNeon,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                          Text(
                            '6 Institutional Profiling Dimensions',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white12),
                  Expanded(
                    child: ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: RiskAssessmentService.standardQuestions.length,
                      itemBuilder: (context, index) {
                        final q =
                            RiskAssessmentService.standardQuestions[index];
                        final currentScore = _riskAssessmentAnswers[q.id] ?? 2;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${index + 1}. ${q.question}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...q.options.map((opt) {
                                final isSelected = currentScore == opt.score;
                                return InkWell(
                                  onTap: () {
                                    setSheetState(() {
                                      _riskAssessmentAnswers[q.id] = opt.score;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? purpleNeon.withValues(alpha: 0.2)
                                          : cardDark,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isSelected
                                            ? cyanNeon
                                            : Colors.white10,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isSelected
                                              ? Icons.radio_button_checked
                                              : Icons.radio_button_off,
                                          color: isSelected
                                              ? cyanNeon
                                              : Colors.white30,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            opt.text,
                                            style: TextStyle(
                                              color: isSelected
                                                  ? Colors.white
                                                  : Colors.white70,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: purpleNeon,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Calculate & Calibrate Risk Profile',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () {
                        final breakdown =
                            RiskAssessmentService.evaluateAssessment(
                              selectedOptions: _riskAssessmentAnswers,
                              emergencyRunwayMonths: 4.0,
                              savingsRate: 25.0,
                              targetHorizonYears: 5.0,
                            );
                        setState(() {
                          _userRiskProfile = breakdown.profileType;
                        });
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showReadinessChecklistSheet(InvestmentReadinessReport report) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: bgDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '9-POINT INVESTMENT READINESS CHECKLIST',
                    style: TextStyle(
                      color: cyanNeon,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: report.checklist.length,
                  itemBuilder: (context, index) {
                    final item = report.checklist[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cardDark,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: item.isPassed
                              ? emeraldGreen.withValues(alpha: 0.3)
                              : goldAccent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            item.isPassed
                                ? Icons.check_circle
                                : Icons.warning_amber_rounded,
                            color: item.isPassed ? emeraldGreen : goldAccent,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  item.detail,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddInvestmentDialog(BuildContext context) {
    _assetNameController.clear();
    _investedController.clear();
    _currentController.clear();
    _selectedAssetType = 'Index Fund';

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: cardDark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              title: const Text(
                'Log Investment Asset',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Asset Name',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _assetNameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'e.g. Nifty 50 Index Fund, SGB Gold',
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Category Type',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedAssetType,
                      dropdownColor: cardDark,
                      items: const [
                        DropdownMenuItem(
                          value: 'Index Fund',
                          child: Text('Index Fund'),
                        ),
                        DropdownMenuItem(
                          value: 'Mutual Fund',
                          child: Text('Mutual Fund / Equity'),
                        ),
                        DropdownMenuItem(
                          value: 'Gold',
                          child: Text('Gold / SGB'),
                        ),
                        DropdownMenuItem(
                          value: 'PPF',
                          child: Text('PPF / EPF'),
                        ),
                        DropdownMenuItem(
                          value: 'Fixed Deposit',
                          child: Text('Fixed Deposit'),
                        ),
                        DropdownMenuItem(
                          value: 'Direct Stock',
                          child: Text('Direct Stock'),
                        ),
                        DropdownMenuItem(
                          value: 'Liquid Fund',
                          child: Text('Liquid Fund'),
                        ),
                      ],
                      onChanged: (val) =>
                          setDialogState(() => _selectedAssetType = val!),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Invested Amount',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _investedController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(hintText: '₹0'),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Current Value',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _currentController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(hintText: '₹0'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: purpleNeon),
                  child: const Text(
                    'Save Asset',
                    style: TextStyle(color: Colors.white),
                  ),
                  onPressed: () async {
                    final name = _assetNameController.text.trim();
                    final invested = double.tryParse(
                      _investedController.text.trim(),
                    );
                    final current = double.tryParse(
                      _currentController.text.trim(),
                    );

                    if (name.isNotEmpty &&
                        invested != null &&
                        current != null) {
                      final nav = Navigator.of(dialogCtx);
                      final provider = context.read<InvestmentProvider>();
                      final asset = InvestmentModel(
                        id: const Uuid().v4(),
                        name: name,
                        type: _selectedAssetType,
                        investedAmount: invested,
                        currentValue: current,
                        date: DateTime.now(),
                      );
                      await provider.addInvestment(asset);
                      if (!mounted) return;
                      nav.pop();
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}
