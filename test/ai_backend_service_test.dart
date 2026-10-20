import 'package:flutter_test/flutter_test.dart';
import 'package:finpilot_ai/models/ai_message_model.dart';
import 'package:finpilot_ai/providers/finance_provider.dart';
import 'package:finpilot_ai/providers/budget_provider.dart';
import 'package:finpilot_ai/providers/goal_provider.dart';
import 'package:finpilot_ai/providers/investment_provider.dart';
import 'package:finpilot_ai/services/ai_backend_service.dart';
import 'package:finpilot_ai/services/storage_service.dart';

class MockStorage implements StorageService {
  final Map<String, dynamic> data = {};

  @override
  Future<void> init() async {}

  @override
  String? getString(String key) => data[key] as String?;

  @override
  Future<bool> setString(String key, String value) async {
    data[key] = value;
    return true;
  }

  @override
  bool? getBool(String key) => data[key] as bool?;

  @override
  Future<bool> setBool(String key, bool value) async {
    data[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    data.remove(key);
    return true;
  }

  @override
  Future<bool> clear() async {
    data.clear();
    return true;
  }
}

void main() {
  group('AIBackendService Diagnostic & Health Tests', () {
    late MockStorage storage;
    late FinanceProvider finance;
    late BudgetProvider budget;
    late GoalProvider goals;
    late InvestmentProvider investments;

    setUp(() {
      storage = MockStorage();
      finance = FinanceProvider(storage);
      budget = BudgetProvider(storage);
      goals = GoalProvider(storage);
      investments = InvestmentProvider(storage);
    });

    test('checkHealth returns unconfigured status when no API key or custom endpoint is set', () async {
      final backend = AIBackendService(storageService: storage);

      final health = await backend.checkHealth();
      expect(health['configured'], isFalse);
      expect(health['status'], equals('unconfigured'));
      expect(health['provider'], equals('gemini'));
      expect(health['model'], equals('gemini-flash-latest'));
      expect(health['message'], contains('No AI API key is configured'));
    });

    test('resolvedBaseUri defaults safely and parses custom endpoint', () {
      final backendDefault = AIBackendService(storageService: storage);
      expect(backendDefault.resolvedBaseUri, isNotNull);

      storage.data['ai_backend_endpoint'] = 'https://api.finpilot.ai';
      final backendCustom = AIBackendService(storageService: storage);
      expect(backendCustom.resolvedBaseUri.host, equals('api.finpilot.ai'));
    });

    test('generateAdvice returns actionable failure directing setup when unconfigured', () async {
      final backend = AIBackendService(storageService: storage);

      final result = await backend.generateAdvice(
        query: 'What is my financial situation?',
        finance: finance,
        budget: budget,
        goals: goals,
        investments: investments,
        chatHistory: [],
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('FINPILOT_AI_API_KEY'));
      expect(result.isLocalFallback, isTrue);
    });

    test('formatGeminiContents strictly alternates turns and ends with query', () {
      final history = [
        AIMessageModel(
          id: '1',
          message: 'Hello! I am FinPilot AI.',
          isUser: false,
          timestamp: DateTime.now(),
        ),
        AIMessageModel(
          id: '2',
          message: 'What is inflation?',
          isUser: true,
          timestamp: DateTime.now(),
        ),
        AIMessageModel(
          id: '3',
          message: 'Inflation is the rate at which prices rise.',
          isUser: false,
          timestamp: DateTime.now(),
        ),
      ];

      final contents = AIBackendService.formatGeminiContents(
        chatHistory: history,
        query: 'How does it affect my savings in India?',
      );

      // Must not begin with model
      expect(contents.first['role'], equals('user'));
      // Must end with user's current query
      expect(contents.last['role'], equals('user'));
      final lastParts = contents.last['parts'] as List;
      expect((lastParts.first as Map)['text'], equals('How does it affect my savings in India?'));

      // Roles must alternate strictly
      for (int i = 0; i < contents.length - 1; i++) {
        expect(contents[i]['role'], isNot(equals(contents[i + 1]['role'])));
      }
    });

    test('AICoachResult model constructors work cleanly', () {
      final aiRes = AICoachResult.fromAI('Hello from Gemini');
      expect(aiRes.isSuccess, isTrue);
      expect(aiRes.isLocalFallback, isFalse);
      expect(aiRes.text, equals('Hello from Gemini'));

      final failRes = AICoachResult.failure('Authentication Failure (403)');
      expect(failRes.isSuccess, isFalse);
      expect(failRes.errorMessage, contains('403'));
    });
  });
}
