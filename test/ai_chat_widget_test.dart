import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:finpilot_ai/providers/finance_provider.dart';
import 'package:finpilot_ai/providers/budget_provider.dart';
import 'package:finpilot_ai/providers/goal_provider.dart';
import 'package:finpilot_ai/providers/investment_provider.dart';
import 'package:finpilot_ai/providers/ai_provider.dart';
import 'package:finpilot_ai/screens/ai_chat_screen.dart';
import 'package:finpilot_ai/services/storage_service.dart';
import 'package:finpilot_ai/theme/app_theme.dart';

class MockTestStorage implements StorageService {
  final Map<String, dynamic> _data = {};

  @override
  Future<void> init() async {}

  @override
  String? getString(String key) => _data[key] as String?;

  @override
  Future<bool> setString(String key, String value) async {
    _data[key] = value;
    return true;
  }

  @override
  bool? getBool(String key) => _data[key] as bool?;

  @override
  Future<bool> setBool(String key, bool value) async {
    _data[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    _data.remove(key);
    return true;
  }

  @override
  Future<bool> clear() async {
    _data.clear();
    return true;
  }
}

void main() {
  testWidgets(
    'AIChatScreen renders header, orb, suggestion chips, and input composer',
    (WidgetTester tester) async {
      final storage = MockTestStorage();
      final finance = FinanceProvider(storage);
      final budget = BudgetProvider(storage);
      final goals = GoalProvider(storage);
      final investments = InvestmentProvider(storage);
      final aiProvider = AIProvider(
        financeProvider: finance,
        budgetProvider: budget,
        goalProvider: goals,
        storageService: storage,
        investmentProvider: investments,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<StorageService>.value(value: storage),
            ChangeNotifierProvider<FinanceProvider>.value(value: finance),
            ChangeNotifierProvider<BudgetProvider>.value(value: budget),
            ChangeNotifierProvider<GoalProvider>.value(value: goals),
            ChangeNotifierProvider<InvestmentProvider>.value(
              value: investments,
            ),
            ChangeNotifierProvider<AIProvider>.value(value: aiProvider),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const AIChatScreen(),
          ),
        ),
      );

      // Initial frame
      await tester.pump();

      // Verify header and assistant presence
      expect(find.text('AI Coach'), findsOneWidget);
      expect(find.text('FINPILOT'), findsOneWidget);

      // Verify suggestion chips before first user query
      expect(find.text('Analyze My Spending'), findsOneWidget);
      expect(find.text('Help Me Save More'), findsOneWidget);
      expect(find.text('Check My Budget'), findsOneWidget);
      expect(find.text('Review My Goals'), findsOneWidget);

      // Verify input composer placeholder
      expect(
        find.text('Ask FinPilot about spending, budgets, goals...'),
        findsOneWidget,
      );
    },
  );
}
