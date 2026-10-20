import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/budget_model.dart';
import '../services/storage_service.dart';

class BudgetProvider extends ChangeNotifier {
  final StorageService _storageService;
  late BudgetModel _budget;

  BudgetProvider(this._storageService) {
    _loadFromStorage();
  }

  double get monthlyBudget => _budget.monthlyLimit;
  Map<String, double> get categoryBudgets => _budget.categoryLimits;

  double remainingBudget(double totalSpent) {
    return _budget.monthlyLimit - totalSpent;
  }

  double budgetPercentage(double totalSpent) {
    if (_budget.monthlyLimit == 0) return 0.0;
    return (totalSpent / _budget.monthlyLimit).clamp(0.0, 1.0);
  }

  String budgetStatus(double totalSpent) {
    final pct = budgetPercentage(totalSpent);
    if (pct >= 1.0) return 'Over Budget';
    if (pct >= 0.90) return 'Critical';
    if (pct >= 0.75) return 'Warning';
    if (pct >= 0.50) return 'Moderate';
    return 'Healthy';
  }

  double categorySpentLimit(String category) {
    return _budget.categoryLimits[category] ?? 0.0;
  }

  double categoryRemaining(String category, double spent) {
    final limit = categorySpentLimit(category);
    final diff = limit - spent;
    return diff > 0 ? diff : 0.0;
  }

  double categoryPercentage(String category, double spent) {
    final limit = categorySpentLimit(category);
    if (limit == 0) return 0.0;
    return (spent / limit).clamp(0.0, 1.0);
  }

  String categoryStatus(String category, double spent) {
    final pct = categoryPercentage(category, spent);
    if (pct >= 1.0) return 'Over Budget';
    if (pct >= 0.90) return 'Critical';
    if (pct >= 0.75) return 'Warning';
    if (pct >= 0.50) return 'Moderate';
    return 'Healthy';
  }

  Future<void> setMonthlyBudget(double amount) async {
    _budget = _budget.copyWith(monthlyLimit: amount);
    notifyListeners();
    await _saveToStorage();
  }

  Future<void> setCategoryBudget(String category, double amount) async {
    final updatedLimits = Map<String, double>.from(_budget.categoryLimits);
    updatedLimits[category] = amount;
    _budget = _budget.copyWith(categoryLimits: updatedLimits);
    notifyListeners();
    await _saveToStorage();
  }

  Future<void> addCategory(String category) async {
    final updatedLimits = Map<String, double>.from(_budget.categoryLimits);
    if (!updatedLimits.containsKey(category)) {
      updatedLimits[category] = 0.0;
      _budget = _budget.copyWith(categoryLimits: updatedLimits);
      notifyListeners();
      await _saveToStorage();
    }
  }

  Future<void> removeCategory(String category) async {
    final updatedLimits = Map<String, double>.from(_budget.categoryLimits);
    if (updatedLimits.containsKey(category)) {
      updatedLimits.remove(category);
      _budget = _budget.copyWith(categoryLimits: updatedLimits);
      notifyListeners();
      await _saveToStorage();
    }
  }

  Future<void> resetBudget() async {
    _setDefaultBudget();
    notifyListeners();
    await _saveToStorage();
  }

  void _setDefaultBudget() {
    _budget = BudgetModel(
      monthlyLimit: 25000.0,
      categoryLimits: {
        'Food': 6000.0,
        'Transport': 3000.0,
        'Shopping': 5000.0,
        'Bills': 8000.0,
        'Entertainment': 2000.0,
        'Health': 1000.0,
        'Education': 0.0,
        'Travel': 0.0,
        'Other': 0.0,
      },
    );
  }

  void _loadFromStorage() {
    final dataString = _storageService.getString('budget');
    if (dataString != null) {
      _budget = BudgetModel.fromJson(jsonDecode(dataString));
    } else {
      _setDefaultBudget();
      _saveToStorage();
    }
    notifyListeners();
  }

  Future<void> _saveToStorage() async {
    await _storageService.setString('budget', jsonEncode(_budget.toJson()));
  }
}
