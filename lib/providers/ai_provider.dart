import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/advisor_models.dart';
import '../models/ai_message_model.dart';
import '../models/budget_model.dart';
import '../services/advisor/affordability_service.dart';
import '../services/advisor/financial_dna_service.dart';
import '../services/advisor/financial_xray_service.dart';
import '../services/advisor/goal_optimizer_service.dart';
import '../services/advisor/proactive_money_moves_service.dart';
import '../services/advisor/what_if_service.dart';
import '../services/ai_backend_service.dart';
import '../services/ai_finance_service.dart';
import '../services/storage_service.dart';
import 'budget_provider.dart';
import 'finance_provider.dart';
import 'financial_health_provider.dart';
import 'goal_provider.dart';
import 'investment_provider.dart';

class AIProvider extends ChangeNotifier {
  final FinanceProvider financeProvider;
  final BudgetProvider budgetProvider;
  final GoalProvider goalProvider;
  final StorageService storageService;
  InvestmentProvider? investmentProvider;
  FinancialHealthProvider? financialHealthProvider;

  late final AIBackendService _backendService;

  List<AIMessageModel> _chatMessages = [];
  List<AdvisorResponse> _advisorResponses = [];
  bool _isTyping = false;
  String? _lastError;
  String? _lastUserQuery;

  AIProvider({
    required this.financeProvider,
    required this.budgetProvider,
    required this.goalProvider,
    required this.storageService,
    this.investmentProvider,
    this.financialHealthProvider,
  }) {
    _backendService = AIBackendService(storageService: storageService);
    financeProvider.addListener(_onDependencyChanged);
    budgetProvider.addListener(_onDependencyChanged);
    goalProvider.addListener(_onDependencyChanged);
    investmentProvider?.addListener(_onDependencyChanged);
    financialHealthProvider?.addListener(_onDependencyChanged);
    _loadChatFromStorage();
  }

  void updateProviders({
    InvestmentProvider? investment,
    FinancialHealthProvider? health,
  }) {
    if (investment != null && investment != investmentProvider) {
      investmentProvider?.removeListener(_onDependencyChanged);
      investmentProvider = investment;
      investmentProvider?.addListener(_onDependencyChanged);
    }
    if (health != null && health != financialHealthProvider) {
      financialHealthProvider?.removeListener(_onDependencyChanged);
      financialHealthProvider = health;
      financialHealthProvider?.addListener(_onDependencyChanged);
    }
    notifyListeners();
  }

  void refreshBackendConfig() {
    notifyListeners();
  }

  void _onDependencyChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    financeProvider.removeListener(_onDependencyChanged);
    budgetProvider.removeListener(_onDependencyChanged);
    goalProvider.removeListener(_onDependencyChanged);
    investmentProvider?.removeListener(_onDependencyChanged);
    financialHealthProvider?.removeListener(_onDependencyChanged);
    super.dispose();
  }

  List<AIMessageModel> get chatMessages => _chatMessages;
  List<AdvisorResponse> get advisorResponses => _advisorResponses;
  bool get isTyping => _isTyping;
  bool get isBackendConfigured => _backendService.isBackendConfigured;
  String? get lastError => _lastError;
  AIBackendService get backendService => _backendService;

  Future<Map<String, dynamic>> checkHealth() => _backendService.checkHealth();

  InvestmentProvider get _resolvedInvestments =>
      investmentProvider ?? InvestmentProvider(storageService);

  FinancialHealthProvider get resolvedHealth =>
      financialHealthProvider ??
      FinancialHealthProvider(
        financeProvider: financeProvider,
        budgetProvider: budgetProvider,
        goalProvider: goalProvider,
      );

  // Proactive Intelligence & Audits
  List<MoneyMove> get todayMoneyMoves =>
      ProactiveMoneyMovesService.generateTodayMoves(
        finance: financeProvider,
        budget: budgetProvider,
        goals: goalProvider,
        investments: _resolvedInvestments,
      );

  FinancialXRayReport get currentFinancialXRay =>
      FinancialXRayService.analyzeFinances(
        finance: financeProvider,
        budget: budgetProvider,
        goals: goalProvider,
        investments: _resolvedInvestments,
      );

  FinancialDNAProfile get currentFinancialDNA =>
      FinancialDNAService.evaluateDNA(
        finance: financeProvider,
        goals: goalProvider,
        investments: _resolvedInvestments,
      );

  GoalOptimizationResult get currentGoalOptimization =>
      GoalOptimizerService.optimizeGoals(
        goalProvider: goalProvider,
        finance: financeProvider,
      );

  AffordabilityAnalysis evaluatePurchase({
    required String product,
    required double price,
    String? timeframe,
  }) => AffordabilityService.evaluatePurchase(
    product: product,
    price: price,
    timeframe: timeframe,
    finance: financeProvider,
    budget: budgetProvider,
    goals: goalProvider,
  );

  WhatIfScenarioResult simulateScenario({
    double incomeDelta = 0.0,
    double expenseDelta = 0.0,
    double newRecurringEmi = 0.0,
    double oneTimeCost = 0.0,
    String? scenarioDescription,
  }) => WhatIfService.simulateScenario(
    finance: financeProvider,
    incomeDelta: incomeDelta,
    expenseDelta: expenseDelta,
    newRecurringEmi: newRecurringEmi,
    oneTimeCost: oneTimeCost,
    scenarioDescription: scenarioDescription,
  );

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
    final clean = text.trim();
    if (clean.isEmpty) return;
    if (_isTyping) return; // Prevent duplicate submissions

    _lastUserQuery = clean;
    _lastError = null;

    final uuid = const Uuid();
    final userMessage = AIMessageModel(
      id: uuid.v4(),
      message: clean,
      isUser: true,
      timestamp: DateTime.now(),
    );

    // Snapshot prior history so the query is not duplicated in turns
    final priorHistory = List<AIMessageModel>.from(_chatMessages);
    _chatMessages.add(userMessage);
    _isTyping = true;
    notifyListeners();
    await _saveChatToStorage();

    try {
      final aiResult = await _backendService.generateAdvice(
        query: clean,
        finance: financeProvider,
        budget: budgetProvider,
        goals: goalProvider,
        investments: _resolvedInvestments,
        chatHistory: priorHistory,
      );

      if (aiResult.advisorResponse != null) {
        _advisorResponses.add(aiResult.advisorResponse!);
      }

      if (aiResult.isSuccess) {
        final aiMessage = AIMessageModel(
          id: uuid.v4(),
          message: aiResult.text,
          isUser: false,
          timestamp: DateTime.now(),
        );
        _chatMessages.add(aiMessage);
        _lastError = null;
      } else {
        if (aiResult.isLocalFallback && aiResult.errorMessage != null) {
          _chatMessages.add(
            AIMessageModel(
              id: uuid.v4(),
              message: aiResult.errorMessage!,
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
          _lastError = null;
        } else {
          _lastError =
              aiResult.errorMessage ?? 'Unable to process query. Please retry.';
        }
      }
    } catch (e) {
      _lastError = 'An error occurred while analyzing: $e';
    } finally {
      _isTyping = false;
      notifyListeners();
      await _saveChatToStorage();
    }
  }

  Future<void> retryLastMessage() async {
    if (_isTyping) return; // Prevent duplicate retry calls
    if (_lastUserQuery == null || _lastUserQuery!.isEmpty) return;
    final query = _lastUserQuery!;
    _lastError = null;
    _isTyping = true;
    notifyListeners();

    // Prior history is all messages prior to the last user query
    final priorHistory = _chatMessages.isNotEmpty && _chatMessages.last.isUser
        ? _chatMessages.sublist(0, _chatMessages.length - 1)
        : List<AIMessageModel>.from(_chatMessages);

    try {
      final aiResult = await _backendService.generateAdvice(
        query: query,
        finance: financeProvider,
        budget: budgetProvider,
        goals: goalProvider,
        investments: _resolvedInvestments,
        chatHistory: priorHistory,
      );

      if (aiResult.advisorResponse != null) {
        _advisorResponses.add(aiResult.advisorResponse!);
      }

      if (aiResult.isSuccess) {
        final aiMessage = AIMessageModel(
          id: const Uuid().v4(),
          message: aiResult.text,
          isUser: false,
          timestamp: DateTime.now(),
        );
        _chatMessages.add(aiMessage);
        _lastError = null;
      } else {
        if (aiResult.isLocalFallback && aiResult.errorMessage != null) {
          _chatMessages.add(
            AIMessageModel(
              id: const Uuid().v4(),
              message: aiResult.errorMessage!,
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
          _lastError = null;
        } else {
          _lastError =
              aiResult.errorMessage ??
              'Failed to complete request. Please retry.';
        }
      }
    } catch (e) {
      _lastError = 'Retry failed: $e';
    } finally {
      _isTyping = false;
      notifyListeners();
      await _saveChatToStorage();
    }
  }

  Future<void> clearChat() async {
    _chatMessages.clear();
    _advisorResponses.clear();
    _lastError = null;
    _lastUserQuery = null;
    _seedWelcome();
    notifyListeners();
    await _saveChatToStorage();
  }

  void _seedWelcome() {
    final uuid = const Uuid();
    _chatMessages.add(
      AIMessageModel(
        id: uuid.v4(),
        message:
            "Greetings! I am FinPilot AI Coach, your personal financial assistant. I have continuous visibility into your live cash flow, active budgets, savings goals, and portfolio allocation.\n\n"
            "You can ask me open-ended questions across personal finance, wealth creation, tax concepts, technology, business, or general knowledge.\n\n"
            "How can I assist you today?",
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  void _loadChatFromStorage() {
    final chatString = storageService.getString('chat_messages');
    final responsesString = storageService.getString('advisor_responses');

    if (chatString != null) {
      try {
        final List<dynamic> decodedList = jsonDecode(chatString);
        _chatMessages = decodedList
            .map(
              (item) => AIMessageModel.fromJson(item as Map<String, dynamic>),
            )
            .toList();
      } catch (_) {
        _chatMessages = [];
      }
    }

    if (responsesString != null) {
      try {
        final List<dynamic> decodedList = jsonDecode(responsesString);
        _advisorResponses = decodedList
            .map(
              (item) => AdvisorResponse.fromJson(item as Map<String, dynamic>),
            )
            .toList();
      } catch (_) {
        _advisorResponses = [];
      }
    }

    if (_chatMessages.isEmpty) {
      _seedWelcome();
    }

    notifyListeners();
  }

  Future<void> _saveChatToStorage() async {
    final jsonList = _chatMessages.map((m) => m.toJson()).toList();
    final respList = _advisorResponses.map((r) => r.toJson()).toList();
    await storageService.setString('chat_messages', jsonEncode(jsonList));
    await storageService.setString('advisor_responses', jsonEncode(respList));
  }
}
