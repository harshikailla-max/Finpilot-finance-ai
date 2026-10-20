import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/finance_transaction.dart';
import '../providers/finance_provider.dart';
import '../services/category_service.dart';
import '../utils/constants.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_button.dart';

class AddIncomeScreen extends StatefulWidget {
  final FinanceTransaction? editTransaction;
  const AddIncomeScreen({super.key, this.editTransaction});

  @override
  State<AddIncomeScreen> createState() => _AddIncomeScreenState();
}

class _AddIncomeScreenState extends State<AddIncomeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _sourceController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  String _selectedCategory = 'Salary';
  String _selectedReceivedThrough = 'Bank';
  DateTime _selectedDate = DateTime.now();
  bool _isRecurring = false;
  bool _isAutoCategoryDetected = false;

  final List<double> _quickAmounts = [1000, 5000, 10000, 25000, 50000];

  @override
  void initState() {
    super.initState();
    if (widget.editTransaction != null) {
      final tx = widget.editTransaction!;
      _sourceController.text = tx.title;
      _amountController.text = tx.amount.toStringAsFixed(0);
      _noteController.text = tx.note;
      _selectedCategory = tx.category;
      _selectedReceivedThrough = tx.paymentMethod;
      _selectedDate = tx.date;
      _isRecurring = tx.isRecurring;
    }

    _sourceController.addListener(_onSourceChanged);
  }

  @override
  void dispose() {
    _sourceController.removeListener(_onSourceChanged);
    _sourceController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _onSourceChanged() {
    final text = _sourceController.text;
    if (text.isNotEmpty) {
      final detected = CategoryService.detectIncomeCategory(text);
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

  void _saveIncome() async {
    if (_formKey.currentState!.validate()) {
      final financeProvider = context.read<FinanceProvider>();
      final uuid = const Uuid();

      final title = _sourceController.text.trim();
      final amount = double.parse(_amountController.text.trim());
      final note = _noteController.text.trim();

      final tx = FinanceTransaction(
        id: widget.editTransaction?.id ?? uuid.v4(),
        title: title,
        amount: amount,
        category: _selectedCategory,
        type: TransactionType.income,
        date: _selectedDate,
        paymentMethod: _selectedReceivedThrough,
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
                    ? 'Income updated successfully!'
                    : 'Income logged successfully!',
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.editTransaction != null ? 'Edit Income' : 'Add Income',
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
            left: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.successGreen.withValues(alpha: 0.1),
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

                          // Source Input
                          const Text(
                            'Income Source',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _sourceController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              hintText:
                                  'e.g. Monthly Salary, Freelance Web Design',
                              prefixIcon: Icon(
                                Icons.title_rounded,
                                color: AppColors.textMuted,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter an income source';
                              }
                              return null;
                            },
                          ),

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

                          // Category & Received Through
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
                                      items: AppConstants.incomeCategories.map((
                                        cat,
                                      ) {
                                        return DropdownMenuItem(
                                          value: cat,
                                          child: Text(cat),
                                        );
                                      }).toList(),
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
                              // Received Through
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Received Through',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    DropdownButtonFormField<String>(
                                      value: _selectedReceivedThrough,
                                      decoration: const InputDecoration(
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                      ),
                                      dropdownColor: AppColors.cardBackground,
                                      items: AppConstants.incomeReceivedThrough
                                          .map((pm) {
                                            return DropdownMenuItem(
                                              value: pm,
                                              child: Text(pm),
                                            );
                                          })
                                          .toList(),
                                      onChanged: (val) {
                                        setState(() {
                                          _selectedReceivedThrough = val!;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Date picker & Type
                          Row(
                            children: [
                              // Date
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Received Date',
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
                              // Recurring
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Income Cycle',
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
                                            'Recurring',
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
                    const SizedBox(height: 32),

                    GradientButton(
                      text: widget.editTransaction != null
                          ? 'Update Income'
                          : 'Save Income',
                      onTap: _saveIncome,
                      colors: const [AppColors.successGreen, AppColors.cyan],
                    ),
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
