import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/ai_message_model.dart';
import '../models/budget_model.dart';
import '../services/ai_finance_service.dart';
import '../services/storage_service.dart';
import 'finance_provider.dart';
import 'budget_provider.dart';
import 'goal_provider.dart';

class AIProvider extends ChangeNotifier {
  final FinanceProvider financeProvider;
  final BudgetProvider budgetProvider;
  final GoalProvider goalProvider;
  final StorageService storageService;

  List<AIMessageModel> _chatMessages = [];
  bool _isTyping = false;

  AIProvider({
    required this.financeProvider,
    required this.budgetProvider,
    required this.goalProvider,
    required this.storageService,
  }) {
    financeProvider.addListener(_onDependencyChanged);
    budgetProvider.addListener(_onDependencyChanged);
    goalProvider.addListener(_onDependencyChanged);
    _loadChatFromStorage();
  }

  void _onDependencyChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    financeProvider.removeListener(_onDependencyChanged);
    budgetProvider.removeListener(_onDependencyChanged);
    goalProvider.removeListener(_onDependencyChanged);
    super.dispose();
  }

  List<AIMessageModel> get chatMessages => _chatMessages;
  bool get isTyping => _isTyping;

  List<AIInsight> get insights {
    return AIFinanceService.generateInsights(
      transactions: financeProvider.transactions,
      budget: BudgetModel(
        monthlyLimit: budgetProvider.monthlyBudget,
        categoryLimits: budgetProvider.categoryBudgets,
      ),
      goals: goalProvider.goals,
    );
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final uuid = const Uuid();
    final userMessage = AIMessageModel(
      id: uuid.v4(),
      message: text,
      isUser: true,
      timestamp: DateTime.now(),
    );

    _chatMessages.add(userMessage);
    notifyListeners();
    await _saveChatToStorage();

    _isTyping = true;
    notifyListeners();

    // Simulate AI typing delay
    await Future.delayed(const Duration(milliseconds: 800));

    final aiResponseText = AIFinanceService.generateChatResponse(
      query: text,
      transactions: financeProvider.transactions,
      budget: BudgetModel(
        monthlyLimit: budgetProvider.monthlyBudget,
        categoryLimits: budgetProvider.categoryBudgets,
      ),
      goals: goalProvider.goals,
    );

    final aiMessage = AIMessageModel(
      id: uuid.v4(),
      message: aiResponseText,
      isUser: false,
      timestamp: DateTime.now(),
    );

    _chatMessages.add(aiMessage);
    _isTyping = false;
    notifyListeners();
    await _saveChatToStorage();
  }

  Future<void> clearChat() async {
    _chatMessages.clear();
    // Re-seed welcome message
    final uuid = const Uuid();
    _chatMessages.add(
      AIMessageModel(
        id: uuid.v4(),
        message: "Hello! I am FinPilot AI, your personal finance assistant. I've analyzed your financial health, transactions, and goals. Ask me things like:\n\n- *'Where am I spending the most?'*\n- *'Am I overspending?'*\n- *'How can I save more?'*",
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
    notifyListeners();
    await _saveChatToStorage();
  }

  void _loadChatFromStorage() {
    final chatString = storageService.getString('chat_messages');
    if (chatString != null) {
      final List<dynamic> decodedList = jsonDecode(chatString);
      _chatMessages = decodedList
          .map((item) => AIMessageModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      final uuid = const Uuid();
      _chatMessages = [
        AIMessageModel(
          id: uuid.v4(),
          message: "Hello! I am FinPilot AI, your personal finance assistant. I've analyzed your financial health, transactions, and goals. Ask me things like:\n\n- *'Where am I spending the most?'*\n- *'Am I overspending?'*\n- *'How can I save more?'*",
          isUser: false,
          timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        )
      ];
    }
    notifyListeners();
  }

  Future<void> _saveChatToStorage() async {
    final jsonList = _chatMessages.map((m) => m.toJson()).toList();
    await storageService.setString('chat_messages', jsonEncode(jsonList));
  }
}
