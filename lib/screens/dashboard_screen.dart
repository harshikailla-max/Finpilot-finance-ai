import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/finance_transaction.dart';
import '../models/goal_model.dart';
import '../providers/budget_provider.dart';
import '../providers/finance_provider.dart';
import '../providers/financial_health_provider.dart';
import '../providers/goal_provider.dart';
import '../providers/investment_provider.dart';
import '../utils/constants.dart';
import '../utils/currency_formatter.dart';
import '../widgets/aura/aura_background.dart';
import '../widgets/aura/aura_glass_card.dart';
import '../widgets/aura/aura_orb.dart';
import '../widgets/aura/command_tile.dart';
import '../widgets/aura/luxury_metric.dart';

import 'add_expense_screen.dart';
import 'add_income_screen.dart';
import 'ai_chat_screen.dart';
import 'ai_insights_screen.dart';
import 'analytics_screen.dart';
import 'bank_statement_screen.dart';
import 'budget_screen.dart';
import 'financial_health_screen.dart';
import 'future_simulator_screen.dart';
import 'goals_screen.dart';
import 'investment_screen.dart';
import 'profile_screen.dart';
import 'receipt_scanner_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import 'transaction_details_screen.dart';
import 'transactions_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  final List<Widget> _tabs = const [
    DashboardHomeView(),
    TransactionsScreen(),
    AIChatScreen(),
    InvestmentScreen(),
    ProfileScreen(),
  ];

  void _onTabSelected(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    if (isDesktop) {
      return Scaffold(
        backgroundColor: AppColors.obsidian,
        body: Row(
          children: [
            // Left Desktop Navigation Rail
            _buildDesktopNavRail(),

            // Main View Area
            Expanded(
              child: IndexedStack(index: _currentIndex, children: _tabs),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.obsidian,
      body: IndexedStack(index: _currentIndex, children: _tabs),
      bottomNavigationBar: _buildLuxuryBottomNav(),
    );
  }

  // ============================================================
  // DESKTOP NAVIGATION RAIL
  // ============================================================
  Widget _buildDesktopNavRail() {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.95),
        border: const Border(
          right: BorderSide(color: AppColors.glassBorder, width: 1),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 28),
          // Brand & FinPilot Orb
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const FinPilotAuraOrb(
                  size: 38,
                  state: AuraOrbState.idle,
                  showOuterHalo: false,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FINPILOT AURA',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.0,
                        fontFamily: AppTypography.fontFamily,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'AI WEALTH OS • 2030',
                      style: TextStyle(
                        color: AppColors.auroraCyan.withValues(alpha: 0.8),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),

          // Nav Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              children: [
                _desktopNavItem(0, Icons.dashboard_rounded, 'Command Center'),
                _desktopNavItem(1, Icons.receipt_long_rounded, 'Transactions'),
                _desktopNavItem(2, Icons.auto_awesome, 'AI Financial Advisor'),
                _desktopNavItem(
                  3,
                  Icons.account_balance_rounded,
                  'Investments',
                ),
                _desktopNavItem(4, Icons.person_rounded, 'Private Profile'),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(color: AppColors.glassBorder, height: 1),
                ),
                _desktopActionItem(
                  Icons.trending_up_rounded,
                  'Future Simulator',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const FutureSimulatorScreen(),
                    ),
                  ),
                ),
                _desktopActionItem(
                  Icons.health_and_safety_outlined,
                  'Financial Health',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const FinancialHealthScreen(),
                    ),
                  ),
                ),
                _desktopActionItem(
                  Icons.pie_chart_outline_rounded,
                  'Spending DNA',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
                  ),
                ),
                _desktopActionItem(
                  Icons.flag_outlined,
                  'Destinations',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const GoalsScreen()),
                  ),
                ),
                _desktopActionItem(
                  Icons.settings_outlined,
                  'System Settings',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Quick Status
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.successGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'All Engines Optimal',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
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

  Widget _desktopNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: () => _onTabSelected(index),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.auroraViolet.withValues(alpha: 0.16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? AppColors.auroraViolet.withValues(alpha: 0.4)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected
                    ? AppColors.auroraViolet
                    : AppColors.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _desktopActionItem(IconData icon, String label, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: AppColors.textMuted, size: 18),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // LUXURY MOBILE BOTTOM NAVIGATION
  // ============================================================
  Widget _buildLuxuryBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.92),
        border: const Border(
          top: BorderSide(color: AppColors.glassBorder, width: 1),
        ),
      ),
      child: SafeArea(
        child: Container(
          height: 68,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _mobileNavButton(
                index: 0,
                icon: Icons.dashboard_rounded,
                label: 'Universe',
              ),
              _mobileNavButton(
                index: 1,
                icon: Icons.receipt_long_rounded,
                label: 'Activity',
              ),

              // Elevated Central FinPilot Aura Orb
              GestureDetector(
                onTap: () => _onTabSelected(2),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.auroraViolet.withValues(
                              alpha: 0.35,
                            ),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: FinPilotAuraOrb(
                        size: 38,
                        state: _currentIndex == 2
                            ? AuraOrbState.speaking
                            : AuraOrbState.idle,
                        showOuterHalo: false,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'AI Advisor',
                      style: TextStyle(
                        color: _currentIndex == 2
                            ? AppColors.auroraViolet
                            : AppColors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

              _mobileNavButton(
                index: 3,
                icon: Icons.account_balance_rounded,
                label: 'Invest',
              ),
              _mobileNavButton(
                index: 4,
                icon: Icons.person_rounded,
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mobileNavButton({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _currentIndex == index;
    return InkWell(
      onTap: () => _onTabSelected(index),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? AppColors.auroraCyan : AppColors.textMuted,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.textPrimary : AppColors.textMuted,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// DASHBOARD HOME VIEW (CINEMATIC WEALTH FEED)
// ============================================================

class DashboardHomeView extends StatelessWidget {
  const DashboardHomeView({super.key});

  void _openPage(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    return Consumer5<
      FinanceProvider,
      GoalProvider,
      InvestmentProvider,
      FinancialHealthProvider,
      BudgetProvider
    >(
      builder:
          (
            context,
            finance,
            goalProvider,
            investmentProvider,
            healthProvider,
            budgetProvider,
            _,
          ) {
            final balance = finance.balance;
            final income = finance.monthlyIncome;
            final expense = finance.monthlyExpense;
            final savings = finance.monthlySavings;
            final portfolioValue = investmentProvider.totalCurrentValue;
            final healthScore = healthProvider.healthData.totalScore.round();

            return Scaffold(
              backgroundColor: AppColors.obsidian,
              body: Stack(
                children: [
                  // Atmospheric Multi-Layer Aurora Canvas
                  const AuraBackground(),

                  SafeArea(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Center Main Scrollable Feed
                        Expanded(
                          flex: 3,
                          child: RefreshIndicator(
                            color: AppColors.auroraCyan,
                            backgroundColor: AppColors.secondaryBackground,
                            onRefresh: () async {
                              await Future.delayed(
                                const Duration(milliseconds: 400),
                              );
                            },
                            child: CustomScrollView(
                              physics: const BouncingScrollPhysics(
                                parent: AlwaysScrollableScrollPhysics(),
                              ),
                              slivers: [
                                // 1. Sleek Brand Header
                                SliverToBoxAdapter(
                                  child: _buildHeader(context),
                                ),

                                // 2. Wealth Hero (Your Financial Universe)
                                SliverToBoxAdapter(
                                  child: _buildWealthHero(
                                    context,
                                    balance: balance,
                                    income: income,
                                    expense: expense,
                                    savings: savings,
                                    portfolioValue: portfolioValue,
                                  ),
                                ),

                                // 3. AI Financial Briefing
                                SliverToBoxAdapter(
                                  child: _buildAIBriefing(
                                    context,
                                    income: income,
                                    expense: expense,
                                    savings: savings,
                                    healthScore: healthScore,
                                  ),
                                ),

                                // 4. Your Next Best Move
                                SliverToBoxAdapter(
                                  child: _buildNextBestMove(context),
                                ),

                                // 5. Financial Command Center
                                SliverToBoxAdapter(
                                  child: _buildCommandCenter(context),
                                ),

                                // 6. Spending DNA
                                SliverToBoxAdapter(
                                  child: _buildSpendingDNA(
                                    context,
                                    finance: finance,
                                  ),
                                ),

                                // 7. Financial Destinations (Goals)
                                SliverToBoxAdapter(
                                  child: _buildFinancialDestinations(
                                    context,
                                    goals: goalProvider.goals,
                                  ),
                                ),

                                // 8. Financial Timeline (Recent Transactions)
                                SliverToBoxAdapter(
                                  child: _buildFinancialTimeline(
                                    context,
                                    transactions: finance.transactions,
                                  ),
                                ),

                                const SliverToBoxAdapter(
                                  child: SizedBox(height: 40),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Right Intelligence Rail (Desktop Only)
                        if (isDesktop)
                          Expanded(
                            flex: 1,
                            child: _buildDesktopRightRail(
                              context,
                              healthScore: healthScore,
                              goals: goalProvider.goals,
                              monthlySavings: savings,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
    );
  }

  // ============================================================
  // 1. BRAND HEADER
  // ============================================================
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.auroraViolet.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.auroraViolet.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.auroraCyan,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'ORB ACTIVE • 2030',
                  style: TextStyle(
                    color: AppColors.auroraCyan,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => _openPage(context, const ReceiptScannerScreen()),
            icon: const Icon(
              Icons.receipt_long_rounded,
              color: AppColors.textSecondary,
              size: 20,
            ),
            tooltip: 'Smart Receipt Expense',
          ),
          IconButton(
            onPressed: () => _openPage(context, const SettingsScreen()),
            icon: const Icon(
              Icons.tune_rounded,
              color: AppColors.textSecondary,
              size: 20,
            ),
            tooltip: 'Settings',
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 2. WEALTH HERO (YOUR FINANCIAL UNIVERSE)
  // ============================================================
  Widget _buildWealthHero(
    BuildContext context, {
    required double balance,
    required double income,
    required double expense,
    required double savings,
    required double portfolioValue,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
      child: AuraGlassCard(
        level: AuraGlassLevel.level4,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'YOUR FINANCIAL UNIVERSE',
                  style: TextStyle(
                    color: AppColors.textSecondary.withValues(alpha: 0.8),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                    fontFamily: AppTypography.fontFamily,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.successGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.successGreen.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.trending_up_rounded,
                        size: 13,
                        color: AppColors.successGreen,
                      ),
                      SizedBox(width: 4),
                      Text(
                        '+12.4% THIS MONTH',
                        style: TextStyle(
                          color: AppColors.successGreen,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Massive Luxury Metric Balance
            LuxuryMetric(
              label: 'Total Net Liquid Capital',
              value: CurrencyFormatter.format(balance),
              valueSize: 46,
              valueColor: AppColors.textPrimary,
            ),

            const SizedBox(height: 24),

            // Inline Wealth Quadrants
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.025),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _heroStatItem(
                      label: 'Inflow',
                      amount: income,
                      color: AppColors.successGreen,
                      icon: Icons.south_west_rounded,
                    ),
                  ),
                  _divider(),
                  Expanded(
                    child: _heroStatItem(
                      label: 'Outflow',
                      amount: expense,
                      color: AppColors.dangerRed,
                      icon: Icons.north_east_rounded,
                    ),
                  ),
                  _divider(),
                  Expanded(
                    child: _heroStatItem(
                      label: 'Savings',
                      amount: savings,
                      color: AppColors.auroraCyan,
                      icon: Icons.shield_outlined,
                    ),
                  ),
                  _divider(),
                  Expanded(
                    child: _heroStatItem(
                      label: 'Portfolio',
                      amount: portfolioValue,
                      color: AppColors.luxuryChampagne,
                      icon: Icons.auto_graph_rounded,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Fast Command Row
            Row(
              children: [
                Expanded(
                  child: _quickActionButton(
                    icon: Icons.remove_circle_outline_rounded,
                    label: 'Expense',
                    color: AppColors.dangerRed,
                    onTap: () => _openPage(context, const AddExpenseScreen()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _quickActionButton(
                    icon: Icons.add_circle_outline_rounded,
                    label: 'Income',
                    color: AppColors.successGreen,
                    onTap: () => _openPage(context, const AddIncomeScreen()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _quickActionButton(
                    icon: Icons.document_scanner_outlined,
                    label: 'Receipt',
                    color: AppColors.auroraCyan,
                    onTap: () =>
                        _openPage(context, const ReceiptScannerScreen()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _quickActionButton(
                    icon: Icons.account_balance_outlined,
                    label: 'Bank PDF',
                    color: AppColors.auroraViolet,
                    onTap: () =>
                        _openPage(context, const BankStatementScreen()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() {
    return Container(
      height: 32,
      width: 1,
      color: Colors.white.withValues(alpha: 0.08),
    );
  }

  Widget _heroStatItem({
    required String label,
    required double amount,
    required Color color,
    required IconData icon,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                color: AppColors.textSecondary.withValues(alpha: 0.7),
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        FittedBox(
          child: Text(
            CurrencyFormatter.format(amount),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _quickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // 3. AI FINANCIAL BRIEFING
  // ============================================================
  Widget _buildAIBriefing(
    BuildContext context, {
    required double income,
    required double expense,
    required double savings,
    required int healthScore,
  }) {
    final savingsRatio = income > 0 ? (savings / income * 100).round() : 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
      child: AuraGlassCard(
        level: AuraGlassLevel.level3,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const FinPilotAuraOrb(
                  size: 42,
                  state: AuraOrbState.speaking,
                  showOuterHalo: false,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FINPILOT INTELLIGENCE',
                        style: TextStyle(
                          color: AppColors.auroraCyan,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          fontFamily: AppTypography.fontFamily,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Morning Financial Briefing',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.auroraViolet.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'LIVE',
                    style: TextStyle(
                      color: AppColors.auroraViolet,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Dynamic Executive Summary
            Text(
              'Your cash flow velocity is stable with a $savingsRatio% monthly retention rate. '
              'Health score stands at $healthScore/100. Discretionary outflow is disciplined, leaving actionable liquidity ready for compounding.',
              style: TextStyle(
                color: AppColors.textSecondary.withValues(alpha: 0.9),
                fontSize: 12,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 14),

            // Dual Intelligence Observation Pills
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.successGreen.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.successGreen.withValues(alpha: 0.2),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 14,
                          color: AppColors.successGreen,
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Savings rate +14% vs peers',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.warningAmber.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.warningAmber.withValues(alpha: 0.2),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.bolt_outlined,
                          size: 14,
                          color: AppColors.warningAmber,
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '3 Bills due in next 7 days',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Today's Money Move
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.auroraViolet.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.auroraViolet.withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "TODAY'S MONEY MOVE",
                    style: TextStyle(
                      color: AppColors.auroraViolet,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Direct ₹3,500 idle liquidity into liquid debt or short-term yield to capture ~7.1% annualized return.',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () =>
                            _openPage(context, const AIChatScreen()),
                        child: const Text(
                          'Ask FinPilot',
                          style: TextStyle(
                            color: AppColors.auroraCyan,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.auroraViolet,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () =>
                            _openPage(context, const InvestmentScreen()),
                        child: const Text(
                          'Explore Move',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // 4. NEXT BEST MOVE
  // ============================================================
  Widget _buildNextBestMove(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: AuraGlassCard(
        level: AuraGlassLevel.level3,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.luxuryChampagne.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    size: 16,
                    color: AppColors.luxuryChampagne,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'YOUR NEXT BEST MOVE',
                  style: TextStyle(
                    color: AppColors.luxuryChampagne,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                    fontFamily: AppTypography.fontFamily,
                  ),
                ),
                const Spacer(),
                Text(
                  'High Conviction',
                  style: TextStyle(
                    color: AppColors.textSecondary.withValues(alpha: 0.6),
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Increase Monthly SIP by +₹2,000',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Deploying an additional ₹2,000/month into broad-market index funds projects +₹14.8 Lakhs compounding advantage over a 10-year horizon.',
              style: TextStyle(
                color: AppColors.textSecondary.withValues(alpha: 0.85),
                fontSize: 11,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current 10Y Path',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 9,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '₹23.6 Lakhs',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 14,
                  color: AppColors.luxuryChampagne,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.luxuryChampagne.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.luxuryChampagne.withValues(
                          alpha: 0.25,
                        ),
                      ),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Optimized 10Y Path',
                          style: TextStyle(
                            color: AppColors.luxuryChampagne,
                            fontSize: 9,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '₹38.4 Lakhs',
                          style: TextStyle(
                            color: AppColors.luxuryChampagne,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondaryBackground,
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.glassBorder),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () =>
                    _openPage(context, const FutureSimulatorScreen()),
                child: const Text(
                  'Simulate & Optimize Trajectory',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // 5. FINANCIAL COMMAND CENTER
  // ============================================================
  Widget _buildCommandCenter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            'FINANCIAL COMMAND CENTER',
            'Execute intelligent actions across your wealth stack',
          ),
          const SizedBox(height: 14),

          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.1,
            children: [
              CommandTile(
                icon: Icons.remove_circle_outline_rounded,
                title: 'Track Expense',
                subtitle: 'Log spending',
                accentColor: AppColors.dangerRed,
                onTap: () => _openPage(context, const AddExpenseScreen()),
              ),
              CommandTile(
                icon: Icons.add_circle_outline_rounded,
                title: 'Add Income',
                subtitle: 'Record inflow',
                accentColor: AppColors.successGreen,
                onTap: () => _openPage(context, const AddIncomeScreen()),
              ),
              CommandTile(
                icon: Icons.receipt_long_rounded,
                title: 'Smart Receipt',
                subtitle: 'Instant expense',
                accentColor: AppColors.auroraCyan,
                onTap: () => _openPage(context, const ReceiptScannerScreen()),
              ),
              CommandTile(
                icon: Icons.account_balance_outlined,
                title: 'Bank PDF Intelligence',
                subtitle: 'Multi-bank parser',
                accentColor: AppColors.auroraViolet,
                onTap: () => _openPage(context, const BankStatementScreen()),
              ),
              CommandTile(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Budget Planner',
                subtitle: 'Category limits',
                accentColor: AppColors.softBlue,
                onTap: () => _openPage(context, const BudgetScreen()),
              ),
              CommandTile(
                icon: Icons.flag_outlined,
                title: 'Wealth Goals',
                subtitle: 'Future milestones',
                accentColor: AppColors.luxuryChampagne,
                onTap: () => _openPage(context, const GoalsScreen()),
              ),
              CommandTile(
                icon: Icons.auto_graph_rounded,
                title: 'Investment Center',
                subtitle: 'Portfolio engine',
                accentColor: AppColors.auroraViolet,
                onTap: () => _openPage(context, const InvestmentScreen()),
              ),
              CommandTile(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'Ask FinPilot',
                subtitle: 'Private advisor',
                accentColor: AppColors.auroraCyan,
                onTap: () => _openPage(context, const AIChatScreen()),
              ),
              CommandTile(
                icon: Icons.insights_rounded,
                title: 'AI Insights',
                subtitle: 'Deep financial radar',
                accentColor: AppColors.softBlue,
                onTap: () => _openPage(context, const AIInsightsScreen()),
              ),
              CommandTile(
                icon: Icons.description_outlined,
                title: 'Wealth Reports',
                subtitle: 'Executive summaries',
                accentColor: AppColors.luxuryChampagne,
                onTap: () => _openPage(context, const ReportsScreen()),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 6. SPENDING DNA
  // ============================================================
  Widget _buildSpendingDNA(
    BuildContext context, {
    required FinanceProvider finance,
  }) {
    final categoryData = finance.monthlyCategorySpent;
    final totalSpent = finance.monthlyExpense;

    final sortedEntries = categoryData.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topCategory = sortedEntries.isNotEmpty
        ? sortedEntries.first.key
        : 'None';
    final topAmount = sortedEntries.isNotEmpty
        ? sortedEntries.first.value
        : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: AuraGlassCard(
        level: AuraGlassLevel.level2,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.bubble_chart_outlined,
                  color: AppColors.auroraCyan,
                  size: 18,
                ),
                const SizedBox(width: 8),
                _sectionHeader(
                  'SPENDING DNA',
                  'Behavioral outflow decomposition',
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => _openPage(context, const AnalyticsScreen()),
                  child: const Text(
                    'Full Analytics',
                    style: TextStyle(
                      color: AppColors.auroraCyan,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (sortedEntries.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'No categorized expenses for this period.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ),
              )
            else ...[
              // Highlight Top Spending
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.025),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.dangerRed.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.pie_chart_rounded,
                        size: 16,
                        color: AppColors.dangerRed,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Primary Capital Outflow: $topCategory',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            totalSpent > 0
                                ? '${(topAmount / totalSpent * 100).toStringAsFixed(1)}% of total monthly spending'
                                : '0%',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      CurrencyFormatter.format(topAmount),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Category Bars
              ...sortedEntries.take(4).map((entry) {
                final ratio = totalSpent > 0
                    ? (entry.value / totalSpent).clamp(0.0, 1.0)
                    : 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            entry.key,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            CurrencyFormatter.format(entry.value),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ratio,
                          backgroundColor: Colors.white.withValues(alpha: 0.06),
                          color: _categoryColor(entry.key),
                          minHeight: 5,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Color _categoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return AppColors.warningAmber;
      case 'transport':
        return AppColors.auroraCyan;
      case 'shopping':
        return AppColors.dangerRed;
      case 'bills':
        return AppColors.auroraViolet;
      default:
        return AppColors.softBlue;
    }
  }

  // ============================================================
  // 7. FINANCIAL DESTINATIONS (GOALS)
  // ============================================================
  Widget _buildFinancialDestinations(
    BuildContext context, {
    required List<GoalModel> goals,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: AuraGlassCard(
        level: AuraGlassLevel.level2,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.flag_outlined,
                  color: AppColors.luxuryChampagne,
                  size: 18,
                ),
                const SizedBox(width: 8),
                _sectionHeader(
                  'FINANCIAL DESTINATIONS',
                  'Milestone achievement vectors',
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => _openPage(context, const GoalsScreen()),
                  child: const Text(
                    'All Goals',
                    style: TextStyle(
                      color: AppColors.luxuryChampagne,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (goals.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Column(
                    children: [
                      const Text(
                        'No wealth targets established yet.',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () =>
                            _openPage(context, const GoalsScreen()),
                        child: const Text(
                          '+ Establish First Goal',
                          style: TextStyle(
                            color: AppColors.luxuryChampagne,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Column(
                children: goals.take(3).map((goal) {
                  final progress = goal.targetAmount > 0
                      ? (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0)
                      : 0.0;
                  final percentage = (progress * 100).toStringAsFixed(0);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.025),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                goal.title,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: progress >= 0.8
                                    ? AppColors.successGreen.withValues(
                                        alpha: 0.12,
                                      )
                                    : AppColors.auroraCyan.withValues(
                                        alpha: 0.12,
                                      ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                progress >= 1.0 ? 'ACHIEVED' : 'ON TRACK',
                                style: TextStyle(
                                  color: progress >= 0.8
                                      ? AppColors.successGreen
                                      : AppColors.auroraCyan,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${CurrencyFormatter.format(goal.currentAmount)} / ${CurrencyFormatter.format(goal.targetAmount)}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '$percentage%',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.06,
                            ),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.luxuryChampagne,
                            ),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // 8. FINANCIAL TIMELINE (RECENT TRANSACTIONS)
  // ============================================================
  Widget _buildFinancialTimeline(
    BuildContext context, {
    required List<FinanceTransaction> transactions,
  }) {
    final recent = transactions.take(5).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: AuraGlassCard(
        level: AuraGlassLevel.level2,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.history_rounded,
                  color: AppColors.softBlue,
                  size: 18,
                ),
                const SizedBox(width: 8),
                _sectionHeader(
                  'FINANCIAL TIMELINE',
                  'Verified capital transfers',
                ),
                const Spacer(),
                TextButton(
                  onPressed: () =>
                      _openPage(context, const TransactionsScreen()),
                  child: const Text(
                    'View All',
                    style: TextStyle(
                      color: AppColors.softBlue,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (recent.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'No transaction events logged yet.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ),
              )
            else
              Column(
                children: [
                  for (int i = 0; i < recent.length; i++) ...[
                    _timelineTile(context, recent[i]),
                    if (i != recent.length - 1)
                      Divider(
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _timelineTile(BuildContext context, FinanceTransaction tx) {
    final isIncome = tx.type == TransactionType.income;
    final color = isIncome ? AppColors.successGreen : AppColors.dangerRed;

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TransactionDetailsScreen(transaction: tx),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isIncome ? Icons.south_west_rounded : Icons.north_east_rounded,
                color: color,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${tx.category} • ${tx.paymentMethod}',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isIncome ? '+' : '-'}${CurrencyFormatter.format(tx.amount)}',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${tx.date.day.toString().padLeft(2, '0')}/${tx.date.month.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DESKTOP RIGHT INTELLIGENCE RAIL
  // ============================================================
  Widget _buildDesktopRightRail(
    BuildContext context, {
    required int healthScore,
    required List<GoalModel> goals,
    required double monthlySavings,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.75),
        border: const Border(
          left: BorderSide(color: AppColors.glassBorder, width: 1),
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'INTELLIGENCE RADAR',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              fontFamily: AppTypography.fontFamily,
            ),
          ),
          const SizedBox(height: 16),

          // Health Score Radar
          AuraGlassCard(
            level: AuraGlassLevel.level3,
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.shield_rounded,
                      size: 16,
                      color: AppColors.auroraCyan,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Financial Vitality',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 90,
                      height: 90,
                      child: CircularProgressIndicator(
                        value: healthScore / 100,
                        backgroundColor: Colors.white.withValues(alpha: 0.05),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.auroraCyan,
                        ),
                        strokeWidth: 8,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$healthScore',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Text(
                          '/ 100',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () =>
                      _openPage(context, const FinancialHealthScreen()),
                  child: const Text(
                    'Inspect Diagnostic Report',
                    style: TextStyle(
                      color: AppColors.auroraCyan,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Daily Safe Spend Limit
          AuraGlassCard(
            level: AuraGlassLevel.level2,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DAILY SAFE-TO-SPEND',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '₹1,450 / day',
                  style: TextStyle(
                    color: AppColors.successGreen,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Spending below this ceiling preserves your targeted 40% monthly savings velocity.',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Ask FinPilot Fast Prompt
          AuraGlassCard(
            level: AuraGlassLevel.level3,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    FinPilotAuraOrb(
                      size: 24,
                      state: AuraOrbState.thinking,
                      showOuterHalo: false,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'AI Copilot Quick Query',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  '"How does my portfolio risk compare to market volatility?"',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.auroraViolet,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () => _openPage(context, const AIChatScreen()),
                    child: const Text(
                      'Launch Advisor Session',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
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

  Widget _sectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            fontFamily: AppTypography.fontFamily,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(
            color: AppColors.textSecondary.withValues(alpha: 0.65),
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
