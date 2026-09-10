import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/goal_model.dart';
import '../models/investment_model.dart';
import '../providers/goal_provider.dart';
import '../providers/investment_provider.dart';
import '../utils/constants.dart';
import '../utils/currency_formatter.dart';
import '../widgets/empty_state.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_button.dart';

class InvestmentScreen extends StatefulWidget {
  const InvestmentScreen({super.key});

  @override
  State<InvestmentScreen> createState() => _InvestmentScreenState();
}

class _InvestmentScreenState extends State<InvestmentScreen> {
  // ============================================================
  // INVESTMENT FORM CONTROLLERS
  // ============================================================

  final _nameController = TextEditingController();
  final _investedController = TextEditingController();
  final _currentController = TextEditingController();

  String _selectedType = 'Mutual Fund';

  // ============================================================
  // AI INVESTMENT PLANNER
  // ============================================================

  String? _selectedGoalId;

  String _riskProfile = 'Moderate';

  double _expectedReturn = 8.0;

  // ============================================================
  // LIFECYCLE
  // ============================================================

  @override
  void dispose() {
    _nameController.dispose();
    _investedController.dispose();
    _currentController.dispose();
    super.dispose();
  }

  // ============================================================
  // ADD INVESTMENT
  // ============================================================

  void _showAddInvestmentDialog() {
    _nameController.clear();
    _investedController.clear();
    _currentController.clear();
    _selectedType = 'Mutual Fund';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.secondaryBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: const Text(
                'Log Investment',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Asset Name',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'e.g. HDFC Index Fund, SGB Gold',
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Investment Type',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedType,
                      dropdownColor: AppColors.cardBackground,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                        ),
                      ),
                      items: AppConstants.investmentTypes.map((type) {
                        return DropdownMenuItem<String>(
                          value: type,
                          child: Text(type),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value == null) return;

                        setDialogState(() {
                          _selectedType = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Invested Amount',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _investedController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: '₹0',
                        prefixIcon: Icon(
                          Icons.currency_rupee,
                          color: AppColors.textMuted,
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Current Value',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _currentController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: '₹0',
                        prefixIcon: Icon(
                          Icons.currency_rupee,
                          color: AppColors.textMuted,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final name = _nameController.text.trim();
                    final invested = double.tryParse(
                      _investedController.text.trim(),
                    );
                    final current = double.tryParse(
                      _currentController.text.trim(),
                    );

                    if (name.isEmpty ||
                        invested == null ||
                        current == null ||
                        invested < 0 ||
                        current < 0) {
                      return;
                    }

                    final asset = InvestmentModel(
                      id: const Uuid().v4(),
                      name: name,
                      type: _selectedType,
                      investedAmount: invested,
                      currentValue: current,
                      date: DateTime.now(),
                    );

                    await context
                        .read<InvestmentProvider>()
                        .addInvestment(asset);

                    if (!mounted) return;

                    Navigator.pop(dialogContext);
                  },
                  child: const Text(
                    'Save',
                    style: TextStyle(
                      color: AppColors.cyan,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================
  // UPDATE INVESTMENT VALUE
  // ============================================================

  void _showUpdateValueDialog(InvestmentModel asset) {
    _currentController.text =
        asset.currentValue.toStringAsFixed(0);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.secondaryBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'Update "${asset.name}" Value',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Invested Amount: ${CurrencyFormatter.format(asset.investedAmount)}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _currentController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Enter new value',
                  prefixIcon: Icon(
                    Icons.currency_rupee,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                final amount = double.tryParse(
                  _currentController.text.trim(),
                );

                if (amount == null || amount < 0) return;

                final updated = asset.copyWith(
                  currentValue: amount,
                );

                await context
                    .read<InvestmentProvider>()
                    .updateInvestment(updated);

                if (!mounted) return;

                Navigator.pop(dialogContext);
              },
              child: const Text(
                'Update',
                style: TextStyle(
                  color: AppColors.cyan,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // SELECT GOAL
  // ============================================================

  void _selectGoal(String? goalId) {
    setState(() {
      _selectedGoalId = goalId;
    });
  }

  // ============================================================
  // GET SELECTED GOAL
  // ============================================================

  GoalModel? _getSelectedGoal(List<GoalModel> goals) {
    if (goals.isEmpty) return null;

    if (_selectedGoalId == null) {
      return goals.first;
    }

    for (final goal in goals) {
      if (goal.id == _selectedGoalId) {
        return goal;
      }
    }

    return goals.first;
  }

  // ============================================================
  // RISK RETURN
  // ============================================================

  void _setRisk(String risk) {
    setState(() {
      _riskProfile = risk;

      if (risk == 'Low') {
        _expectedReturn = 6.0;
      } else if (risk == 'Moderate') {
        _expectedReturn = 8.0;
      } else {
        _expectedReturn = 12.0;
      }
    });
  }

  // ============================================================
  // MONTHLY INVESTMENT CALCULATION
  // ============================================================

  double _calculateRequiredMonthly(
    GoalModel goal,
  ) {
    final remaining = goal.remainingAmount;

    if (remaining <= 0) return 0;

    final months = math.max(
      1,
      (goal.daysRemaining / 30.4375).ceil(),
    );

    final monthlyRate =
        _expectedReturn / 100 / 12;

    if (monthlyRate <= 0) {
      return remaining / months;
    }

    final factor = math.pow(
      1 + monthlyRate,
      months,
    );

    final denominator = factor - 1;

    if (denominator == 0) {
      return remaining / months;
    }

    return remaining *
        monthlyRate /
        denominator;
  }

  // ============================================================
  // PROJECTED VALUE
  // ============================================================

  double _calculateProjectedValue(
    GoalModel goal,
    double monthlyInvestment,
  ) {
    final months = math.max(
      1,
      (goal.daysRemaining / 30.4375).ceil(),
    );

    final monthlyRate =
        _expectedReturn / 100 / 12;

    if (monthlyRate <= 0) {
      return goal.currentAmount +
          monthlyInvestment * months;
    }

    final growthFactor = math.pow(
      1 + monthlyRate,
      months,
    );

    final futureContributions =
        monthlyInvestment *
            ((growthFactor - 1) / monthlyRate);

    return goal.currentAmount +
        futureContributions;
  }

  // ============================================================
  // RECOMMENDED INVESTMENTS
  // ============================================================

  List<Map<String, dynamic>> _getRecommendations(
    GoalModel goal,
    double monthlyInvestment,
  ) {
    final days = goal.daysRemaining;

    // ----------------------------------------------------------
    // SHORT TERM
    // ----------------------------------------------------------

    if (days <= 365) {
      if (_riskProfile == 'Low') {
        return [
          {
            'name': 'Fixed Deposit',
            'subtitle':
                'Lower-volatility option for short-term goals',
            'percent': 60.0,
            'icon': Icons.account_balance_rounded,
          },
          {
            'name': 'Emergency Fund / Savings',
            'subtitle':
                'Keep goal money accessible and stable',
            'percent': 30.0,
            'icon': Icons.savings_rounded,
          },
          {
            'name': 'Gold',
            'subtitle':
                'Small diversification allocation',
            'percent': 10.0,
            'icon': Icons.workspace_premium_rounded,
          },
        ];
      }

      if (_riskProfile == 'Moderate') {
        return [
          {
            'name': 'Fixed Deposit',
            'subtitle':
                'Stability for the near-term goal',
            'percent': 50.0,
            'icon': Icons.account_balance_rounded,
          },
          {
            'name': 'Mutual Fund',
            'subtitle':
                'Diversified growth-oriented allocation',
            'percent': 35.0,
            'icon': Icons.auto_graph_rounded,
          },
          {
            'name': 'Gold',
            'subtitle':
                'Portfolio diversification',
            'percent': 15.0,
            'icon': Icons.workspace_premium_rounded,
          },
        ];
      }

      return [
        {
          'name': 'Fixed Deposit',
          'subtitle':
              'Stable base for the short-term goal',
          'percent': 40.0,
          'icon': Icons.account_balance_rounded,
        },
        {
          'name': 'Index Fund',
          'subtitle':
              'Higher-growth diversified allocation',
          'percent': 45.0,
          'icon': Icons.show_chart_rounded,
        },
        {
          'name': 'Gold',
          'subtitle':
              'Diversification allocation',
          'percent': 15.0,
          'icon': Icons.workspace_premium_rounded,
        },
      ];
    }

    // ----------------------------------------------------------
    // MEDIUM TERM
    // ----------------------------------------------------------

    if (days <= 1095) {
      if (_riskProfile == 'Low') {
        return [
          {
            'name': 'Fixed Deposit',
            'subtitle':
                'Stability-focused allocation',
            'percent': 50.0,
            'icon': Icons.account_balance_rounded,
          },
          {
            'name': 'PPF',
            'subtitle':
                'Longer-term savings component',
            'percent': 25.0,
            'icon': Icons.lock_clock_rounded,
          },
          {
            'name': 'Gold',
            'subtitle':
                'Diversification',
            'percent': 25.0,
            'icon': Icons.workspace_premium_rounded,
          },
        ];
      }

      if (_riskProfile == 'Moderate') {
        return [
          {
            'name': 'Fixed Deposit',
            'subtitle':
                'Stable portion of the plan',
            'percent': 30.0,
            'icon': Icons.account_balance_rounded,
          },
          {
            'name': 'Mutual Fund',
            'subtitle':
                'Diversified growth allocation',
            'percent': 50.0,
            'icon': Icons.auto_graph_rounded,
          },
          {
            'name': 'Gold',
            'subtitle':
                'Diversification',
            'percent': 20.0,
            'icon': Icons.workspace_premium_rounded,
          },
        ];
      }

      return [
        {
          'name': 'Fixed Deposit',
          'subtitle':
              'Stability component',
          'percent': 20.0,
          'icon': Icons.account_balance_rounded,
        },
        {
          'name': 'Index Fund',
          'subtitle':
              'Diversified growth allocation',
          'percent': 60.0,
          'icon': Icons.show_chart_rounded,
        },
        {
          'name': 'Gold',
          'subtitle':
              'Diversification',
          'percent': 20.0,
          'icon': Icons.workspace_premium_rounded,
        },
      ];
    }

    // ----------------------------------------------------------
    // LONG TERM
    // ----------------------------------------------------------

    if (_riskProfile == 'Low') {
      return [
        {
          'name': 'Fixed Deposit',
          'subtitle':
              'Lower-volatility core allocation',
          'percent': 45.0,
          'icon': Icons.account_balance_rounded,
        },
        {
          'name': 'PPF',
          'subtitle':
              'Long-term savings component',
          'percent': 30.0,
          'icon': Icons.lock_clock_rounded,
        },
        {
          'name': 'Gold',
          'subtitle':
              'Diversification',
          'percent': 25.0,
          'icon': Icons.workspace_premium_rounded,
        },
      ];
    }

    if (_riskProfile == 'Moderate') {
      return [
        {
          'name': 'Fixed Deposit',
          'subtitle':
              'Stable allocation',
          'percent': 20.0,
          'icon': Icons.account_balance_rounded,
        },
        {
          'name': 'Index Fund',
          'subtitle':
              'Diversified long-term growth',
          'percent': 60.0,
          'icon': Icons.show_chart_rounded,
        },
        {
          'name': 'Gold',
          'subtitle':
              'Portfolio diversification',
          'percent': 20.0,
          'icon': Icons.workspace_premium_rounded,
        },
      ];
    }

    return [
      {
        'name': 'Fixed Deposit',
        'subtitle':
            'Stability component',
        'percent': 20.0,
        'icon': Icons.account_balance_rounded,
      },
      {
        'name': 'Index Fund',
        'subtitle':
            'Diversified long-term growth',
        'percent': 60.0,
        'icon': Icons.show_chart_rounded,
      },
      {
        'name': 'Mutual Fund',
        'subtitle':
            'Growth-oriented diversification',
        'percent': 20.0,
        'icon': Icons.auto_graph_rounded,
      },
    ];
  }

  // ============================================================
  // GOAL-SPECIFIC TIPS
  // ============================================================

  List<String> _getTips(
    GoalModel goal,
    double monthlyInvestment,
  ) {
    final tips = <String>[];

    final days = goal.daysRemaining;

    if (goal.remainingAmount <= 0) {
      tips.add(
        'Your goal is already fully funded. Consider keeping future contributions for another goal.',
      );
    } else if (days <= 180) {
      tips.add(
        'Your goal is less than 6 months away. Prioritize stability and liquidity over aggressive growth.',
      );
    } else if (days <= 365) {
      tips.add(
        'Your goal is within one year, so avoid relying heavily on volatile assets for money you need soon.',
      );
    } else if (days <= 1095) {
      tips.add(
        'Your medium-term horizon allows a balanced approach between stability and growth.',
      );
    } else {
      tips.add(
        'Your longer time horizon gives you more room to consider diversified growth investments.',
      );
    }

    if (_riskProfile == 'Low') {
      tips.add(
        'Low risk selected: FinPilot emphasizes capital stability and lower-volatility categories.',
      );
    } else if (_riskProfile == 'Moderate') {
      tips.add(
        'Moderate risk selected: FinPilot balances stability with diversified growth.',
      );
    } else {
      tips.add(
        'High risk selected: higher-growth allocations can fluctuate more and may not suit short-term goals.',
      );
    }

    if (monthlyInvestment > 0) {
      tips.add(
        'Target approximately ${CurrencyFormatter.format(monthlyInvestment)} per month toward this goal.',
      );
    }

    if (goal.category.toLowerCase().contains('emergency')) {
      tips.add(
        'For an emergency fund, accessibility and stability are generally more important than chasing high returns.',
      );
    }

    if (goal.category.toLowerCase().contains('gadget') ||
        goal.title.toLowerCase().contains('laptop')) {
      tips.add(
        'For a laptop or gadget goal, protect the money as the purchase date gets closer.',
      );
    }

    return tips.take(4).toList();
  }

  // ============================================================
  // RISK DESCRIPTION
  // ============================================================

  String _riskDescription() {
    switch (_riskProfile) {
      case 'Low':
        return 'Focuses on stability and lower volatility.';
      case 'High':
        return 'Accepts greater volatility for higher growth potential.';
      default:
        return 'Balances stability with long-term growth potential.';
    }
  }

  // ============================================================
  // RISK COLOR
  // ============================================================

  Color _riskColor() {
    switch (_riskProfile) {
      case 'Low':
        return AppColors.successGreen;
      case 'High':
        return AppColors.dangerRed;
      default:
        return AppColors.warningOrange;
    }
  }

  // ============================================================
  // PORTFOLIO SUMMARY
  // ============================================================

  Widget _buildPortfolioSummary(
    InvestmentProvider provider,
  ) {
    final investedTotal =
        provider.totalInvestedAmount;

    final valueTotal =
        provider.totalCurrentValue;

    final returnsTotal =
        provider.totalReturns;

    final returnPctTotal =
        provider.totalReturnPercentage;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 12,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              AppColors.secondaryBackground,
              AppColors.cardBackground,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(
            AppConstants.cardRadius,
          ),
          border: Border.all(
            color: Colors.white.withValues(
              alpha: 0.05,
            ),
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PORTFOLIO VALUE',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      CurrencyFormatter.format(
                        valueTotal,
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'TOTAL RETURNS',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          returnsTotal >= 0
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded,
                          color: returnsTotal >= 0
                              ? AppColors.successGreen
                              : AppColors.dangerRed,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${returnsTotal >= 0 ? '+' : ''}${CurrencyFormatter.format(returnsTotal)}',
                          style: TextStyle(
                            color: returnsTotal >= 0
                                ? AppColors.successGreen
                                : AppColors.dangerRed,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${returnsTotal >= 0 ? '+' : ''}${returnPctTotal.toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: returnsTotal >= 0
                            ? AppColors.successGreen
                            : AppColors.dangerRed,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(
              height: 32,
              color: Colors.white10,
            ),
            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Invested:',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                Text(
                  CurrencyFormatter.format(
                    investedTotal,
                  ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
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
  // INVESTMENT PLANNER
  // ============================================================

  Widget _buildInvestmentPlanner(
    List<GoalModel> goals,
  ) {
    if (goals.isEmpty) {
      return _buildNoGoalsCard();
    }

    final goal = _getSelectedGoal(goals);

    if (goal == null) {
      return _buildNoGoalsCard();
    }

    final monthlyInvestment =
        _calculateRequiredMonthly(goal);

    final projectedValue =
        _calculateProjectedValue(
      goal,
      monthlyInvestment,
    );

    final recommendations =
        _getRecommendations(
      goal,
      monthlyInvestment,
    );

    final tips = _getTips(
      goal,
      monthlyInvestment,
    );

    final progress =
        goal.progressPercentage;

    final riskColor = _riskColor();

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 8,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF5B4BFF)
                  .withValues(alpha: 0.14),
              AppColors.cyan
                  .withValues(alpha: 0.06),
              AppColors.cardBackground,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: const Color(0xFF6C5CE7)
                .withValues(alpha: 0.20),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF5B4BFF)
                  .withValues(alpha: 0.08),
              blurRadius: 25,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            // --------------------------------------------------
            // HEADER
            // --------------------------------------------------

            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF6C5CE7),
                        AppColors.cyan,
                      ],
                    ),
                    borderRadius:
                        BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FINPILOT INVESTMENT PLANNER',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.4,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Goal-based educational investment guidance',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // --------------------------------------------------
            // SELECT GOAL
            // --------------------------------------------------

            const Text(
              'SELECT YOUR GOAL',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),

            const SizedBox(height: 7),

            DropdownButtonFormField<String>(
              initialValue: goals.any(
                (g) => g.id == _selectedGoalId,
              )
                  ? _selectedGoalId
                  : goals.first.id,
              dropdownColor:
                  AppColors.secondaryBackground,
              decoration: InputDecoration(
                filled: true,
                fillColor:
                    Colors.white.withValues(alpha: 0.04),
                prefixIcon: const Icon(
                  Icons.flag_rounded,
                  color: AppColors.cyan,
                  size: 19,
                ),
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(13),
                  borderSide: BorderSide(
                    color: Colors.white
                        .withValues(alpha: 0.08),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(13),
                  borderSide: BorderSide(
                    color: Colors.white
                        .withValues(alpha: 0.08),
                  ),
                ),
              ),
              items: goals.map((goalItem) {
                return DropdownMenuItem<String>(
                  value: goalItem.id,
                  child: Text(
                    goalItem.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                );
              }).toList(),
              onChanged: _selectGoal,
            ),

            const SizedBox(height: 15),

            // --------------------------------------------------
            // GOAL SNAPSHOT
            // --------------------------------------------------

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black
                    .withValues(alpha: 0.12),
                borderRadius:
                    BorderRadius.circular(15),
                border: Border.all(
                  color: Colors.white
                      .withValues(alpha: 0.05),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      _miniGoalStat(
                        'TARGET',
                        CurrencyFormatter.format(
                          goal.targetAmount,
                        ),
                      ),
                      _miniGoalStat(
                        'CURRENT',
                        CurrencyFormatter.format(
                          goal.currentAmount,
                        ),
                      ),
                      _miniGoalStat(
                        'REMAINING',
                        CurrencyFormatter.format(
                          goal.remainingAmount,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 13),
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        color: AppColors.cyan,
                        size: 15,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${goal.daysRemaining} days remaining',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${(progress * 100).toStringAsFixed(0)}% complete',
                        style: const TextStyle(
                          color: AppColors.cyan,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius:
                        BorderRadius.circular(20),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor:
                          Colors.white.withValues(
                        alpha: 0.06,
                      ),
                      valueColor:
                          const AlwaysStoppedAnimation(
                        AppColors.cyan,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // --------------------------------------------------
            // RISK PROFILE
            // --------------------------------------------------

            const Text(
              'RISK PROFILE',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: _riskButton('Low'),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: _riskButton('Moderate'),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: _riskButton('High'),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Text(
              _riskDescription(),
              style: TextStyle(
                color: riskColor,
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 18),

            // --------------------------------------------------
            // RETURN RATE
            // --------------------------------------------------

            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'ILLUSTRATIVE ANNUAL RETURN',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.7,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.cyan
                        .withValues(alpha: 0.10),
                    borderRadius:
                        BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_expectedReturn.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      color: AppColors.cyan,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            Slider(
              value: _expectedReturn,
              min: 4,
              max: 15,
              divisions: 22,
              activeColor: AppColors.cyan,
              inactiveColor:
                  Colors.white.withValues(alpha: 0.08),
              onChanged: (value) {
                setState(() {
                  _expectedReturn = value;
                });
              },
            ),

            const Text(
              'Illustrative assumption only. Actual returns can be higher or lower.',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 8,
              ),
            ),

            const SizedBox(height: 18),

            // --------------------------------------------------
            // MONTHLY INVESTMENT RESULT
            // --------------------------------------------------

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.cyan
                        .withValues(alpha: 0.11),
                    const Color(0xFF6C5CE7)
                        .withValues(alpha: 0.08),
                  ],
                ),
                borderRadius:
                    BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.cyan
                      .withValues(alpha: 0.16),
                ),
              ),
              child: Column(
                children: [
                  const Text(
                    'ESTIMATED MONTHLY INVESTMENT',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    CurrencyFormatter.format(
                      monthlyInvestment,
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'per month to target ${goal.title}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // --------------------------------------------------
            // PROJECTED VALUE
            // --------------------------------------------------

            Row(
              children: [
                Expanded(
                  child: _resultBox(
                    icon: Icons.trending_up_rounded,
                    label: 'PROJECTED VALUE',
                    value: CurrencyFormatter.format(
                      projectedValue,
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: _resultBox(
                    icon: Icons.flag_rounded,
                    label: 'GOAL TARGET',
                    value: CurrencyFormatter.format(
                      goal.targetAmount,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // --------------------------------------------------
            // WHERE TO INVEST
            // --------------------------------------------------

            const Row(
              children: [
                Icon(
                  Icons.account_balance_wallet_rounded,
                  color: AppColors.cyan,
                  size: 18,
                ),
                SizedBox(width: 8),
                Text(
                  'WHERE TO INVEST',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 5),

            const Text(
              'Suggested educational allocation based on your goal horizon and selected risk.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 9,
              ),
            ),

            const SizedBox(height: 11),

            ...recommendations.map(
              (item) {
                final percent =
                    item['percent'] as double;

                final monthlyAmount =
                    monthlyInvestment *
                        percent /
                        100;

                return _recommendationCard(
                  name: item['name'] as String,
                  subtitle:
                      item['subtitle'] as String,
                  percent: percent,
                  monthlyAmount: monthlyAmount,
                  icon: item['icon'] as IconData,
                );
              },
            ),

            const SizedBox(height: 12),

            // --------------------------------------------------
            // WHY THIS PLAN
            // --------------------------------------------------

            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFF6C5CE7)
                    .withValues(alpha: 0.08),
                borderRadius:
                    BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF6C5CE7)
                      .withValues(alpha: 0.14),
                ),
              ),
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.psychology_rounded,
                    color: AppColors.cyan,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _whyThisPlan(goal),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // --------------------------------------------------
            // FINPILOT TIPS
            // --------------------------------------------------

            const Row(
              children: [
                Icon(
                  Icons.lightbulb_rounded,
                  color: AppColors.warningOrange,
                  size: 18,
                ),
                SizedBox(width: 8),
                Text(
                  'FINPILOT TIPS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 9),

            ...tips.map(
              (tip) => Padding(
                padding:
                    const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding:
                          EdgeInsets.only(top: 4),
                      child: Icon(
                        Icons.circle,
                        color: AppColors.cyan,
                        size: 5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tip,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // NO GOALS CARD
  // ============================================================

  Widget _buildNoGoalsCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 8,
      ),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white
                .withValues(alpha: 0.06),
          ),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.flag_outlined,
              color: AppColors.cyan,
              size: 25,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create a financial goal first',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'FinPilot will use your goal amount and deadline to build an educational investment plan.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 9,
                      height: 1.4,
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
  // MINI GOAL STAT
  // ============================================================

  Widget _miniGoalStat(
    String label,
    String value,
  ) {
    return Expanded(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // RISK BUTTON
  // ============================================================

  Widget _riskButton(String risk) {
    final selected = _riskProfile == risk;

    Color color;

    switch (risk) {
      case 'Low':
        color = AppColors.successGreen;
        break;
      case 'High':
        color = AppColors.dangerRed;
        break;
      default:
        color = AppColors.warningOrange;
    }

    return GestureDetector(
      onTap: () => _setRisk(risk),
      child: AnimatedContainer(
        duration:
            const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          vertical: 10,
          horizontal: 5,
        ),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.14)
              : Colors.white
                  .withValues(alpha: 0.025),
          borderRadius:
              BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.65)
                : Colors.white
                    .withValues(alpha: 0.06),
          ),
        ),
        child: Center(
          child: Text(
            risk,
            style: TextStyle(
              color: selected
                  ? color
                  : AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // RESULT BOX
  // ============================================================

  Widget _resultBox({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white
            .withValues(alpha: 0.025),
        borderRadius:
            BorderRadius.circular(13),
        border: Border.all(
          color: Colors.white
              .withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: AppColors.cyan,
            size: 17,
          ),
          const SizedBox(height: 7),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // RECOMMENDATION CARD
  // ============================================================

  Widget _recommendationCard({
    required String name,
    required String subtitle,
    required double percent,
    required double monthlyAmount,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(
        bottom: 9,
      ),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white
            .withValues(alpha: 0.035),
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white
              .withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: AppColors.cyan
                  .withValues(alpha: 0.10),
              borderRadius:
                  BorderRadius.circular(11),
            ),
            child: Icon(
              icon,
              color: AppColors.cyan,
              size: 19,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 9,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment:
                CrossAxisAlignment.end,
            children: [
              Text(
                '${percent.toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: AppColors.cyan,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                CurrencyFormatter.format(
                  monthlyAmount,
                ),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
              const Text(
                '/ month',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // WHY THIS PLAN
  // ============================================================

  String _whyThisPlan(GoalModel goal) {
    if (goal.daysRemaining <= 365) {
      return 'FinPilot is prioritizing stability because ${goal.title} is a near-term goal. The plan limits dependence on higher-volatility investments.';
    }

    if (goal.daysRemaining <= 1095) {
      return 'FinPilot is using a balanced allocation because ${goal.title} has a medium-term horizon. The plan combines stability with diversified growth.';
    }

    return 'FinPilot is allowing a greater growth allocation because ${goal.title} has a longer time horizon. The selected risk level determines how aggressive the allocation becomes.';
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final investmentProvider =
        context.watch<InvestmentProvider>();

    final goalProvider =
        context.watch<GoalProvider>();

    final investments =
        investmentProvider.investments;

    final goals =
        goalProvider.goals;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Investment Planner',
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),

      // ========================================================
      // MAIN BODY
      // ========================================================

      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(
            top: 2,
            bottom: 20,
          ),
          children: [
            // ----------------------------------------------------
            // PORTFOLIO
            // ----------------------------------------------------

            _buildPortfolioSummary(
              investmentProvider,
            ),

            // ----------------------------------------------------
            // AI PLANNER
            // ----------------------------------------------------

            _buildInvestmentPlanner(
              goals,
            ),

            const SizedBox(height: 6),

            // ----------------------------------------------------
            // INVESTMENT LOGS
            // ----------------------------------------------------

            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 8,
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'YOUR INVESTMENTS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Track your existing assets',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (investments.isNotEmpty)
                    IconButton(
                      onPressed:
                          _showAddInvestmentDialog,
                      icon: const Icon(
                        Icons.add_circle_outline_rounded,
                        color: AppColors.cyan,
                      ),
                    ),
                ],
              ),
            ),

            if (investments.isEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 20,
                ),
                child: EmptyState(
                  icon: Icons.trending_up_rounded,
                  title: 'No Investments Logged',
                  description:
                      'Track your gold, FDs, mutual funds, index funds, PPF, or other assets here.',
                  buttonText:
                      'Add Investment',
                  onButtonTap:
                      _showAddInvestmentDialog,
                ),
              )
            else
              Padding(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 20,
                ),
                child: Column(
                  children: investments.map(
                    (asset) {
                      final gain =
                          asset.totalReturns;

                      final gainPct =
                          asset.returnPercentage;

                      return Container(
                        margin:
                            const EdgeInsets.only(
                          bottom: 12,
                        ),
                        child: Dismissible(
                          key: Key(asset.id),
                          direction:
                              DismissDirection
                                  .endToStart,
                          background: Container(
                            alignment:
                                Alignment.centerRight,
                            padding:
                                const EdgeInsets.only(
                              right: 20,
                            ),
                            decoration:
                                BoxDecoration(
                              color: AppColors
                                  .dangerRed
                                  .withValues(
                                alpha: 0.15,
                              ),
                              borderRadius:
                                  BorderRadius.circular(
                                AppConstants.cardRadius,
                              ),
                            ),
                            child: const Icon(
                              Icons.delete_outline_rounded,
                              color: AppColors.dangerRed,
                              size: 28,
                            ),
                          ),
                          onDismissed:
                              (direction) async {
                            await investmentProvider
                                .deleteInvestment(
                              asset.id,
                            );
                          },
                          child: GlassCard(
                            padding:
                                const EdgeInsets
                                    .symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment
                                      .spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Container(
                                        padding:
                                            const EdgeInsets
                                                .all(
                                          8,
                                        ),
                                        decoration:
                                            BoxDecoration(
                                          color: AppColors
                                              .cyan
                                              .withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius:
                                              BorderRadius
                                                  .circular(
                                            12,
                                          ),
                                        ),
                                        child:
                                            const Icon(
                                          Icons
                                              .show_chart_rounded,
                                          color:
                                              AppColors.cyan,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(
                                        width: 12,
                                      ),
                                      Expanded(
                                        child:
                                            Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment
                                                  .start,
                                          children: [
                                            Text(
                                              asset.name,
                                              style:
                                                  const TextStyle(
                                                fontWeight:
                                                    FontWeight
                                                        .bold,
                                                fontSize:
                                                    14,
                                                color: Colors
                                                    .white,
                                              ),
                                              maxLines:
                                                  1,
                                              overflow:
                                                  TextOverflow
                                                      .ellipsis,
                                            ),
                                            Text(
                                              'Type: ${asset.type}',
                                              style:
                                                  const TextStyle(
                                                fontSize:
                                                    11,
                                                color: AppColors
                                                    .textSecondary,
                                              ),
                                            ),
                                            const SizedBox(
                                              height: 4,
                                            ),
                                            Text(
                                              'Cost: ${CurrencyFormatter.format(asset.investedAmount)}',
                                              style:
                                                  const TextStyle(
                                                fontSize:
                                                    10,
                                                color: AppColors
                                                    .textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(
                                  width: 8,
                                ),
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment
                                          .end,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          CurrencyFormatter
                                              .format(
                                            asset
                                                .currentValue,
                                          ),
                                          style:
                                              const TextStyle(
                                            fontWeight:
                                                FontWeight
                                                    .bold,
                                            fontSize:
                                                14,
                                            color: Colors
                                                .white,
                                          ),
                                        ),
                                        const SizedBox(
                                          width: 4,
                                        ),
                                        IconButton(
                                          icon:
                                              const Icon(
                                            Icons
                                                .update_rounded,
                                            color:
                                                AppColors
                                                    .cyan,
                                            size: 16,
                                          ),
                                          onPressed:
                                              () =>
                                                  _showUpdateValueDialog(
                                            asset,
                                          ),
                                          constraints:
                                              const BoxConstraints(),
                                          padding:
                                              EdgeInsets
                                                  .zero,
                                        ),
                                      ],
                                    ),
                                    Text(
                                      '${gain >= 0 ? '+' : ''}${gainPct.toStringAsFixed(1)}%',
                                      style: TextStyle(
                                        color: gain >= 0
                                            ? AppColors
                                                .successGreen
                                            : AppColors
                                                .dangerRed,
                                        fontSize: 11,
                                        fontWeight:
                                            FontWeight
                                                .bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ).toList(),
                ),
              ),

            // ----------------------------------------------------
            // ADD INVESTMENT BUTTON
            // ----------------------------------------------------

            Padding(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 8,
              ),
              child: GradientButton(
                text: 'Add Investment Asset',
                onTap:
                    _showAddInvestmentDialog,
                height: 48,
              ),
            ),

            // ----------------------------------------------------
            // DISCLAIMER
            // ----------------------------------------------------

            Padding(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 4,
              ),
              child: Container(
                padding:
                    const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warningOrange
                      .withValues(alpha: 0.08),
                  borderRadius:
                      BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.warningOrange
                        .withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color:
                          AppColors.warningOrange,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Disclaimer: FinPilot provides educational investment guidance only. The return rates and allocations shown are illustrative and are not professional financial advice. Actual investment returns can vary and investments can lose value. Always perform your own research.',
                        style: TextStyle(
                          color: AppColors
                              .warningOrange
                              .withValues(
                            alpha: 0.9,
                          ),
                          fontSize: 10,
                          height: 1.4,
                          fontWeight:
                              FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}