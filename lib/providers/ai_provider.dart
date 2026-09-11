import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/advisor_models.dart';
import '../models/ai_message_model.dart';
import '../models/budget_model.dart';
import '../services/advisor/advisor_engine.dart';
import '../services/advisor/affordability_service.dart';
import '../services/advisor/financial_dna_service.dart';
import '../services/advisor/financial_xray_service.dart';
import '../services/advisor/goal_optimizer_service.dart';
import '../services/advisor/proactive_money_moves_service.dart';
import '../services/advisor/what_if_service.dart';
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

  final AdvisorEngine _advisorEngine = AdvisorEngine();

  List<AIMessageModel> _chatMessages = [];
  List<AdvisorResponse> _advisorResponses = [];
  bool _isTyping = false;

  AIProvider({
    required this.financeProvider,
    required this.budgetProvider,
    required this.goalProvider,
    required this.storageService,
    this.investmentProvider,
    this.financialHealthProvider,
  }) {
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

  InvestmentProvider get _resolvedInvestments =>
      investmentProvider ?? InvestmentProvider(storageService);

  FinancialHealthProvider get _resolvedHealth =>
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
  }) =>
      AffordabilityService.evaluatePurchase(
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
  }) =>
      WhatIfService.simulateScenario(
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

    // Subtle AI reasoning delay
    await Future.delayed(const Duration(milliseconds: 600));

    // Execute the 16-stage Financial Advisor Brain pipeline
    final advisorResponse = _advisorEngine.evaluate(
      query: text,
      finance: financeProvider,
      budget: budgetProvider,
      goals: goalProvider,
      investments: _resolvedInvestments,
      health: _resolvedHealth,
    );

    _advisorResponses.add(advisorResponse);

    // Also populate standard conversational fallback for chat view
    final summaryText =
        '**${advisorResponse.verdict}**\n\n${advisorResponse.reasoning}\n\n*Action:* ${advisorResponse.nextAction}';

    final aiMessage = AIMessageModel(
      id: advisorResponse.id,
      message: summaryText,
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
    _advisorResponses.clear();
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
            "Greetings. I am FinPilot AI, your Private Financial Intelligence Advisor. I monitor your live cash flow, active goals, asset allocation, and emergency reserves.\n\nAsk me about purchases, goal acceleration, debt repayment, or request a complete Financial X-Ray.",
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
            .map((item) => AIMessageModel.fromJson(item as Map<String, dynamic>))
            .toList();
      } catch (_) {
        _chatMessages = [];
      }
    }

    if (responsesString != null) {
      try {
        final List<dynamic> decodedList = jsonDecode(responsesString);
        _advisorResponses = decodedList
            .map((item) => AdvisorResponse.fromJson(item as Map<String, dynamic>))
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
