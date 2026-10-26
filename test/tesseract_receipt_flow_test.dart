import 'package:flutter_test/flutter_test.dart';
import 'package:finpilot_ai/models/finance_transaction.dart';
import 'package:finpilot_ai/providers/finance_provider.dart';
import 'package:finpilot_ai/services/receipt_parser_service.dart';
import 'package:finpilot_ai/services/storage_service.dart';

class MockStorageService implements StorageService {
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

  int? getInt(String key) => data[key] as int?;

  Future<bool> setInt(String key, int value) async {
    data[key] = value;
    return true;
  }

  double? getDouble(String key) => data[key] as double?;

  Future<bool> setDouble(String key, double value) async {
    data[key] = value;
    return true;
  }

  List<String>? getStringList(String key) => data[key] as List<String>?;

  Future<bool> setStringList(String key, List<String> value) async {
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
  group('Tesseract Receipt Parsing & Non-Inventing Rules', () {
    test('Receipt with complete details extracts merchant, date, subtotal, tax, and total', () {
      const receiptText = '''
BLUE TOKAI COFFEE ROASTERS
Koramangala 5th Block, Bengaluru
Date: 24/10/2026
Tax Invoice: BT-8491

Flat White Double Shot   280.00
Almond Croissant         220.00

Subtotal: 500.00
CGST 2.5%: 12.50
SGST 2.5%: 12.50
Total Tax: 25.00
Grand Total: 525.00

Paid via UPI
''';

      final data = ReceiptParserService.parseReceiptText(receiptText);

      expect(data.merchant, equals('Blue Tokai'));
      expect(data.total, equals(525.00));
      expect(data.subtotal, equals(500.00));
      expect(data.tax, equals(25.00));
      expect(data.date.year, equals(2026));
      expect(data.date.month, equals(10));
      expect(data.date.day, equals(24));
      expect(data.paymentMethod, equals('UPI'));
      expect(data.isTotalUncertain, isFalse);
    });

    test('Never invents missing merchant, tax, subtotal or fake values', () {
      // Receipt without merchant header and without tax/subtotal lines
      const vagueReceipt = '''
Customer Receipt
Some Street
No: 1048

Total: 150.00
''';

      final data = ReceiptParserService.parseReceiptText(vagueReceipt);

      // Merchant should NOT be invented as "Receipt Merchant"
      expect(data.merchant, isEmpty);
      expect(data.total, equals(150.00));
      // Missing subtotal and tax should remain null (never invented!)
      expect(data.subtotal, isNull);
      expect(data.tax, isNull);
    });

    test('Never invents total if no amount or total keyword is present', () {
      const emptyReceipt = '''
Customer Receipt
Thanks for your visit
Have a great day
''';

      final data = ReceiptParserService.parseReceiptText(emptyReceipt);

      expect(data.merchant, isEmpty);
      expect(data.total, equals(0.0));
      expect(data.subtotal, isNull);
      expect(data.tax, isNull);
      expect(data.isTotalUncertain, isTrue);
    });
  });

  group('FinanceProvider Save Confirmation, Budget & Duplicate Prevention', () {
    late MockStorageService storage;
    late FinanceProvider finance;

    setUp(() {
      storage = MockStorageService();
      storage.data['transactions'] = '[]';
      finance = FinanceProvider(storage);
    });

    test('Saves expense and updates history, total expense, and balance', () async {
      final initialBalance = finance.balance;
      final initialExpenses = finance.totalExpense;

      final tx = FinanceTransaction(
        id: 'test-receipt-tx-1',
        title: 'Blue Tokai',
        amount: 525.00,
        category: 'Food & Dining',
        type: TransactionType.expense,
        date: DateTime.now(),
        merchant: 'Blue Tokai',
        paymentMethod: 'UPI',
        source: 'Receipt',
        createdAt: DateTime.now(),
      );

      final saved = await finance.addTransaction(tx);
      expect(saved, isTrue);

      // 1. Transaction appears in transaction history
      expect(finance.transactions.any((t) => t.id == 'test-receipt-tx-1'), isTrue);

      // 2. Total expenses increased
      expect(finance.totalExpense, equals(initialExpenses + 525.00));

      // 3. Balance updated
      expect(finance.balance, equals(initialBalance - 525.00));

      // 4. Duplicate prevention: exact same ID or duplicate transaction is rejected
      final duplicateSaved = await finance.addTransaction(tx);
      expect(duplicateSaved, isFalse);
    });

    test('Prevents near-duplicate transaction within same minute with same merchant and amount', () async {
      final now = DateTime(2026, 10, 24, 15, 30);
      final tx1 = FinanceTransaction(
        id: 'tx-unique-1',
        title: 'Starbucks',
        amount: 350.00,
        category: 'Food & Dining',
        type: TransactionType.expense,
        date: now,
        merchant: 'Starbucks',
        paymentMethod: 'UPI',
        source: 'Receipt',
        createdAt: now,
      );

      final tx2 = FinanceTransaction(
        id: 'tx-unique-2', // Different ID
        title: 'Starbucks',
        amount: 350.00,    // Same amount
        category: 'Food & Dining',
        type: TransactionType.expense,
        date: now,         // Same minute
        merchant: 'Starbucks', // Same merchant
        paymentMethod: 'UPI',
        source: 'Receipt',
        createdAt: now,
      );

      final firstSaved = await finance.addTransaction(tx1);
      expect(firstSaved, isTrue);

      // Attempting to add second duplicate should be blocked by FinanceProvider
      final secondSaved = await finance.addTransaction(tx2);
      expect(secondSaved, isFalse);
    });
  });
}
