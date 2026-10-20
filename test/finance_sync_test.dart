import 'package:flutter_test/flutter_test.dart';
import 'package:finpilot_ai/models/finance_transaction.dart';
import 'package:finpilot_ai/providers/finance_provider.dart';
import 'package:finpilot_ai/services/storage_service.dart';

class FailingMockStorage implements StorageService {
  final Map<String, dynamic> data = {};
  bool shouldFailOnSave = false;

  @override
  Future<void> init() async {}

  @override
  String? getString(String key) => data[key] as String?;

  @override
  Future<bool> setString(String key, String value) async {
    if (shouldFailOnSave && key == 'transactions') {
      throw Exception('Simulated disk I/O / SQLite persistence failure');
    }
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
  group('FinanceProvider Accounting & Atomic Sync Tests', () {
    late FailingMockStorage storage;
    late FinanceProvider provider;

    setUp(() {
      storage = FailingMockStorage();
      // Initialize with empty transaction array to bypass demo seeding
      storage.data['transactions'] = '[]';
      provider = FinanceProvider(storage);
    });

    test('Add expense updates balance, totalExpense, and persists to storage', () async {
      final now = DateTime.now();
      expect(provider.transactions.isEmpty, isTrue);
      final initialBalance = provider.balance;

      final tx = FinanceTransaction(
        id: 'tx-101',
        title: 'Swiggy Dinner',
        merchant: 'Swiggy',
        amount: 540.0,
        category: 'Food & Dining',
        type: TransactionType.expense,
        date: now,
        paymentMethod: 'UPI',
        createdAt: now,
      );

      final success = await provider.addTransaction(tx);

      expect(success, isTrue);
      expect(provider.transactions.length, equals(1));
      expect(provider.totalExpense, equals(540.0));
      expect(provider.balance, equals(initialBalance - 540.0));
      expect(storage.data['transactions'], isNotNull);
    });

    test('Idempotency guard prevents duplicate transaction ingestion', () async {
      final fixedDate = DateTime(2026, 10, 15, 14, 30);

      final tx1 = FinanceTransaction(
        id: 'tx-201',
        title: 'Supermarket Grocery',
        merchant: 'Nature Basket',
        amount: 1250.0,
        category: 'Groceries',
        type: TransactionType.expense,
        date: fixedDate,
        paymentMethod: 'Debit Card',
        createdAt: fixedDate,
      );

      final firstSaved = await provider.addTransaction(tx1);
      expect(firstSaved, isTrue);
      expect(provider.transactions.length, equals(1));

      // Attempt to add duplicate transaction with distinct ID but identical payload
      final duplicateTx = FinanceTransaction(
        id: 'tx-202-duplicate',
        title: 'Supermarket Grocery',
        merchant: 'Nature Basket',
        amount: 1250.0,
        category: 'Groceries',
        type: TransactionType.expense,
        date: fixedDate,
        paymentMethod: 'Debit Card',
        createdAt: fixedDate.add(const Duration(seconds: 3)),
      );

      expect(provider.isDuplicateTransaction(duplicateTx), isTrue);

      final duplicateSaved = await provider.addTransaction(duplicateTx);
      expect(duplicateSaved, isFalse);
      expect(provider.transactions.length, equals(1),
          reason: 'Duplicate transaction must not be added to transaction list');
      expect(provider.totalExpense, equals(1250.0));
    });

    test('Atomic persistence rollback restores in-memory state on storage failure', () async {
      final now = DateTime.now();
      expect(provider.transactions.isEmpty, isTrue);

      // Configure storage to simulate write failure
      storage.shouldFailOnSave = true;

      final failingTx = FinanceTransaction(
        id: 'tx-301-fail',
        title: 'Hospital Bill',
        merchant: 'Apollo Clinic',
        amount: 4500.0,
        category: 'Health',
        type: TransactionType.expense,
        date: now,
        paymentMethod: 'Credit Card',
        createdAt: now,
      );

      await expectLater(
        () => provider.addTransaction(failingTx),
        throwsA(isA<Exception>()),
      );

      // Verify in-memory state was completely rolled back
      expect(provider.transactions.isEmpty, isTrue,
          reason: 'In-memory transaction list must rollback on storage error');
      expect(provider.totalExpense, equals(0.0));
    });

    test('Monthly calculation getters correctly isolate current month spending', () async {
      final currentMonthDate = DateTime.now();
      final lastMonthDate = DateTime(
        currentMonthDate.year,
        currentMonthDate.month == 1 ? 12 : currentMonthDate.month - 1,
        15,
      );

      final currentMonthTx = FinanceTransaction(
        id: 'tx-cur',
        title: 'Current Month Fuel',
        amount: 2000.0,
        category: 'Transport',
        type: TransactionType.expense,
        date: currentMonthDate,
        paymentMethod: 'UPI',
        createdAt: currentMonthDate,
      );

      final lastMonthTx = FinanceTransaction(
        id: 'tx-old',
        title: 'Old Month Fuel',
        amount: 1800.0,
        category: 'Transport',
        type: TransactionType.expense,
        date: lastMonthDate,
        paymentMethod: 'UPI',
        createdAt: lastMonthDate,
      );

      await provider.addTransaction(currentMonthTx);
      await provider.addTransaction(lastMonthTx);

      expect(provider.transactions.length, equals(2));
      expect(provider.totalExpense, equals(3800.0));
      expect(provider.monthlyExpense, equals(2000.0));
      expect(provider.monthlyCategorySpent['Transport'], equals(2000.0));
    });
  });
}
