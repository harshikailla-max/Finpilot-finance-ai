import 'package:flutter/material.dart';

class AppColors {
  // FINPILOT AURA Luxury Futuristic Palette
  static const Color obsidian = Color(0xFF05070D);
  static const Color background = Color(0xFF080B14);
  static const Color secondaryBackground = Color(0xFF0D1220);
  static const Color cardBackground = Color(0xFF0E1424);

  // Glass Material System
  static const Color glass = Color(0x0CFFFFFF); // rgba(255,255,255,0.045)
  static const Color glassBorder = Color(0x14FFFFFF); // rgba(255,255,255,0.08)
  static const Color glassHighlight = Color(0x24FFFFFF);

  // Typography
  static const Color textPrimary = Color(0xFFF5F7FF);
  static const Color textSecondary = Color(0xFF9299AA);
  static const Color textMuted = Color(0xFF5E6575);

  // AURA Accents (Used with extreme restraint)
  static const Color auroraViolet = Color(0xFF7C5CFF);
  static const Color auroraCyan = Color(0xFF55D6FF);
  static const Color softBlue = Color(0xFF7AA8FF);
  static const Color luxuryChampagne = Color(0xFFD8B878);

  // Status Indicators
  static const Color success = Color(0xFF61D6A1);
  static const Color warning = Color(0xFFF2B866);
  static const Color danger = Color(0xFFFF7185);

  // Backwards Compatibility Aliases
  static const Color primaryPurple = Color(0xFF7C5CFF);
  static const Color lightPurple = Color(0xFF9A8CFF);
  static const Color cyan = Color(0xFF55D6FF);
  static const Color successGreen = Color(0xFF61D6A1);
  static const Color warningOrange = Color(0xFFF2B866);
  static const Color warningAmber = Color(0xFFF2B866);
  static const Color dangerRed = Color(0xFFFF7185);
}

class AppTypography {
  static const String fontFamily = 'Plus Jakarta Sans';
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
