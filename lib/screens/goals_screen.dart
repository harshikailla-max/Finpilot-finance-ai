import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/goal_model.dart';
import '../providers/goal_provider.dart';
import '../utils/constants.dart';
import '../utils/currency_formatter.dart';
import '../widgets/empty_state.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_button.dart';
import 'goal_details_screen.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final _goalTitleController = TextEditingController();
  final _goalTargetController = TextEditingController();
  final _addMoneyController = TextEditingController();

  String _selectedGoalCategory = 'Emergency Fund';
  DateTime _selectedGoalDeadline = DateTime.now().add(const Duration(days: 365));

  @override
  void dispose() {
    _goalTitleController.dispose();
    _goalTargetController.dispose();
    _addMoneyController.dispose();
    super.dispose();
  }


  void _showAddGoalDialog() {
    _goalTitleController.clear();
    _goalTargetController.clear();
    _selectedGoalCategory = 'Emergency Fund';
    _selectedGoalDeadline = DateTime.now().add(const Duration(days: 365));

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.secondaryBackground,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text('New Savings Goal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Goal Name', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _goalTitleController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(hintText: 'e.g. Dream House, Macbook Pro'),
                    ),
                    const SizedBox(height: 16),

                    const Text('Target Amount', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _goalTargetController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: '₹0',
                        prefixIcon: Icon(Icons.currency_rupee, color: AppColors.textMuted, size: 18),
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text('Category', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _selectedGoalCategory,
                      dropdownColor: AppColors.cardBackground,
                      decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12)),
                      items: AppConstants.goalCategories.map((cat) {
                        return DropdownMenuItem(value: cat, child: Text(cat));
                      }).toList(),
                      onChanged: (val) {
                        setDialogState(() {
                          _selectedGoalCategory = val!;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    const Text('Deadline', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedGoalDeadline,
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2040),
                        );
                        if (picked != null) {
                          setDialogState(() {
                            _selectedGoalDeadline = picked;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryBackground,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${_selectedGoalDeadline.day}/${_selectedGoalDeadline.month}/${_selectedGoalDeadline.year}',
                              style: const TextStyle(color: Colors.white),
                            ),
                            const Icon(Icons.calendar_today_rounded, color: AppColors.textMuted, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                ),
                TextButton(
                  onPressed: () async {
                    final title = _goalTitleController.text.trim();
                    final amt = double.tryParse(_goalTargetController.text.trim());
                    if (title.isNotEmpty && amt != null && amt > 0) {
                      final uuid = const Uuid();
                      final goal = GoalModel(
                        id: uuid.v4(),
                        title: title,
                        targetAmount: amt,
                        currentAmount: 0.0,
                        deadline: _selectedGoalDeadline,
                        category: _selectedGoalCategory,
                        createdAt: DateTime.now(),
                      );
                      await context.read<GoalProvider>().addGoal(goal);
                      if (mounted) Navigator.pop(context);
                    }
                  },
                  child: const Text('Create', style: TextStyle(color: AppColors.cyan, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddMoneyDialog(GoalModel goal) {
    _addMoneyController.clear();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.secondaryBackground,
          title: Text('Fund "${goal.title}"', style: const TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add savings to this goal. Target remaining: ${CurrencyFormatter.format(goal.remainingAmount)}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _addMoneyController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Enter contribution',
                  prefixIcon: Icon(Icons.currency_rupee, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () async {
                final amt = double.tryParse(_addMoneyController.text.trim());
                if (amt != null && amt > 0) {
                  await context.read<GoalProvider>().addMoneyToGoal(goal.id, amt);
                  if (mounted) Navigator.pop(context);
                }
              },
              child: const Text('Add Money', style: TextStyle(color: AppColors.successGreen, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final goalProvider = context.watch<GoalProvider>();
    final goals = goalProvider.goals;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Savings Goals'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: goals.isEmpty
            ? EmptyState(
                icon: Icons.flag_rounded,
                title: 'No Goals Set',
                description: 'Setting a savings goal keeps you motivated and tracks progress.',
                buttonText: 'Create Goal',
                onButtonTap: _showAddGoalDialog,
              )
            : Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(20.0),
                      itemCount: goals.length,
                      itemBuilder: (context, index) {
                        final goal = goals[index];
                        final pct = goal.progressPercentage;
                        final days = goal.daysRemaining;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => GoalDetailsScreen(goal: goal),
                                ),
                              );
                            },
                            child: Dismissible(
                              key: Key(goal.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                decoration: BoxDecoration(
                                  color: AppColors.dangerRed.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(AppConstants.cardRadius),
                                ),
                                child: const Icon(Icons.delete_outline_rounded, color: AppColors.dangerRed, size: 28),
                              ),
                              onDismissed: (direction) async {
                                await goalProvider.deleteGoal(goal.id);
                              },
                              child: GlassCard(
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
                                                color: AppColors.successGreen.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Icon(
                                                _getGoalIcon(goal.category),
                                                color: AppColors.successGreen,
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  goal.title,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                                                ),
                                                Text(
                                                  goal.category,
                                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.cyan, size: 24),
                                          onPressed: () => _showAddMoneyDialog(goal),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '${CurrencyFormatter.format(goal.currentAmount)} / ${CurrencyFormatter.format(goal.targetAmount)}',
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                        Text(
                                          '${(pct * 100).toStringAsFixed(0)}%',
                                          style: const TextStyle(color: AppColors.successGreen, fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: pct,
                                        backgroundColor: AppColors.secondaryBackground,
                                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.successGreen),
                                        minHeight: 6,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Remaining: ${CurrencyFormatter.format(goal.remainingAmount)}',
                                          style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.8), fontSize: 11),
                                        ),
                                        Text(
                                          days > 0 ? '$days days left' : 'Due today',
                                          style: const TextStyle(color: AppColors.warningOrange, fontSize: 11, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: GradientButton(
                      text: 'Create New Goal',
                      onTap: _showAddGoalDialog,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  IconData _getGoalIcon(String category) {
    switch (category) {
      case 'Emergency Fund':
        return Icons.security_rounded;
      case 'Travel':
        return Icons.flight_takeoff_rounded;
      case 'Education':
        return Icons.school_rounded;
      case 'Vehicle':
        return Icons.directions_car_rounded;
      case 'House':
        return Icons.home_rounded;
      case 'Gadgets':
        return Icons.laptop_mac_rounded;
      case 'Investment':
        return Icons.trending_up_rounded;
      default:
        return Icons.flag_rounded;
    }
  }
}
