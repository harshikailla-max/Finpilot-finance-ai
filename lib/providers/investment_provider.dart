import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/investment_model.dart';
import '../services/storage_service.dart';

class InvestmentProvider extends ChangeNotifier {
  final StorageService _storageService;
  List<InvestmentModel> _investments = [];

  InvestmentProvider(this._storageService) {
    _loadFromStorage();
  }

  List<InvestmentModel> get investments => _investments;

  double get totalInvestedAmount {
    return _investments.fold(0.0, (sum, item) => sum + item.investedAmount);
  }

  double get totalCurrentValue {
    return _investments.fold(0.0, (sum, item) => sum + item.currentValue);
  }

  double get totalReturns {
    return totalCurrentValue - totalInvestedAmount;
  }

  double get totalReturnPercentage {
    if (totalInvestedAmount == 0) return 0.0;
    return (totalReturns / totalInvestedAmount) * 100;
  }

  Future<void> addInvestment(InvestmentModel investment) async {
    _investments.add(investment);
    notifyListeners();
    await _saveToStorage();
  }

  Future<void> updateInvestment(InvestmentModel updatedInvestment) async {
    final index = _investments.indexWhere((i) => i.id == updatedInvestment.id);
    if (index != -1) {
      _investments[index] = updatedInvestment;
      notifyListeners();
      await _saveToStorage();
    }
  }

  Future<void> deleteInvestment(String id) async {
    _investments.removeWhere((i) => i.id == id);
    notifyListeners();
    await _saveToStorage();
  }

  Future<void> clearAll() async {
    _investments.clear();
    notifyListeners();
    await _saveToStorage();
  }

  void _loadFromStorage() {
    final dataString = _storageService.getString('investments');
    if (dataString != null) {
      final List<dynamic> decodedList = jsonDecode(dataString);
      _investments = decodedList
          .map((item) => InvestmentModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      _seedDemoInvestments();
    }
    notifyListeners();
  }

  Future<void> _saveToStorage() async {
    final jsonList = _investments.map((i) => i.toJson()).toList();
    await _storageService.setString('investments', jsonEncode(jsonList));
  }

  void _seedDemoInvestments() {
    final uuid = const Uuid();
    _investments = [
      InvestmentModel(
        id: uuid.v4(),
        name: 'Nifty 50 Index Fund',
        type: 'Index Fund',
        investedAmount: 15000.0,
        currentValue: 16500.0,
        date: DateTime.now().subtract(const Duration(days: 90)),
      ),
      InvestmentModel(
        id: uuid.v4(),
        name: 'SGB Gold Bond',
        type: 'Gold',
        investedAmount: 10000.0,
        currentValue: 10800.0,
        date: DateTime.now().subtract(const Duration(days: 60)),
      ),
      InvestmentModel(
        id: uuid.v4(),
        name: 'Public Provident Fund (PPF)',
        type: 'PPF',
        investedAmount: 5000.0,
        currentValue: 5150.0,
        date: DateTime.now().subtract(const Duration(days: 30)),
      ),
    ];
    _saveToStorage();
  }
}
