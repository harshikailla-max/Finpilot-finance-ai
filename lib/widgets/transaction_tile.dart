import 'package:flutter/material.dart';
import '../models/finance_transaction.dart';
import '../utils/constants.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_utils.dart';

class TransactionTile extends StatelessWidget {
  final FinanceTransaction transaction;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Function(DismissDirection)? onDismissed;

  const TransactionTile({
    super.key,
    required this.transaction,
    this.onTap,
    this.onLongPress,
    this.onDismissed,
  });

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
        case 'Gift':
          return Icons.card_giftcard_rounded;
        case 'Scholarship':
          return Icons.school_rounded;
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
        case 'Bonus':
          return AppColors.warningOrange;
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
        case 'Education':
          return Colors.blue;
        case 'Travel':
          return Colors.teal;
        default:
          return AppColors.textSecondary;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconData = _getCategoryIcon(transaction.category, transaction.type);
    final themeColor = _getCategoryColor(transaction.category, transaction.type);
    final isIncome = transaction.type == TransactionType.income;

    Widget tile = Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.04),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: onTap,
        onLongPress: onLongPress,
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: themeColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            iconData,
            color: themeColor,
            size: 24,
          ),
        ),
        title: Text(
          transaction.title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: DefaultTextStyle(
            style: TextStyle(
              color: AppColors.textSecondary.withValues(alpha: 0.7),
              fontSize: 12,
            ),
            child: Row(
            children: [
              Text(transaction.category),
              const SizedBox(width: 6),
              const Icon(Icons.circle, size: 4, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Text(transaction.paymentMethod),
              const SizedBox(width: 6),
              const Icon(Icons.circle, size: 4, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Text(AppDateUtils.formatFriendly(transaction.date)),
            ],
          ),
        ),
      ),
        trailing: Text(
          '${isIncome ? '+' : '-'}${CurrencyFormatter.format(transaction.amount)}',
          style: TextStyle(
            color: isIncome ? AppColors.successGreen : AppColors.dangerRed,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ),
    );

    if (onDismissed != null) {
      return Dismissible(
        key: Key(transaction.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24.0),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.dangerRed.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.delete_outline_rounded,
            color: AppColors.dangerRed,
            size: 28,
          ),
        ),
        onDismissed: onDismissed,
        child: tile,
      );
    }

    return tile;
  }
}
