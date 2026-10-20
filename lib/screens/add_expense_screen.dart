import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/finance_transaction.dart';
import '../providers/finance_provider.dart';
import '../providers/budget_provider.dart';
import '../services/category_service.dart';
import '../utils/constants.dart';
import '../utils/currency_formatter.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_button.dart';

class AddExpenseScreen extends StatefulWidget {
  final FinanceTransaction? editTransaction;
  const AddExpenseScreen({super.key, this.editTransaction});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _merchantController = TextEditingController();
  final _noteController = TextEditingController();

  String _selectedCategory = 'Food';
  String _selectedPaymentMethod = 'UPI';
  DateTime _selectedDate = DateTime.now();
  bool _isRecurring = false;
  bool _isAutoCategoryDetected = false;

  final List<double> _quickAmounts = [100, 500, 1000, 2000, 5000];

  @override
  void initState() {
    super.initState();
    if (widget.editTransaction != null) {
      final tx = widget.editTransaction!;
      _nameController.text = tx.title;
      _amountController.text = tx.amount.toStringAsFixed(0);
      _merchantController.text = tx.merchant;
      _noteController.text = tx.note;
      _selectedCategory = tx.category;
      _selectedPaymentMethod = tx.paymentMethod;
      _selectedDate = tx.date;
      _isRecurring = tx.isRecurring;
    }

    // Listener for smart auto-categorization
    _nameController.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    _amountController.dispose();
    _merchantController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _onNameChanged() {
    final text = _nameController.text;
    if (text.isNotEmpty) {
      final detected = CategoryService.detectExpenseCategory(text);
      if (detected != 'Other' && detected != _selectedCategory) {
        setState(() {
          _selectedCategory = detected;
          _isAutoCategoryDetected = true;
        });
      }
    }
  }

  void _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primaryPurple,
              onPrimary: Colors.white,
              surface: AppColors.cardBackground,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _saveExpense() async {
    if (_formKey.currentState!.validate()) {
      final financeProvider = context.read<FinanceProvider>();
      final uuid = const Uuid();

      final title = _nameController.text.trim();
      final amount = double.parse(_amountController.text.trim());
      final merchant = _merchantController.text.trim();
      final note = _noteController.text.trim();

      final tx = FinanceTransaction(
        id: widget.editTransaction?.id ?? uuid.v4(),
        title: title,
        amount: amount,
        category: _selectedCategory,
        type: TransactionType.expense,
        date: _selectedDate,
        paymentMethod: _selectedPaymentMethod,
        merchant: merchant,
        note: note,
        isRecurring: _isRecurring,
        createdAt: widget.editTransaction?.createdAt ?? DateTime.now(),
      );

      if (widget.editTransaction != null) {
        await financeProvider.updateTransaction(tx);
      } else {
        await financeProvider.addTransaction(tx);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                widget.editTransaction != null
                    ? 'Expense updated successfully!'
                    : 'Expense saved successfully!',
              ),
            ],
          ),
          backgroundColor: AppColors.successGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );

      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final financeProvider = context.watch<FinanceProvider>();
    final budgetProvider = context.watch<BudgetProvider>();

    // Dynamic calculations for Budget Impact
    final double enteredAmount = double.tryParse(_amountController.text) ?? 0.0;
    final double categoryLimit = budgetProvider.categorySpentLimit(
      _selectedCategory,
    );
    final double currentSpent =
        financeProvider.monthlyCategorySpent[_selectedCategory] ?? 0.0;
    final double projectedSpent = currentSpent + enteredAmount;
    final double remainingBudgetAfter = categoryLimit - projectedSpent;

    final bool isBudgetExceeded =
        categoryLimit > 0 && projectedSpent > categoryLimit;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.editTransaction != null ? 'Edit Expense' : 'Add Expense',
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Background Glow
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.dangerRed.withValues(alpha: 0.1),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Glass Card Container
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Amount Input
                          const Text(
                            'Amount',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            decoration: InputDecoration(
                              hintText: '₹0',
                              hintStyle: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                              prefixIcon: const Icon(
                                Icons.currency_rupee,
                                size: 28,
                                color: Colors.white,
                              ),
                              fillColor: AppColors.secondaryBackground,
                            ),
                            onChanged: (val) {
                              setState(
                                () {},
                              ); // Rebuild to update budget impact
                            },
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter an amount';
                              }
                              final amt = double.tryParse(value);
                              if (amt == null || amt <= 0) {
                                return 'Please enter a valid positive number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Quick Chips
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: _quickAmounts.map((amt) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: ActionChip(
                                    label: Text('+₹${amt.toStringAsFixed(0)}'),
                                    backgroundColor:
                                        AppColors.secondaryBackground,

                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    onPressed: () {
                                      final current =
                                          double.tryParse(
                                            _amountController.text,
                                          ) ??
                                          0.0;
                                      setState(() {
                                        _amountController.text = (current + amt)
                                            .toStringAsFixed(0);
                                      });
                                    },
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Expense Name Input
                          const Text(
                            'Expense Title',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _nameController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: 'e.g. Swiggy Lunch',
                              prefixIcon: Icon(
                                Icons.title_rounded,
                                color: AppColors.textMuted,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter an expense name';
                              }
                              return null;
                            },
                          ),

                          // Auto category badge info
                          if (_isAutoCategoryDetected) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(
                                  Icons.auto_awesome_rounded,
                                  color: AppColors.cyan,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'AI auto-suggested category: $_selectedCategory',
                                  style: const TextStyle(
                                    color: AppColors.cyan,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 20),

                          // Category & Payment row
                          Row(
                            children: [
                              // Category
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Category',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    DropdownButtonFormField<String>(
                                      value: _selectedCategory,
                                      decoration: const InputDecoration(
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                      ),
                                      dropdownColor: AppColors.cardBackground,
                                      items: AppConstants.expenseCategories.map(
                                        (cat) {
                                          return DropdownMenuItem(
                                            value: cat,
                                            child: Text(cat),
                                          );
                                        },
                                      ).toList(),
                                      onChanged: (val) {
                                        setState(() {
                                          _selectedCategory = val!;
                                          _isAutoCategoryDetected = false;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Payment Method
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Payment Method',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    DropdownButtonFormField<String>(
                                      value: _selectedPaymentMethod,
                                      decoration: const InputDecoration(
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                      ),
                                      dropdownColor: AppColors.cardBackground,
                                      items: AppConstants.paymentMethods.map((
                                        pm,
                                      ) {
                                        return DropdownMenuItem(
                                          value: pm,
                                          child: Text(pm),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        setState(() {
                                          _selectedPaymentMethod = val!;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Date picker row
                          Row(
                            children: [
                              // Date Selection
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Transaction Date',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    InkWell(
                                      onTap: _selectDate,
                                      borderRadius: BorderRadius.circular(
                                        AppConstants.buttonRadius,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 16,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.secondaryBackground,
                                          borderRadius: BorderRadius.circular(
                                            AppConstants.buttonRadius,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                            const Icon(
                                              Icons.calendar_today_rounded,
                                              color: AppColors.textMuted,
                                              size: 18,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Recurring toggle
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Recurring Cost',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.secondaryBackground,
                                        borderRadius: BorderRadius.circular(
                                          AppConstants.buttonRadius,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'Monthly',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                            ),
                                          ),
                                          Switch(
                                            value: _isRecurring,
                                            activeColor:
                                                AppColors.primaryPurple,
                                            onChanged: (val) {
                                              setState(() {
                                                _isRecurring = val;
                                              });
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Merchant Name
                          const Text(
                            'Merchant Name (Optional)',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _merchantController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: 'e.g. Swiggy, Netflix, Amazon',
                              prefixIcon: Icon(
                                Icons.store_rounded,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Notes
                          const Text(
                            'Notes (Optional)',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _noteController,
                            maxLines: 2,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: 'Add additional details...',
                              prefixIcon: Icon(
                                Icons.notes_rounded,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Dynamic Budget Impact Analytics
                    if (categoryLimit > 0) ...[
                      const Text(
                        'BUDGET IMPACT FORECAST',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 12),
                      GlassCard(
                        color: isBudgetExceeded
                            ? AppColors.dangerRed.withValues(alpha: 0.08)
                            : AppColors.cardBackground,
                        border: Border.all(
                          color: isBudgetExceeded
                              ? AppColors.dangerRed.withValues(alpha: 0.3)
                              : Colors.white.withValues(alpha: 0.04),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '$_selectedCategory Limit:',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  CurrencyFormatter.format(categoryLimit),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Current Spent:',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  CurrencyFormatter.format(currentSpent),
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'After Expense:',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  CurrencyFormatter.format(projectedSpent),
                                  style: TextStyle(
                                    color: isBudgetExceeded
                                        ? AppColors.dangerRed
                                        : Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24, color: Colors.white10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Remaining Budget:',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  CurrencyFormatter.format(
                                    remainingBudgetAfter > 0
                                        ? remainingBudgetAfter
                                        : 0.0,
                                  ),
                                  style: TextStyle(
                                    color: remainingBudgetAfter <= 0
                                        ? AppColors.dangerRed
                                        : AppColors.successGreen,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),

                            if (isBudgetExceeded) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.dangerRed.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.warning_amber_rounded,
                                      color: AppColors.dangerRed,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Warning: This expense exceeds your monthly budget limit for $_selectedCategory by ${CurrencyFormatter.format(projectedSpent - categoryLimit)}.',
                                        style: const TextStyle(
                                          color: AppColors.dangerRed,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    GradientButton(
                      text: widget.editTransaction != null
                          ? 'Update Expense'
                          : 'Save Expense',
                      onTap: _saveExpense,
                      colors: isBudgetExceeded
                          ? [AppColors.dangerRed, AppColors.primaryPurple]
                          : null,
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
