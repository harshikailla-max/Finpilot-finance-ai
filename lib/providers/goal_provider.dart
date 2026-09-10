import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/goal_model.dart';
import '../services/storage_service.dart';

class GoalProvider extends ChangeNotifier {
  final StorageService _storageService;
  List<GoalModel> _goals = [];

  GoalProvider(this._storageService) {
    _loadFromStorage();
  }

  List<GoalModel> get goals => _goals;

  Future<void> addGoal(GoalModel goal) async {
    _goals.add(goal);
    notifyListeners();
    await _saveToStorage();
  }

  Future<void> updateGoal(GoalModel updatedGoal) async {
    final index = _goals.indexWhere((g) => g.id == updatedGoal.id);
    if (index != -1) {
      _goals[index] = updatedGoal;
      notifyListeners();
      await _saveToStorage();
    }
  }

  Future<void> deleteGoal(String id) async {
    _goals.removeWhere((g) => g.id == id);
    notifyListeners();
    await _saveToStorage();
  }

  Future<void> addMoneyToGoal(String id, double amount) async {
    final index = _goals.indexWhere((g) => g.id == id);
    if (index != -1) {
      final goal = _goals[index];
      final newAmount = (goal.currentAmount + amount).clamp(0.0, goal.targetAmount);
      _goals[index] = goal.copyWith(currentAmount: newAmount);
      notifyListeners();
      await _saveToStorage();
    }
  }

  Future<void> clearAll() async {
    _goals.clear();
    notifyListeners();
    await _saveToStorage();
  }

  void _loadFromStorage() {
    final dataString = _storageService.getString('goals');
    if (dataString != null) {
      final List<dynamic> decodedList = jsonDecode(dataString);
      _goals = decodedList
          .map((item) => GoalModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      _seedDemoGoals();
    }
    notifyListeners();
  }

  Future<void> _saveToStorage() async {
    final jsonList = _goals.map((g) => g.toJson()).toList();
    await _storageService.setString('goals', jsonEncode(jsonList));
  }

  void _seedDemoGoals() {
    final uuid = const Uuid();
    _goals = [
      GoalModel(
        id: uuid.v4(),
        title: 'New Laptop',
        targetAmount: 80000,
        currentAmount: 45000,
        deadline: DateTime(2026, 12, 31),
        category: 'Gadgets',
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
      GoalModel(
        id: uuid.v4(),
        title: 'Emergency Fund',
        targetAmount: 50000,
        currentAmount: 20000,
        deadline: DateTime(2027, 6, 30),
        category: 'Emergency Fund',
        createdAt: DateTime.now().subtract(const Duration(days: 60)),
      ),
    ];
    _saveToStorage();
  }
}
