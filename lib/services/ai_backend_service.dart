import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/advisor_models.dart';
import '../models/ai_message_model.dart';
import '../providers/finance_provider.dart';
import '../providers/budget_provider.dart';
import '../providers/goal_provider.dart';
import '../providers/investment_provider.dart';
import '../utils/currency_formatter.dart';
import 'storage_service.dart';

class RemoteAIException implements Exception {
  final int statusCode;
  final String message;
  RemoteAIException(this.statusCode, this.message);

  @override
  String toString() => 'RemoteAIException($statusCode): $message';
}

class AICoachResult {
  final bool isSuccess;
  final String text;
  final bool isLocalFallback;
  final String? errorMessage;
  final AdvisorResponse? advisorResponse;

  const AICoachResult({
    required this.isSuccess,
    required this.text,
    this.isLocalFallback = false,
    this.errorMessage,
    this.advisorResponse,
  });

  factory AICoachResult.fromAI(String text) =>
      AICoachResult(isSuccess: true, text: text, isLocalFallback: false);

  factory AICoachResult.localFallback({
    required String text,
    AdvisorResponse? advisorResponse,
  }) =>
      AICoachResult(
        isSuccess: true,
        text: text,
        isLocalFallback: true,
        advisorResponse: advisorResponse,
      );

  factory AICoachResult.failure(String error, {bool isLocalFallback = false}) =>
      AICoachResult(isSuccess: false, text: '', errorMessage: error, isLocalFallback: isLocalFallback);
}

class AIBackendService {
  final StorageService storageService;
  bool? _serverConfiguredCache;

  AIBackendService({required this.storageService});

  /// Checks if a valid AI API key or backend endpoint is configured.
  /// On Flutter Web, server-side proxy handles GEMINI_API_KEY without exposing it to the client.
  bool get isBackendConfigured {
    if (_serverConfiguredCache != null) {
      return _serverConfiguredCache!;
    }
    final key = storageService.getString('ai_backend_api_key') ??
        const String.fromEnvironment('FINPILOT_AI_API_KEY', defaultValue: '');
    final endpoint = storageService.getString('ai_backend_endpoint') ??
        const String.fromEnvironment('FINPILOT_BACKEND_URL', defaultValue: '');
    if (kIsWeb) {
      return true;
    }
    return key.trim().isNotEmpty || endpoint.trim().isNotEmpty;
  }

  void updateServerConfigured(bool configured) {
    _serverConfiguredCache = configured;
  }

  String get configuredApiKey {
    return storageService.getString('ai_backend_api_key') ??
        const String.fromEnvironment('FINPILOT_AI_API_KEY', defaultValue: '');
  }

  String get configuredEndpoint {
    return storageService.getString('ai_backend_endpoint') ??
        const String.fromEnvironment('FINPILOT_BACKEND_URL', defaultValue: '');
  }

  /// Resolves the base URI for backend reverse proxy and API routes
  Uri get resolvedBaseUri {
    final custom = configuredEndpoint.trim();
    if (custom.isNotEmpty) {
      return Uri.parse(custom);
    }
    if (kIsWeb) {
      return Uri.base;
    }
    return Uri.parse('http://localhost:8088');
  }

  /// Safe backend-side connectivity/health test using the provider's official documented endpoint
  Future<Map<String, dynamic>> checkHealth() async {
    // 1. Try server-side health endpoint first
    try {
      final healthUri = resolvedBaseUri.resolve('/api/health');
      final response = await http
          .get(healthUri)
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final bodyStr = response.body.trim();
        if (!bodyStr.startsWith('<!DOCTYPE') && !bodyStr.startsWith('<html')) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          if (data.containsKey('configured')) {
            _serverConfiguredCache = data['configured'] == true;
            return data;
          }
        }
      }
    } catch (_) {
      // Server-side endpoint unavailable or network error
    }

    // 2. Direct client check if API key is stored locally
    final apiKey = configuredApiKey.trim();
    if (apiKey.isEmpty) {
      return {
        'configured': false,
        'provider': 'gemini',
        'model': 'gemini-flash-latest',
        'status': 'unconfigured',
        'message':
            'No AI API key is configured. FinPilot on-device deterministic intelligence engine is active.',
      };
    }

    // Direct Gemini health check to official models endpoint
    try {
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models?key=${Uri.encodeComponent(apiKey)}',
      );
      final resp = await http.get(uri).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        return {
          'configured': true,
          'status': 'ok',
          'provider': 'gemini',
          'model': 'gemini-3.5-flash-lite',
          'message':
              'Successfully connected to Google Gemini API (gemini-3.5-flash-lite).',
        };
      }
      final statusCode = resp.statusCode;
      String msg = 'HTTP $statusCode';
      try {
        final errJson = jsonDecode(resp.body) as Map<String, dynamic>;
        if (errJson['error']?['message'] != null) {
          msg = errJson['error']['message'].toString();
        }
      } catch (_) {}

      String status = 'error';
      if (statusCode == 401 || statusCode == 403) {
        status = 'auth_failed';
        msg =
            'Authentication failure (HTTP $statusCode): API key invalid, unauthorized, or Gemini API not enabled in Google Cloud Console.';
      } else if (statusCode == 429) {
        status = 'rate_limited';
        msg = 'Gemini API quota or rate limit exceeded (HTTP 429).';
      }

      return {
        'configured': true,
        'status': status,
        'statusCode': statusCode,
        'provider': 'gemini',
        'model': 'gemini-1.5-flash',
        'message': msg,
      };
    } catch (e) {
      return {
        'configured': true,
        'status': 'network_error',
        'provider': 'gemini',
        'model': 'gemini-1.5-flash',
        'message': 'Unable to connect to Google Gemini API: $e',
      };
    }
  }

  /// Builds a strictly valid multi-turn contents list for Google Gemini API:
  /// - Must start with role: 'user'
  /// - Roles must alternate: user <-> model
  /// - Merges adjacent turns with the same role
  /// - Ends with the latest query as the final 'user' turn
  static List<Map<String, dynamic>> formatGeminiContents({
    required List<AIMessageModel> chatHistory,
    required String query,
  }) {
    final rawTurns = <Map<String, dynamic>>[];
    for (final turn in chatHistory) {
      final msg = turn.message.trim();
      if (msg.isEmpty) continue;
      final role = turn.isUser ? 'user' : 'model';
      rawTurns.add({'role': role, 'text': msg});
    }

    // Drop leading model turns (e.g. initial greeting)
    while (rawTurns.isNotEmpty && rawTurns.first['role'] == 'model') {
      rawTurns.removeAt(0);
    }

    // Check if the last turn is already identical to the current query
    if (rawTurns.isNotEmpty &&
        rawTurns.last['role'] == 'user' &&
        rawTurns.last['text'] == query) {
      rawTurns.removeLast();
    }

    // Merge adjacent turns with the same role
    final mergedTurns = <Map<String, dynamic>>[];
    for (final item in rawTurns) {
      if (mergedTurns.isNotEmpty &&
          mergedTurns.last['role'] == item['role']) {
        mergedTurns.last['text'] =
            '${mergedTurns.last['text']}\n\n${item['text']}';
      } else {
        mergedTurns.add({'role': item['role'], 'text': item['text']});
      }
    }

    final contents = <Map<String, dynamic>>[];
    for (final item in mergedTurns) {
      contents.add({
        'role': item['role'],
        'parts': [
          {'text': item['text']},
        ],
      });
    }

    // Ensure alternating sequence before appending the new query
    if (contents.isNotEmpty && contents.last['role'] == 'user') {
      contents.add({
        'role': 'model',
        'parts': [
          {'text': 'Understood. How can I assist you with this?'},
        ],
      });
    }

    contents.add({
      'role': 'user',
      'parts': [
        {'text': query},
      ],
    });

    return contents;
  }

  /// Sends user query to the genuine AI model with live financial context.
  /// Handles open-ended questions across finance, tech, education, math, and general knowledge.
  Future<AICoachResult> generateAdvice({
    required String query,
    required FinanceProvider finance,
    required BudgetProvider budget,
    required GoalProvider goals,
    required InvestmentProvider investments,
    required List<AIMessageModel> chatHistory,
  }) async {
    final apiKey = configuredApiKey.trim();
    final customEndpoint = configuredEndpoint.trim();

    final financialContext = _buildFinancialContext(
      finance: finance,
      budget: budget,
      goals: goals,
      investments: investments,
    );

    // 1. Attempt server-side proxy route (/api/chat) first
    try {
      final chatUri = resolvedBaseUri.resolve('/api/chat');
      final body = jsonEncode({
        'query': query,
        'context': financialContext,
        'chatHistory': chatHistory.map((m) => m.toJson()).toList(),
        if (apiKey.isNotEmpty) 'apiKey': apiKey,
      });
      final headers = {
        'Content-Type': 'application/json',
        if (apiKey.isNotEmpty) 'X-AI-Key': apiKey,
      };
      final resp = await http
          .post(chatUri, headers: headers, body: body)
          .timeout(const Duration(seconds: 40));

      if (resp.statusCode == 200) {
        final bodyStr = resp.body.trim();
        if (bodyStr.startsWith('<!DOCTYPE') || bodyStr.startsWith('<html')) {
          // Response was HTML fallback (e.g. misrouted Vercel SPA), fall through to client direct request if key exists
        } else {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          if (data['isSuccess'] == true &&
              data['text'] != null &&
              (data['text'] as String).trim().isNotEmpty) {
            _serverConfiguredCache = true;
            return AICoachResult.fromAI(data['text'] as String);
          } else if (data['errorMessage'] != null) {
            if (data['errorType'] == 'unconfigured' && apiKey.isNotEmpty) {
              // Server has no key configured, but user has key in client storage -> fall through to direct call
            } else {
              return AICoachResult.failure(data['errorMessage'] as String);
            }
          }
        }
      } else {
        try {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          if (data['errorMessage'] != null) {
            return AICoachResult.failure(data['errorMessage'] as String);
          }
        } catch (_) {}
        return AICoachResult.failure('Server returned HTTP ${resp.statusCode}: ${resp.reasonPhrase ?? "Error"}');
      }
    } catch (_) {
      // Server not reachable or network error, fall through to client check or setup guidance
    }

    // 2. Direct client query if an API key or custom endpoint is configured in client storage
    if (apiKey.isNotEmpty || customEndpoint.isNotEmpty) {
      try {
        final remoteAnswer = await _queryRemoteModel(
          query: query,
          apiKey: apiKey,
          customEndpoint: customEndpoint,
          contextString: financialContext,
          chatHistory: chatHistory,
        );

        if (remoteAnswer != null && remoteAnswer.trim().isNotEmpty) {
          return AICoachResult.fromAI(remoteAnswer);
        }
      } on RemoteAIException catch (e) {
        String msg = e.message;
        if (e.statusCode == 401 || e.statusCode == 403) {
          msg =
              'Authentication failed (HTTP ${e.statusCode}): Gemini API key is invalid or Generative Language API is disabled.';
        } else if (e.statusCode == 429) {
          msg =
              'Gemini quota or rate limit exceeded (HTTP 429). Please wait a moment or check your Google AI account.';
        }
        return AICoachResult.failure(msg);
      } catch (e) {
        return AICoachResult.failure(
          'Network error reaching Gemini AI service: $e.\n\nPlease check your internet connection or verify your API key in Settings.',
        );
      }
    }

    // 3. Neither server nor client has a configured key
    return AICoachResult.failure(
      'Google Gemini API key is not configured.\n\n'
      'To enable the AI Coach:\n'
      '1. Get a free Gemini API key from https://aistudio.google.com/app/apikey\n'
      '2. Add GEMINI_API_KEY (or FINPILOT_AI_API_KEY)=your_key to .env in your project root and restart the server, '
      'or configure your key directly in Settings > AI Configuration.',
      isLocalFallback: true,
    );
  }

  /// Queries the remote Gemini model using official REST API
  Future<String?> _queryRemoteModel({
    required String query,
    required String apiKey,
    required String customEndpoint,
    required String contextString,
    required List<AIMessageModel> chatHistory,
  }) async {
    final Uri targetUrl;
    final Map<String, String> headers = {'Content-Type': 'application/json'};

    if (customEndpoint.isNotEmpty) {
      targetUrl = Uri.parse(customEndpoint);
      if (apiKey.isNotEmpty) {
        headers['Authorization'] = 'Bearer $apiKey';
      }
    } else {
      targetUrl = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent?key=$apiKey',
      );
    }

    final systemInstruction = '''
You are FinPilot AI Coach, an elite personal financial strategist and versatile AI advisor operating at the conversational depth, analytical brilliance, and nuanced reasoning of ChatGPT.
You are chatting with a user inside the FinPilot AI luxury personal finance platform.

You think deeply before providing each response. When asked any financial, analytical, or strategic question, reason carefully step-by-step through the underlying numbers, economic principles, tax laws, behavioral factors, and risk tradeoffs. Provide comprehensive, dynamic, personalized analysis rather than generic or fixed answers.

USER LIVE FINANCIAL SNAPSHOT:
$contextString

CORE CAPABILITIES & DIRECTIVES:
1. Deep Reasoning & Thoughtful Deliberation ("Think Before Answering"):
   - Dissect the user's inquiry systematically. Break complex trade-offs into clear logical components (e.g. Old vs New Tax Regime, Debt vs Equity asset allocation, Prepaying Home Loan vs SIP investing, Term Insurance vs ULIP).
   - Show the math: when relevant, calculate explicit numbers, compounding outcomes, tax brackets, and net cash flows.
   - Address hidden trade-offs, liquidity risks, opportunity costs, inflation impacts, and long-term consequences.

2. True Conversational Intelligence (Like ChatGPT):
   - You are not limited to canned scripts or fixed answers. Never give robotic, templated replies. Answer dynamically to what the user actually asks.
   - Handle questions across ANY topic: personal finance, macroeconomic trends, Indian & global markets, real estate, taxation, career advice, technology, startups, math, or everyday conversation.
   - Maintain multi-turn context naturally. Reference previous points discussed when relevant.

3. Context-Aware Personalization:
   - When the user asks about their own money, spending, savings, or goals, ground your answers in their live financial records above (quote exact ₹ amounts).
   - If specific personal data is missing from the snapshot, acknowledge what's missing politely and offer a well-reasoned benchmark or framework.

4. Actionable & Engaging Structure:
   - Structure answers with clean Markdown headings, bullet points, and bold emphasis.
   - Conclude complex advice with a clear, prioritized checklist of next actions.
   - Clarify that calculations and models are educational and planning estimates and do not constitute certified SEBI/CA legal advice.

5. Direct & Non-Repetitive Responses:
   - Do NOT repeat canned intros or greetings (e.g. "Hello! I am FinPilot AI Coach", "Let's break down...") on every message.
   - Do NOT regurgitate or repeat the entire user financial snapshot back to them unless they explicitly ask for a financial summary.
   - Do NOT repeat previously stated points, checklists, or standard disclaimers if already mentioned earlier in the conversation.
   - Answer ANY question directly, concisely, and progress the conversation naturally without looping or repeating yourself.
''';

    final contents = formatGeminiContents(
      chatHistory: chatHistory,
      query: query,
    );

    final requestBody = {
      'system_instruction': {
        'parts': [
          {'text': systemInstruction},
        ],
      },
      'contents': contents,
      'generationConfig': {'temperature': 0.7, 'maxOutputTokens': 2048},
    };

    final response = await http
        .post(targetUrl, headers: headers, body: jsonEncode(requestBody))
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = json['candidates'] as List<dynamic>?;
      if (candidates != null && candidates.isNotEmpty) {
        final content = candidates[0]['content'] as Map<String, dynamic>?;
        final parts = content?['parts'] as List<dynamic>?;
        if (parts != null && parts.isNotEmpty) {
          return parts[0]['text'] as String?;
        }
      }
      return null;
    } else {
      String errorMessage = 'HTTP ${response.statusCode}';
      try {
        final errJson = jsonDecode(response.body) as Map<String, dynamic>;
        if (errJson['error']?['message'] != null) {
          errorMessage = errJson['error']['message'].toString();
        }
      } catch (_) {}
      throw RemoteAIException(response.statusCode, errorMessage);
    }
  }

  /// Builds context string containing live financial metrics
  String _buildFinancialContext({
    required FinanceProvider finance,
    required BudgetProvider budget,
    required GoalProvider goals,
    required InvestmentProvider investments,
  }) {
    final income = finance.monthlyIncome;
    final expense = finance.monthlyExpense;
    final surplus = income - expense;
    final savingsRate =
        income > 0 ? ((surplus / income) * 100).clamp(-100.0, 100.0) : 0.0;
    final totalPortfolio = investments.totalCurrentValue;

    final categoriesBuffer = StringBuffer();
    finance.monthlyCategorySpent.forEach((cat, amt) {
      if (amt > 0) {
        categoriesBuffer.write('$cat: ${CurrencyFormatter.format(amt)}, ');
      }
    });

    final goalsBuffer = StringBuffer();
    for (final g in goals.goals) {
      final pct = (g.progressPercentage * 100).toStringAsFixed(0);
      goalsBuffer.write(
        '${g.title} (${CurrencyFormatter.format(g.currentAmount)} / ${CurrencyFormatter.format(g.targetAmount)} - $pct%), ',
      );
    }

    return '''
LIVE FINANCIAL RECORD SUMMARY:
- Monthly Inflows: ${CurrencyFormatter.format(income)}
- Monthly Outflows: ${CurrencyFormatter.format(expense)}
- Net Monthly Cash Flow: ${CurrencyFormatter.format(surplus)}
- Savings Rate: ${savingsRate.toStringAsFixed(1)}%
- Tracked Available Balance: ${CurrencyFormatter.format(finance.balance)}
- Total Investment Assets: ${CurrencyFormatter.format(totalPortfolio)}
- Monthly Budget Limit: ${CurrencyFormatter.format(budget.monthlyBudget)}
- Category Spending This Month: ${categoriesBuffer.toString()}
- Active Savings Goals: ${goalsBuffer.toString()}
''';
  }
}
