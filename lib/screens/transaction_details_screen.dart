import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/finance_transaction.dart';
import '../providers/finance_provider.dart';
import '../utils/constants.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_utils.dart';
import '../widgets/glass_card.dart';
import 'add_expense_screen.dart';
import 'add_income_screen.dart';

class TransactionDetailsScreen extends StatelessWidget {
  final FinanceTransaction transaction;

  const TransactionDetailsScreen({super.key, required this.transaction});

  IconData _getCategoryIcon(String category, TransactionType type) {
    if (type == TransactionType.income) {
      switch (category) {
        case 'Salary':
          return Icons.account_balance_wallet_rounded;
        case 'Freelance':
          return Icons.laptop_mac_rounded;
        case 'Business':
          return Icons.storefront_rounded;
        case 'Investment':
          return Icons.show_chart_rounded;
        case 'Bonus':
          return Icons.redeem_rounded;
        default:
          return Icons.monetization_on_rounded;
      }
    } else {
      switch (category) {
        case 'Food':
          return Icons.restaurant_rounded;
        case 'Transport':
          return Icons.directions_car_rounded;
        case 'Shopping':
          return Icons.shopping_bag_rounded;
        case 'Bills':
          return Icons.receipt_long_rounded;
        case 'Entertainment':
          return Icons.sports_esports_rounded;
        case 'Health':
          return Icons.local_hospital_rounded;
        case 'Education':
          return Icons.school_rounded;
        case 'Travel':
          return Icons.flight_takeoff_rounded;
        default:
          return Icons.shopping_cart_rounded;
      }
    }
  }

  Color _getCategoryColor(String category, TransactionType type) {
    if (type == TransactionType.income) {
      switch (category) {
        case 'Salary':
          return AppColors.successGreen;
        case 'Freelance':
          return AppColors.cyan;
        case 'Business':
          return AppColors.lightPurple;
        case 'Investment':
          return AppColors.primaryPurple;
        default:
          return AppColors.successGreen.withValues(alpha: 0.8);
      }
    } else {
      switch (category) {
        case 'Food':
          return AppColors.warningOrange;
        case 'Transport':
          return AppColors.cyan;
        case 'Shopping':
          return AppColors.lightPurple;
        case 'Bills':
          return AppColors.dangerRed;
        case 'Entertainment':
          return AppColors.primaryPurple;
        case 'Health':
          return AppColors.successGreen;
        default:
          return AppColors.textSecondary;
      }
    }
  }

  void _edit(BuildContext context) {
    Navigator.pop(context); // Pop details screen
    Widget editScreen = transaction.type == TransactionType.income
        ? AddIncomeScreen(editTransaction: transaction)
        : AddExpenseScreen(editTransaction: transaction);

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => editScreen),
    );
  }

  void _delete(BuildContext context) async {
    final financeProvider = context.read<FinanceProvider>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // Delete operation
    await financeProvider.deleteTransaction(transaction.id);

    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: const Text('Transaction deleted successfully'),
        backgroundColor: AppColors.dangerRed.withValues(alpha: 0.8),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    if (context.mounted) {
      Navigator.pop(context); // Pop details screen
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = _getCategoryColor(transaction.category, transaction.type);
    final iconData = _getCategoryIcon(transaction.category, transaction.type);
    final isIncome = transaction.type == TransactionType.income;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: AppColors.cyan),
            onPressed: () => _edit(context),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.dangerRed),
            onPressed: () => _delete(context),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned(
            top: -20,
            left: -20,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: themeColor.withValues(alpha: 0.08),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 16),

                  // Large Category icon
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: themeColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: themeColor.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      iconData,
                      color: themeColor,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Amount
                  Text(
                    '${isIncome ? '+' : '-'}${CurrencyFormatter.format(transaction.amount)}',
                    style: TextStyle(
                      color: isIncome ? AppColors.successGreen : AppColors.dangerRed,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Title
                  Text(
                    transaction.title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Metadata list in Glass Card
                  GlassCard(
                    child: Column(
                      children: [
                        _buildDetailRow(
                          icon: Icons.category_outlined,
                          label: 'Category',
                          value: transaction.category,
                        ),
                        const Divider(height: 24, color: Colors.white10),
                        _buildDetailRow(
                          icon: Icons.calendar_today_outlined,
                          label: 'Transaction Date',
                          value: AppDateUtils.formatFriendly(transaction.date),
                        ),
                        const Divider(height: 24, color: Colors.white10),
                        _buildDetailRow(
                          icon: Icons.payment_outlined,
                          label: 'Payment Method',
                          value: transaction.paymentMethod,
                        ),
                        if (transaction.merchant.isNotEmpty) ...[
                          const Divider(height: 24, color: Colors.white10),
                          _buildDetailRow(
                            icon: Icons.storefront_outlined,
                            label: 'Merchant',
                            value: transaction.merchant,
                          ),
                        ],
                        const Divider(height: 24, color: Colors.white10),
                        _buildDetailRow(
                          icon: Icons.repeat_one_rounded,
                          label: 'Is Recurring',
                          value: transaction.isRecurring ? 'Yes, Monthly' : 'No, One-time',
                        ),
                        if (transaction.note.isNotEmpty) ...[
                          const Divider(height: 24, color: Colors.white10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.notes_rounded, size: 16, color: AppColors.textMuted),
                                  SizedBox(width: 8),
                                  Text(
                                    'Notes',
                                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                transaction.note,
                                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, height: 1.4),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textMuted),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
