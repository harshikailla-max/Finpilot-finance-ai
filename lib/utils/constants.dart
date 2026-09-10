import 'package:flutter/material.dart';

class AppColors {
  static const Color background = Color(0xFF081120);
  static const Color secondaryBackground = Color(0xFF0D1626);
  static const Color cardBackground = Color(0xFF10192B);
  static const Color primaryPurple = Color(0xFF6C5CE7);
  static const Color lightPurple = Color(0xFF9A8CFF);
  static const Color cyan = Color(0xFF4CC9F0);
  static const Color successGreen = Color(0xFF2DD4A8);
  static const Color warningOrange = Color(0xFFFFB86B);
  static const Color dangerRed = Color(0xFFFF6B81);

  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xB3FFFFFF);
  static const Color textMuted = Color(0x80FFFFFF);
}

class AppConstants {
  static const double cardRadius = 24.0;
  static const double buttonRadius = 18.0;

  static const List<String> expenseCategories = [
    'Food',
    'Transport',
    'Shopping',
    'Bills',
    'Entertainment',
    'Health',
    'Education',
    'Travel',
    'Other',
  ];

  static const List<String> incomeCategories = [
    'Salary',
    'Freelance',
    'Business',
    'Investment',
    'Bonus',
    'Gift',
    'Scholarship',
    'Other',
  ];

  static const List<String> paymentMethods = [
    'UPI',
    'Cash',
    'Debit Card',
    'Credit Card',
    'Bank',
  ];

  static const List<String> incomeReceivedThrough = [
    'Bank',
    'UPI',
    'Cash',
    'PayPal',
    'Other',
  ];

  static const List<String> goalCategories = [
    'Emergency Fund',
    'Travel',
    'Education',
    'Vehicle',
    'House',
    'Gadgets',
    'Investment',
    'Other',
  ];

  static const List<String> investmentTypes = [
    'Emergency Fund',
    'Fixed Deposit',
    'Mutual Fund',
    'Index Fund',
    'PPF',
    'Gold',
    'Other Investments',
  ];
}
