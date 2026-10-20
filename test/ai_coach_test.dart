import 'package:flutter_test/flutter_test.dart';
import 'package:finpilot_ai/models/finance_transaction.dart';
import 'package:finpilot_ai/models/goal_model.dart';
import 'package:finpilot_ai/providers/finance_provider.dart';
import 'package:finpilot_ai/providers/budget_provider.dart';
import 'package:finpilot_ai/providers/goal_provider.dart';
import 'package:finpilot_ai/providers/investment_provider.dart';
import 'package:finpilot_ai/providers/ai_provider.dart';
import 'package:finpilot_ai/services/advisor/affordability_service.dart';
import 'package:finpilot_ai/services/ai_backend_service.dart';
import 'package:finpilot_ai/services/storage_service.dart';

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
  group('AI Coach & Backend Service Tests', () {
    late MockTestStorage storage;
    late FinanceProvider finance;
    late BudgetProvider budget;
    late GoalProvider goals;
    late InvestmentProvider investments;
    late AIProvider aiProvider;

    setUp(() async {
      storage = MockTestStorage();
      finance = FinanceProvider(storage);
      budget = BudgetProvider(storage);
      goals = GoalProvider(storage);
      investments = InvestmentProvider(storage);

      // Seed real financial transactions
      await finance.addTransaction(
        FinanceTransaction(
          id: 'tx-1',
          title: 'Monthly Salary',
          amount: 85000.0,
          category: 'Salary',
          type: TransactionType.income,
          date: DateTime.now(),
          paymentMethod: 'Bank Transfer',
          createdAt: DateTime.now(),
        ),
      );

      await finance.addTransaction(
        FinanceTransaction(
          id: 'tx-2',
          title: 'Groceries & Provisions',
          amount: 12000.0,
          category: 'Food',
          type: TransactionType.expense,
          date: DateTime.now(),
          paymentMethod: 'UPI',
          createdAt: DateTime.now(),
        ),
      );

      await finance.addTransaction(
        FinanceTransaction(
          id: 'tx-3',
          title: 'Online Shopping',
          amount: 6500.0,
          category: 'Shopping',
          type: TransactionType.expense,
          date: DateTime.now(),
          paymentMethod: 'Credit Card',
          createdAt: DateTime.now(),
        ),
      );

      // Seed budget
      await budget.setMonthlyBudget(40000.0);
      await budget.setCategoryBudget('Food', 15000.0);
      await budget.setCategoryBudget('Shopping', 5000.0);

      // Seed goal
      await goals.addGoal(
        GoalModel(
          id: 'goal-1',
          title: 'Emergency Reserve',
          targetAmount: 200000.0,
          currentAmount: 60000.0,
          deadline: DateTime.now().add(const Duration(days: 180)),
          category: 'Emergency Fund',
          createdAt: DateTime.now(),
        ),
      );

      aiProvider = AIProvider(
        financeProvider: finance,
        budgetProvider: budget,
        goalProvider: goals,
        storageService: storage,
        investmentProvider: investments,
      );
    });

    test('Correctly identifies unconfigured AI backend and provides explicit configuration guidance without fake responses', () async {
      final backend = AIBackendService(storageService: storage);

      expect(backend.isBackendConfigured, isFalse);

      final result = await backend.generateAdvice(
        query: 'Where am I spending the most?',
        finance: finance,
        budget: budget,
        goals: goals,
        investments: investments,
        chatHistory: [],
      );

      // Must NOT return fake/canned AI response; must return unconfigured diagnostic
      expect(result.isSuccess, isFalse);
      expect(result.isLocalFallback, isTrue);
      expect(result.errorMessage, contains('FINPILOT_AI_API_KEY'));
    });

    test('AffordabilityService evaluates purchase affordability using real cash flow and liquid balance', () async {
      final analysis = AffordabilityService.evaluatePurchase(
        product: 'Laptop',
        price: 45000.0,
        finance: finance,
        budget: budget,
        goals: goals,
      );

      expect(analysis.verdict, isNotNull);
      expect(analysis.remainingEmergencyMonths, isNotNull);
    });

    test(
      'AI Provider handles conversational message flow and stores chat history',
      () async {
        expect(
          aiProvider.chatMessages.isNotEmpty,
          isTrue,
        ); // Initial welcome seed

        await aiProvider.sendMessage('How can I save more?');

        expect(aiProvider.isTyping, isFalse);
        // User message and assistant response (or diagnostic guidance) added
        expect(aiProvider.chatMessages.length, greaterThanOrEqualTo(2));

        final lastMessage = aiProvider.chatMessages.last;
        expect(lastMessage.isUser, isFalse);
        expect(lastMessage.message, isNotEmpty);
      },
    );

    test('AI Provider prevents duplicate submission when already typing', () async {
      aiProvider.sendMessage('First message'); // triggers async
      // Subsequent immediate send while typing must be rejected
      await aiProvider.sendMessage('Second message while typing');
      expect(aiProvider.isTyping, isFalse);
    });

    test('AI Provider clearChat resets conversation cleanly', () async {
      await aiProvider.sendMessage('Test query');
      expect(aiProvider.chatMessages.length, greaterThanOrEqualTo(2));

      await aiProvider.clearChat();
      expect(aiProvider.chatMessages.length, equals(1));
      expect(aiProvider.chatMessages.first.isUser, isFalse);
      expect(aiProvider.chatMessages.first.message, contains('FinPilot AI'));
    });
  });
}
