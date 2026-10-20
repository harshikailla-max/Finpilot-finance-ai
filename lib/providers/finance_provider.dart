import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/finance_transaction.dart';
import '../services/storage_service.dart';

class FinanceProvider extends ChangeNotifier {
  final StorageService _storageService;
  List<FinanceTransaction> _transactions = [];

  FinanceProvider(this._storageService) {
    _loadFromStorage();
  }

  List<FinanceTransaction> get transactions => List.unmodifiable(_transactions);

  // Global calculations (tracked / app-recorded)
  double get totalIncome {
    return _transactions
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  double get totalExpense {
    return _transactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  /// App-recorded available liquid balance
  double get balance => totalIncome - totalExpense;
  double get savings => totalIncome - totalExpense;

  // Monthly calculations (current month)
  double get monthlyIncome {
    final now = DateTime.now();
    return getIncomeForMonth(now.year, now.month);
  }

  double get monthlyExpense {
    final now = DateTime.now();
    return getExpenseForMonth(now.year, now.month);
  }

  double get monthlySavings => monthlyIncome - monthlyExpense;

  // Category specific spent values for current month
  Map<String, double> get monthlyCategorySpent {
    final now = DateTime.now();
    return getCategorySpentForMonth(now.year, now.month);
  }

  // Filter calculations by month
  double getIncomeForMonth(int year, int month) {
    return _transactions
        .where(
          (t) =>
              t.type == TransactionType.income &&
              t.date.year == year &&
              t.date.month == month,
        )
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  double getExpenseForMonth(int year, int month) {
    return _transactions
        .where(
          (t) =>
              t.type == TransactionType.expense &&
              t.date.year == year &&
              t.date.month == month,
        )
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  Map<String, double> getCategorySpentForMonth(int year, int month) {
    final Map<String, double> categoryMap = {};
    for (var tx in _transactions) {
      if (tx.type == TransactionType.expense &&
          tx.date.year == year &&
          tx.date.month == month) {
        categoryMap[tx.category] =
            (categoryMap[tx.category] ?? 0.0) + tx.amount;
      }
    }
    return categoryMap;
  }

  /// Returns transactions within a date range [start, end] inclusive
  List<FinanceTransaction> getTransactionsForRange(DateTime start, DateTime end) {
    return _transactions.where((t) {
      final date = t.date;
      return (date.isAfter(start) || date.isAtSameMomentAs(start)) &&
          (date.isBefore(end) || date.isAtSameMomentAs(end));
    }).toList();
  }

  /// Checks if an identical transaction already exists (idempotency guard)
  bool isDuplicateTransaction(FinanceTransaction tx) {
    return _transactions.any((t) {
      final tDesc = (t.merchant.isNotEmpty ? t.merchant : t.title).trim().toLowerCase();
      final txDesc = (tx.merchant.isNotEmpty ? tx.merchant : tx.title).trim().toLowerCase();

      return t.id == tx.id ||
          (t.type == tx.type &&
              t.amount == tx.amount &&
              tDesc == txDesc &&
              t.date.year == tx.date.year &&
              t.date.month == tx.date.month &&
              t.date.day == tx.date.day &&
              t.date.hour == tx.date.hour &&
              t.date.minute == tx.date.minute);
    });
  }

  // Add Transaction with strict idempotency and rollback on storage failure
  Future<bool> addTransaction(FinanceTransaction tx) async {
    // 1. Idempotency check: don't add duplicate by ID
    if (_transactions.any((t) => t.id == tx.id)) {
      return false;
    }

    // 2. Near-duplicate check within same minute
    if (isDuplicateTransaction(tx)) {
      return false;
    }

    _transactions.add(tx);
    _transactions.sort((a, b) => b.date.compareTo(a.date));

    // 3. Atomically persist to storage before notifying listeners
    try {
      await _saveToStorage();
      notifyListeners();
      return true;
    } catch (e) {
      // 4. Critical rollback rule: revert in-memory change if save failed!
      _transactions.removeWhere((t) => t.id == tx.id);
      rethrow;
    }
  }

  // Update Transaction
  Future<void> updateTransaction(FinanceTransaction updatedTx) async {
    final index = _transactions.indexWhere((t) => t.id == updatedTx.id);
    if (index != -1) {
      final originalTx = _transactions[index];
      _transactions[index] = updatedTx;
      _transactions.sort((a, b) => b.date.compareTo(a.date));

      try {
        await _saveToStorage();
        notifyListeners();
      } catch (e) {
        _transactions[index] = originalTx;
        rethrow;
      }
    }
  }

  // Delete Transaction
  Future<void> deleteTransaction(String id) async {
    final index = _transactions.indexWhere((t) => t.id == id);
    if (index != -1) {
      final removed = _transactions.removeAt(index);
      try {
        await _saveToStorage();
        notifyListeners();
      } catch (e) {
        _transactions.insert(index, removed);
        rethrow;
      }
    }
  }

  // Reset Application Data
  Future<void> clearAll() async {
    final backup = List<FinanceTransaction>.from(_transactions);
    _transactions.clear();
    try {
      await _saveToStorage();
      notifyListeners();
    } catch (e) {
      _transactions = backup;
      rethrow;
    }
  }

  // Load from Storage
  void _loadFromStorage() {
    final dataString = _storageService.getString('transactions');
    if (dataString != null) {
      final List<dynamic> decodedList = jsonDecode(dataString);
      _transactions = decodedList
          .map(
            (item) => FinanceTransaction.fromJson(item as Map<String, dynamic>),
          )
          .toList();
      _transactions.sort((a, b) => b.date.compareTo(a.date));
    } else {
      // First Launch - Seed realistic Demo Data
      _seedDemoData();
    }
    notifyListeners();
  }

  // Save to Storage
  Future<void> _saveToStorage() async {
    final jsonList = _transactions.map((t) => t.toJson()).toList();
    await _storageService.setString('transactions', jsonEncode(jsonList));
  }

  // Demo seeding
  void _seedDemoData() {
    final now = DateTime.now();
    final uuid = const Uuid();

    _transactions = [
      FinanceTransaction(
        id: uuid.v4(),
        title: 'Monthly Salary',
        amount: 65000,
        category: 'Salary',
        type: TransactionType.income,
        date: DateTime(now.year, now.month, 1, 10, 0),
        paymentMethod: 'Bank',
        createdAt: DateTime.now(),
      ),
      FinanceTransaction(
        id: uuid.v4(),
        title: 'Freelance Project',
        amount: 12000,
        category: 'Freelance',
        type: TransactionType.income,
        date: DateTime(now.year, now.month, 15, 14, 30),
        paymentMethod: 'UPI',
        createdAt: DateTime.now(),
      ),
      FinanceTransaction(
        id: uuid.v4(),
        title: 'Swiggy',
        amount: 450,
        category: 'Food',
        type: TransactionType.expense,
        date: DateTime(now.year, now.month, 2, 20, 15),
        paymentMethod: 'UPI',
        merchant: 'Swiggy',
        createdAt: DateTime.now(),
      ),
      FinanceTransaction(
        id: uuid.v4(),
        title: 'Uber',
        amount: 280,
        category: 'Transport',
        type: TransactionType.expense,
        date: DateTime(now.year, now.month, 3, 9, 45),
        paymentMethod: 'UPI',
        merchant: 'Uber',
        createdAt: DateTime.now(),
      ),
      FinanceTransaction(
        id: uuid.v4(),
        title: 'Netflix Subscription',
        amount: 649,
        category: 'Entertainment',
        type: TransactionType.expense,
        date: DateTime(now.year, now.month, 5, 0, 5),
        paymentMethod: 'Credit Card',
        merchant: 'Netflix',
        isRecurring: true,
        createdAt: DateTime.now(),
      ),
      FinanceTransaction(
        id: uuid.v4(),
        title: 'Groceries',
        amount: 3500,
        category: 'Food',
        type: TransactionType.expense,
        date: DateTime(now.year, now.month, 8, 11, 30),
        paymentMethod: 'UPI',
        merchant: 'Reliance Fresh',
        createdAt: DateTime.now(),
      ),
      FinanceTransaction(
        id: uuid.v4(),
        title: 'Electricity Bill',
        amount: 1500,
        category: 'Bills',
        type: TransactionType.expense,
        date: DateTime(now.year, now.month, 10, 16, 0),
        paymentMethod: 'Bank',
        merchant: 'State Electricity Board',
        createdAt: DateTime.now(),
      ),
      FinanceTransaction(
        id: uuid.v4(),
        title: 'Amazon Shopping',
        amount: 2200,
        category: 'Shopping',
        type: TransactionType.expense,
        date: DateTime(now.year, now.month, 12, 18, 20),
        paymentMethod: 'Credit Card',
        merchant: 'Amazon',
        createdAt: DateTime.now(),
      ),
      FinanceTransaction(
        id: uuid.v4(),
        title: 'Zara Clothing',
        amount: 4000,
        category: 'Shopping',
        type: TransactionType.expense,
        date: DateTime(now.year, now.month, 18, 15, 0),
        paymentMethod: 'Debit Card',
        merchant: 'Zara',
        createdAt: DateTime.now(),
      ),
    ];
    _transactions.sort((a, b) => b.date.compareTo(a.date));
    _saveToStorage();
  }
}
