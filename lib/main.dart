import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'providers/theme_provider.dart';
import 'providers/finance_provider.dart';
import 'providers/budget_provider.dart';
import 'providers/goal_provider.dart';
import 'providers/financial_health_provider.dart';
import 'providers/investment_provider.dart';
import 'providers/ai_provider.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI overlay style for dark fintech aesthetic
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF081120),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final storageService = SharedPreferencesStorageService();
  await storageService.init();

  runApp(
    MultiProvider(
      providers: [
        Provider<StorageService>.value(value: storageService),
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(storageService),
        ),
        ChangeNotifierProvider<FinanceProvider>(
          create: (_) => FinanceProvider(storageService),
        ),
        ChangeNotifierProvider<BudgetProvider>(
          create: (_) => BudgetProvider(storageService),
        ),
        ChangeNotifierProvider<GoalProvider>(
          create: (_) => GoalProvider(storageService),
        ),
        ChangeNotifierProvider<InvestmentProvider>(
          create: (_) => InvestmentProvider(storageService),
        ),
        ChangeNotifierProxyProvider3<FinanceProvider, BudgetProvider, GoalProvider, FinancialHealthProvider>(
          create: (context) => FinancialHealthProvider(
            financeProvider: context.read<FinanceProvider>(),
            budgetProvider: context.read<BudgetProvider>(),
            goalProvider: context.read<GoalProvider>(),
          ),
          update: (context, finance, budget, goal, previous) =>
              previous ??
              FinancialHealthProvider(
                financeProvider: finance,
                budgetProvider: budget,
                goalProvider: goal,
              ),
        ),
        ChangeNotifierProxyProvider3<FinanceProvider, BudgetProvider, GoalProvider, AIProvider>(
          create: (context) => AIProvider(
            financeProvider: context.read<FinanceProvider>(),
            budgetProvider: context.read<BudgetProvider>(),
            goalProvider: context.read<GoalProvider>(),
            storageService: storageService,
          ),
          update: (context, finance, budget, goal, previous) =>
              previous ??
              AIProvider(
                financeProvider: finance,
                budgetProvider: budget,
                goalProvider: goal,
                storageService: storageService,
              ),
        ),
      ],
      child: const FinPilotApp(),
    ),
  );
}

class FinPilotApp extends StatelessWidget {
  const FinPilotApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      title: 'FinPilot AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const SplashScreen(),
    );
  }
}
