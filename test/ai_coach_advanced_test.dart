import 'package:flutter_test/flutter_test.dart';
import 'package:finpilot_ai/models/advisor_models.dart';
import 'package:finpilot_ai/models/finance_transaction.dart';
import 'package:finpilot_ai/providers/finance_provider.dart';
import 'package:finpilot_ai/providers/budget_provider.dart';
import 'package:finpilot_ai/providers/goal_provider.dart';
import 'package:finpilot_ai/providers/investment_provider.dart';
import 'package:finpilot_ai/providers/financial_health_provider.dart';
import 'package:finpilot_ai/services/advisor/advisor_engine.dart';
import 'package:finpilot_ai/services/advisor/investment_reasoning_service.dart';
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
  group('AI Financial Coach Lump Sum & Compound Growth Reasoning Tests', () {
    late MockStorage storage;
    late FinanceProvider finance;
    late InvestmentProvider investments;

    setUp(() {
      storage = MockStorage();
      storage.data['transactions'] = '[]';
      finance = FinanceProvider(storage);
      investments = InvestmentProvider(storage);
    });

    test('Calculates 3 compound growth scenarios for ₹1,00,000 lump sum accurately', () async {
      // Seed income and expenses: monthly expense 30,000, balance 2,00,000
      final now = DateTime.now();
      await finance.addTransaction(
        FinanceTransaction(
          id: 'inc-1',
          title: 'Salary',
          amount: 230000.0,
          category: 'Salary',
          type: TransactionType.income,
          date: now,
          paymentMethod: 'Bank',
          createdAt: now,
        ),
      );
      await finance.addTransaction(
        FinanceTransaction(
          id: 'exp-1',
          title: 'Rent & Living',
          amount: 30000.0,
          category: 'Bills',
          type: TransactionType.expense,
          date: now,
          paymentMethod: 'Bank',
          createdAt: now,
        ),
      );

      final report = InvestmentReasoningService.evaluateLumpSumStrategy(
        lumpSum: 100000.0,
        finance: finance,
        investments: investments,
        durationYears: 5,
      );

      expect(report.principal, equals(100000.0));
      expect(report.durationYears, equals(5));
      expect(report.pessimisticRate, equals(6.5));
      expect(report.illustrativeRate, equals(11.0));
      expect(report.optimisticRate, equals(14.0));

      // FV = 100,000 * (1 + 0.065)^5 = 137,008.67
      expect(report.pessimisticCorpus, closeTo(137008.67, 1.0));
      expect(report.pessimisticGain, closeTo(37008.67, 1.0));

      // FV = 100,000 * (1 + 0.11)^5 = 168,505.81
      expect(report.illustrativeCorpus, closeTo(168505.81, 1.0));
      expect(report.illustrativeGain, closeTo(68505.81, 1.0));

      // FV = 100,000 * (1 + 0.14)^5 = 192,541.45
      expect(report.optimisticCorpus, closeTo(192541.45, 1.0));
      expect(report.optimisticGain, closeTo(92541.45, 1.0));

      // Liquidity is healthy (2,00,000 / 30,000 = 6.6 months)
      expect(report.emergencyFundStatus, contains('Liquidity Healthy'));

      // Check tax implications & SEBI disclaimer
      expect(report.taxImplications, contains('Budget 2024'));
      expect(report.taxImplications, contains('12.5%'));
      expect(report.taxImplications, contains('20%'));
      expect(report.educationalDisclaimer, contains('not a SEBI-registered'));
    });

    test('Triggers liquidity warning when emergency runway is under 3 months', () async {
      // Liquid balance only 20,000 with monthly expense 30,000 (0.66 months runway)
      final now = DateTime.now();
      await finance.addTransaction(
        FinanceTransaction(
          id: 'inc-low',
          title: 'Salary',
          amount: 50000.0,
          category: 'Salary',
          type: TransactionType.income,
          date: now,
          paymentMethod: 'Bank',
          createdAt: now,
        ),
      );
      await finance.addTransaction(
        FinanceTransaction(
          id: 'exp-high',
          title: 'High Living Cost',
          amount: 30000.0,
          category: 'Bills',
          type: TransactionType.expense,
          date: now,
          paymentMethod: 'Bank',
          createdAt: now,
        ),
      );

      final report = InvestmentReasoningService.evaluateLumpSumStrategy(
        lumpSum: 100000.0,
        finance: finance,
        investments: investments,
      );

      expect(report.emergencyFundStatus, contains('Liquidity Alert'));
      expect(report.emergencyFundStatus, contains('high-yield liquid fund'));
    });

    test('AIBackendService throws RemoteAIException with actionable message on 401/403', () {
      final ex401 = RemoteAIException(401, 'Invalid API Key');
      final ex403 = RemoteAIException(403, 'Permission Denied');

      expect(ex401.statusCode, equals(401));
      expect(ex403.statusCode, equals(403));
      expect(ex401.toString(), contains('RemoteAIException(401)'));
      expect(ex403.toString(), contains('Permission Denied'));
    });

    test('AIBackendService initializes with storage and detects unconfigured state', () {
      final backend = AIBackendService(storageService: storage);
      expect(backend.isBackendConfigured, isFalse);
    });

    test('AdvisorEngine provides authoritative CA Tax Regime audit with Budget 2024 rules', () async {
      final budget = BudgetProvider(storage);
      final goals = GoalProvider(storage);
      final health = FinancialHealthProvider(
        financeProvider: finance,
        budgetProvider: budget,
        goalProvider: goals,
      );

      final engine = AdvisorEngine();
      final response = engine.evaluate(
        query: 'Which tax regime should I choose (Old vs New)?',
        finance: finance,
        budget: budget,
        goals: goals,
        investments: investments,
        health: health,
      );

      expect(response.intent, equals(AdvisorIntent.tax));
      expect(response.verdict, contains('TAX VERDICT'));
      expect(response.calculation, contains('Standard Deduction: ₹75,000'));
      expect(response.reasoning, contains('Budget 2024'));
      expect(response.reasoning, contains('₹7.75 Lakhs is effectively 100% tax-free'));
      expect(response.reasoning, contains('12.5%'));
    });

    test('AdvisorEngine calculates 30x FIRE retirement corpus with 6% inflation', () async {
      final budget = BudgetProvider(storage);
      final goals = GoalProvider(storage);
      final health = FinancialHealthProvider(
        financeProvider: finance,
        budgetProvider: budget,
        goalProvider: goals,
      );

      final engine = AdvisorEngine();
      final response = engine.evaluate(
        query: 'How much do I need to retire?',
        finance: finance,
        budget: budget,
        goals: goals,
        investments: investments,
        health: health,
      );

      expect(response.intent, equals(AdvisorIntent.retirement));
      expect(response.verdict, contains('FIRE NUMBER'));
      expect(response.calculation, contains('30×'));
      expect(response.reasoning, contains('Safe Withdrawal Rate'));
      expect(response.recommendation, contains('SIP'));
    });

    test('AdvisorEngine provides non-negotiable CA Insurance moat rules', () async {
      final budget = BudgetProvider(storage);
      final goals = GoalProvider(storage);
      final health = FinancialHealthProvider(
        financeProvider: finance,
        budgetProvider: budget,
        goalProvider: goals,
      );

      final engine = AdvisorEngine();
      final response = engine.evaluate(
        query: 'Which insurance should I buy? Are ULIPs good?',
        finance: finance,
        budget: budget,
        goals: goals,
        investments: investments,
        health: health,
      );

      expect(response.intent, equals(AdvisorIntent.insurance));
      expect(response.verdict, contains('INSURANCE AUDIT'));
      expect(response.calculation, contains('15–20× Annual Income'));
      expect(response.reasoning, contains('Never Mix Insurance and Investment'));
      expect(response.reasoning, contains('Super Top-Up'));
    });

    test('AdvisorEngine solves Home Loan Prepayment vs Equity SIP mathematically', () async {
      final budget = BudgetProvider(storage);
      final goals = GoalProvider(storage);
      final health = FinancialHealthProvider(
        financeProvider: finance,
        budgetProvider: budget,
        goalProvider: goals,
      );

      final engine = AdvisorEngine();
      final response = engine.evaluate(
        query: 'Should I prepay my home loan or invest in mutual funds?',
        finance: finance,
        budget: budget,
        goals: goals,
        investments: investments,
        health: health,
      );

      expect(response.intent, equals(AdvisorIntent.debt));
      expect(response.verdict, contains('DEBT AUDIT'));
      expect(response.reasoning, contains('8.5% vs 12% Math'));
      expect(response.reasoning, contains('1-Extra-EMI Hybrid Hack'));
    });

    test('AdvisorEngine delivers executive CA dashboard greeting on "Hi"', () async {
      final budget = BudgetProvider(storage);
      final goals = GoalProvider(storage);
      final health = FinancialHealthProvider(
        financeProvider: finance,
        budgetProvider: budget,
        goalProvider: goals,
      );

      final engine = AdvisorEngine();
      final response = engine.evaluate(
        query: 'Hi',
        finance: finance,
        budget: budget,
        goals: goals,
        investments: investments,
        health: health,
      );

      expect(response.verdict, contains('EXECUTIVE FINANCIAL AUDIT'));
      expect(response.reasoning, contains('Chartered Wealth Architect'));
      expect(response.reasoning, contains('Cash Flow'));
      expect(response.reasoning, contains('Which tax regime should I choose'));
    });
  });
}
