import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/finance_provider.dart';
import '../providers/budget_provider.dart';
import '../providers/financial_health_provider.dart';
import '../providers/ai_provider.dart';

import '../models/finance_transaction.dart';

import '../utils/currency_formatter.dart';

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
    ProfileScreen(),
  ];

  void _openPage(Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050914),
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF080D1A),
        border: Border(
          top: BorderSide(
            color: Color(0x1FFFFFFF),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: NavigationBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          indicatorColor: const Color(0x305B4BFF),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Transactions',
            ),
            NavigationDestination(
              icon: Icon(Icons.auto_awesome_outlined),
              selectedIcon: Icon(Icons.auto_awesome),
              label: 'AI',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// DASHBOARD HOME
// ============================================================

class DashboardHomeView extends StatelessWidget {
  const DashboardHomeView({super.key});

  static const Color background = Color(0xFF050914);
  static const Color cardColor = Color(0xFF0C1324);
  static const Color purple = Color(0xFF5B4BFF);
  static const Color cyan = Color(0xFF4CC9F0);
  static const Color green = Color(0xFF35D07F);
  static const Color red = Color(0xFFFF5577);

  void _openPage(BuildContext context, Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  String _formatCurrency(double value) {
    return CurrencyFormatter.format(value);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceProvider>(
      builder: (context, finance, _) {
        final income = finance.monthlyIncome;
        final expense = finance.monthlyExpense;
        final balance = finance.balance;
        final savings = finance.monthlySavings;

        final transactions = finance.transactions;

        return Scaffold(
          backgroundColor: background,
          body: Stack(
            children: [
              const _AuroraBackground(),

              SafeArea(
                child: RefreshIndicator(
                  color: cyan,
                  backgroundColor: cardColor,
                  onRefresh: () async {
                    await Future.delayed(
                      const Duration(milliseconds: 500),
                    );
                  },
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    slivers: [
                      SliverToBoxAdapter(
                        child: _buildHeader(context),
                      ),

                      SliverToBoxAdapter(
                        child: _buildBalanceCard(
                          context,
                          income,
                          expense,
                          balance,
                          savings,
                        ),
                      ),

                      SliverToBoxAdapter(
                        child: _buildQuickActions(context),
                      ),

                      
                      SliverToBoxAdapter(
                        child: _buildFinancialOverview(
                          context,
                          finance,
                        ),
                      ),

                      SliverToBoxAdapter(
                        child: _buildRecentTransactions(
                          context,
                          transactions,
                        ),
                      ),

                      SliverToBoxAdapter(
                        child: _buildToolsSection(context),
                      ),

                      const SliverToBoxAdapter(
                        child: SizedBox(height: 30),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [
                  purple,
                  cyan,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: purple.withValues(alpha: 0.35),
                  blurRadius: 18,
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.white,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FINPILOT AI',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Financial Command Center',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          IconButton(
            onPressed: () {
              _openPage(context, const SettingsScreen());
            },
            icon: const Icon(
              Icons.settings_outlined,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BALANCE CARD
  // ============================================================

  Widget _buildBalanceCard(
    BuildContext context,
    double income,
    double expense,
    double balance,
    double savings,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF151C45),
            const Color(0xFF0C1730),
            cyan.withValues(alpha: 0.12),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
        ),
        boxShadow: [
          BoxShadow(
            color: purple.withValues(alpha: 0.16),
            blurRadius: 30,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'TOTAL BALANCE',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.trending_up,
                      size: 14,
                      color: green,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Healthy',
                      style: TextStyle(
                        color: green,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            _formatCurrency(balance),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: _moneyStat(
                  icon: Icons.arrow_downward,
                  label: 'Income',
                  amount: income,
                  color: green,
                ),
              ),
              Container(
                height: 40,
                width: 1,
                color: Colors.white.withValues(alpha: 0.10),
              ),
              Expanded(
                child: _moneyStat(
                  icon: Icons.arrow_upward,
                  label: 'Expenses',
                  amount: expense,
                  color: red,
                ),
              ),
              Container(
                height: 40,
                width: 1,
                color: Colors.white.withValues(alpha: 0.10),
              ),
              Expanded(
                child: _moneyStat(
                  icon: Icons.savings_outlined,
                  label: 'Savings',
                  amount: savings,
                  color: cyan,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _moneyStat({
    required IconData icon,
    required String label,
    required double amount,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Icon(
            icon,
            size: 17,
            color: color,
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.50),
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            child: Text(
              _formatCurrency(amount),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // QUICK ACTIONS
  // ============================================================

  Widget _buildQuickActions(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          title: 'SMART ACTIONS',
          subtitle: 'Your most useful financial tools',
        ),
        const SizedBox(height: 14),

        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.55,
          children: [
            _actionButton(
              icon: Icons.remove_circle_outline,
              title: 'Add Expense',
              subtitle: 'Track spending',
              color: red,
              onTap: () {
                _openPage(
                  context,
                  const AddExpenseScreen(),
                );
              },
            ),

            _actionButton(
              icon: Icons.add_circle_outline,
              title: 'Add Income',
              subtitle: 'Record earnings',
              color: green,
              onTap: () {
                _openPage(
                  context,
                  const AddIncomeScreen(),
                );
              },
            ),

            _actionButton(
              icon: Icons.document_scanner_outlined,
              title: 'Scan Receipt',
              subtitle: 'AI OCR expense',
              color: cyan,
              onTap: () {
                _openPage(
                  context,
                  const ReceiptScannerScreen(),
                );
              },
            ),

            _actionButton(
              icon: Icons.account_balance_outlined,
              title: 'Bank Statement',
              subtitle: 'Import transactions',
              color: purple,
              onTap: () {
                _openPage(
                  context,
                  const BankStatementScreen(),
                );
              },
            ),

            _actionButton(
              icon: Icons.auto_awesome,
              title: 'AI Insights',
              subtitle: 'Understand money',
              color: const Color(0xFFFFC857),
              onTap: () {
                _openPage(
                  context,
                  const AIInsightsScreen(),
                );
              },
            ),

            _actionButton(
              icon: Icons.chat_bubble_outline,
              title: 'Ask FinPilot',
              subtitle: 'AI financial assistant',
              color: const Color(0xFFFF6B9D),
              onTap: () {
                _openPage(
                  context,
                  const AIChatScreen(),
                );
              },
            ),
          ],
        ),
      ],
    ),
  );
}
  Widget _actionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            Container(
              height: 42,
              width: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: color,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 9,
                    ),
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
  // SMART ACTIONS
  // ============================================================

  Widget _buildSmartActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 25, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'SMART ACTIONS',
            subtitle: 'AI-powered financial tools',
          ),

          const SizedBox(height: 14),

          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.55,
            children: [
              _smartAction(
                icon: Icons.document_scanner_outlined,
                title: 'Scan Receipt',
                subtitle: 'AI OCR expense',
                color: cyan,
                onTap: () {
                  _openPage(
                    context,
                    const ReceiptScannerScreen(),
                  );
                },
              ),
              _smartAction(
                icon: Icons.account_balance_outlined,
                title: 'Bank Statement',
                subtitle: 'Import transactions',
                color: purple,
                onTap: () {
                  _openPage(
                    context,
                    const BankStatementScreen(),
                  );
                },
              ),
              _smartAction(
                icon: Icons.auto_awesome,
                title: 'AI Insights',
                subtitle: 'Understand money',
                color: const Color(0xFFFFC857),
                onTap: () {
                  _openPage(
                    context,
                    const AIInsightsScreen(),
                  );
                },
              ),
              _smartAction(
                icon: Icons.chat_bubble_outline,
                title: 'Ask FinPilot',
                subtitle: 'AI financial assistant',
                color: const Color(0xFFFF6B9D),
                onTap: () {
                  _openPage(
                    context,
                    const AIChatScreen(),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _smartAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.07),
          ),
        ),
        child: Row(
          children: [
            Container(
              height: 42,
              width: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                icon,
                color: color,
                size: 21,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.42),
                      fontSize: 9,
                    ),
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
  // FINANCIAL OVERVIEW
  // ============================================================

  Widget _buildFinancialOverview(
    BuildContext context,
    FinanceProvider finance,
  ) {
    final categoryData = finance.monthlyCategorySpent;

    String highestCategory = 'No data';
    double highestAmount = 0;

    for (final entry in categoryData.entries) {
      if (entry.value > highestAmount) {
        highestAmount = entry.value;
        highestCategory = entry.key;
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 25, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'FINANCIAL OVERVIEW',
            subtitle: 'Your money at a glance',
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: _overviewCard(
                  icon: Icons.pie_chart_outline,
                  title: 'Top Spending',
                  value: highestCategory,
                  subtitle: _formatCurrency(highestAmount),
                  color: red,
                  onTap: () {
                    _openPage(
                      context,
                      const AnalyticsScreen(),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _overviewCard(
                  icon: Icons.track_changes,
                  title: 'Budget',
                  value: 'Manage',
                  subtitle: 'Track limits',
                  color: purple,
                  onTap: () {
                    _openPage(
                      context,
                      const BudgetScreen(),
                    );
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _overviewCard(
                  icon: Icons.favorite_border,
                  title: 'Health',
                  value: 'Check',
                  subtitle: 'Financial score',
                  color: green,
                  onTap: () {
                    _openPage(
                      context,
                      const FinancialHealthScreen(),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _overviewCard(
                  icon: Icons.flag_outlined,
                  title: 'Goals',
                  value: 'Plan',
                  subtitle: 'Build your future',
                  color: cyan,
                  onTap: () {
                    _openPage(
                      context,
                      const GoalsScreen(),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _overviewCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.07),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: color,
              size: 23,
            ),
            const SizedBox(height: 15),
            Text(
              title,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.50),
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color.withValues(alpha: 0.85),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // RECENT TRANSACTIONS
  // ============================================================

  Widget _buildRecentTransactions(
    BuildContext context,
    List<FinanceTransaction> transactions,
  ) {
    final recent = transactions.take(5).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: _SectionTitle(
                  title: 'RECENT TRANSACTIONS',
                  subtitle: 'Latest financial activity',
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TransactionsScreen(),
                    ),
                  );
                },
                child: const Text(
                  'View All',
                  style: TextStyle(
                    color: cyan,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          if (recent.isEmpty)
            _emptyTransactions()
          else
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.07),
                ),
              ),
              child: Column(
                children: [
                  for (int i = 0; i < recent.length; i++) ...[
                    _transactionTile(
                      context,
                      recent[i],
                    ),
                    if (i != recent.length - 1)
                      Divider(
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _transactionTile(
    BuildContext context,
    FinanceTransaction transaction,
  ) {
    final isIncome = transaction.type == TransactionType.income;

    final color = isIncome ? green : red;

    IconData icon;

    switch (transaction.category.toLowerCase()) {
      case 'food':
        icon = Icons.restaurant_outlined;
        break;
      case 'transport':
        icon = Icons.directions_car_outlined;
        break;
      case 'shopping':
        icon = Icons.shopping_bag_outlined;
        break;
      case 'bills':
        icon = Icons.receipt_outlined;
        break;
      case 'entertainment':
        icon = Icons.movie_outlined;
        break;
      case 'salary':
        icon = Icons.account_balance_wallet_outlined;
        break;
      case 'freelance':
        icon = Icons.work_outline;
        break;
      default:
        icon = isIncome
            ? Icons.arrow_downward
            : Icons.arrow_upward;
    }

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TransactionDetailsScreen(
              transaction: transaction,
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: color,
                size: 20,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${transaction.category} • ${transaction.paymentMethod}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.40),
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isIncome ? '+' : '-'}${_formatCurrency(transaction.amount)}',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(transaction.date),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
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

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}';
  }

  Widget _emptyTransactions() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.07),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            color: Colors.white.withValues(alpha: 0.35),
            size: 38,
          ),
          const SizedBox(height: 12),
          const Text(
            'No transactions yet',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Add an expense or income to get started.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.40),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ALL TOOLS
  // ============================================================

  Widget _buildToolsSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'FINANCIAL TOOLS',
            subtitle: 'Everything you need in one place',
          ),

          const SizedBox(height: 14),

          _toolTile(
            icon: Icons.analytics_outlined,
            title: 'Analytics & Spending',
            subtitle: 'Charts, categories and spending patterns',
            color: cyan,
            onTap: () {
              _openPage(context, const AnalyticsScreen());
            },
          ),

          _toolTile(
            icon: Icons.flag_outlined,
            title: 'Goals',
            subtitle: 'Create and track your financial goals',
            color: const Color(0xFFFFC857),
            onTap: () {
              _openPage(context, const GoalsScreen());
            },
          ),

          _toolTile(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Budget Planner',
            subtitle: 'Set category limits and monitor spending',
            color: purple,
            onTap: () {
              _openPage(context, const BudgetScreen());
            },
          ),

          _toolTile(
            icon: Icons.trending_up,
            title: 'Investment Planner',
            subtitle: 'Goal-based investment recommendations',
            color: green,
            onTap: () {
              _openPage(context, const InvestmentScreen());
            },
          ),

          _toolTile(
            icon: Icons.auto_graph,
            title: 'Future Simulator',
            subtitle: 'See where your money could take you',
            color: cyan,
            onTap: () {
              _openPage(context, const FutureSimulatorScreen());
            },
          ),

          _toolTile(
            icon: Icons.favorite_outline,
            title: 'Financial Health',
            subtitle: 'Check your financial wellness score',
            color: const Color(0xFFFF6B9D),
            onTap: () {
              _openPage(
                context,
                const FinancialHealthScreen(),
              );
            },
          ),

          _toolTile(
            icon: Icons.description_outlined,
            title: 'Reports',
            subtitle: 'Generate financial reports',
            color: const Color(0xFFB58CFF),
            onTap: () {
              _openPage(context, const ReportsScreen());
            },
          ),

          _toolTile(
            icon: Icons.settings_outlined,
            title: 'Settings',
            subtitle: 'Customize your FinPilot experience',
            color: Colors.white70,
            onTap: () {
              _openPage(context, const SettingsScreen());
            },
          ),
        ],
      ),
    );
  }

  Widget _toolTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            children: [
              Container(
                height: 43,
                width: 43,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 21,
                ),
              ),

              const SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.42),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),

              Icon(
                Icons.chevron_right,
                color: Colors.white.withValues(alpha: 0.30),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// SECTION TITLE
// ============================================================

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.38),
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// AURORA BACKGROUND
// ============================================================

class _AuroraBackground extends StatefulWidget {
  const _AuroraBackground();

  @override
  State<_AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<_AuroraBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final value = _controller.value;

        return IgnorePointer(
          child: CustomPaint(
            size: MediaQuery.of(context).size,
            painter: _AuroraPainter(value),
          ),
        );
      },
    );
  }
}

class _AuroraPainter extends CustomPainter {
  final double animation;

  _AuroraPainter(this.animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..maskFilter = const MaskFilter.blur(
        BlurStyle.normal,
        80,
      );

    final dx = math.sin(animation * math.pi * 2) * 60;
    final dy = math.cos(animation * math.pi * 2) * 40;

    paint.color = const Color(0xFF5B4BFF).withValues(alpha: 0.09);

    canvas.drawCircle(
      Offset(
        size.width * 0.85 + dx,
        size.height * 0.08 + dy,
      ),
      130,
      paint,
    );

    paint.color = const Color(0xFF4CC9F0).withValues(alpha: 0.06);

    canvas.drawCircle(
      Offset(
        size.width * 0.10 - dx,
        size.height * 0.38 - dy,
      ),
      110,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter oldDelegate) {
    return oldDelegate.animation != animation;
  }
}