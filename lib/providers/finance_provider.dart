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

  List<FinanceTransaction> get transactions => _transactions;

  // Global calculations
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

  double get balance => totalIncome - totalExpense;
  double get savings => totalIncome - totalExpense;

  // Monthly calculations (current month)
  double get monthlyIncome {
    final now = DateTime.now();
    return _transactions
        .where((t) =>
            t.type == TransactionType.income &&
            t.date.year == now.year &&
            t.date.month == now.month)
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  double get monthlyExpense {
    final now = DateTime.now();
    return _transactions
        .where((t) =>
            t.type == TransactionType.expense &&
            t.date.year == now.year &&
            t.date.month == now.month)
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  double get monthlySavings => monthlyIncome - monthlyExpense;

  // Category specific spent values for current month
  Map<String, double> get monthlyCategorySpent {
    final now = DateTime.now();
    final Map<String, double> categoryMap = {};

    for (var tx in _transactions) {
      if (tx.type == TransactionType.expense &&
          tx.date.year == now.year &&
          tx.date.month == now.month) {
        categoryMap[tx.category] = (categoryMap[tx.category] ?? 0.0) + tx.amount;
      }
    }
    return categoryMap;
  }

  // Add Transaction
  Future<void> addTransaction(FinanceTransaction tx) async {
    _transactions.add(tx);
    // Sort transactions by date descending
    _transactions.sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();
    await _saveToStorage();
  }

  // Update Transaction
  Future<void> updateTransaction(FinanceTransaction updatedTx) async {
    final index = _transactions.indexWhere((t) => t.id == updatedTx.id);
    if (index != -1) {
      _transactions[index] = updatedTx;
      _transactions.sort((a, b) => b.date.compareTo(a.date));
      notifyListeners();
      await _saveToStorage();
    }
  }

  // Delete Transaction
  Future<void> deleteTransaction(String id) async {
    _transactions.removeWhere((t) => t.id == id);
    notifyListeners();
    await _saveToStorage();
  }

  // Reset Application Data
  Future<void> clearAll() async {
    _transactions.clear();
    notifyListeners();
    await _saveToStorage();
  }

  // Load from Storage
  void _loadFromStorage() {
    final dataString = _storageService.getString('transactions');
    if (dataString != null) {
      final List<dynamic> decodedList = jsonDecode(dataString);
      _transactions = decodedList
          .map((item) => FinanceTransaction.fromJson(item as Map<String, dynamic>))
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
