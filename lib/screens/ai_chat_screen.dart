import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/advisor_models.dart';
import '../models/ai_message_model.dart';
import '../providers/ai_provider.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';
import '../utils/currency_formatter.dart';
import '../widgets/aura/aura_background.dart';
import '../widgets/aura/aura_glass_card.dart';
import '../widgets/aura/aura_orb.dart';
import 'analytics_screen.dart';
import 'budget_screen.dart';
import 'goals_screen.dart';
import 'investment_screen.dart';
import 'receipt_scanner_screen.dart';

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final TextEditingController _queryController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom(animated: false);
      context.read<AIProvider>().checkHealth().then((_) {
        if (mounted) setState(() {});
      });
    });
  }

  @override
  void dispose() {
    _queryController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _submitQuery(String text) async {
    final clean = text.trim();
    if (clean.isEmpty) return;
    final ai = context.read<AIProvider>();
    if (ai.isTyping) return;
    _queryController.clear();

    await ai.sendMessage(clean);
    _scrollToBottom();
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        if (animated) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOut,
          );
        } else {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      }
    });
  }

  void _navigateToRoute(String? route) {
    if (route == null) return;
    Widget target;
    switch (route) {
      case 'goals':
        target = const GoalsScreen();
        break;
      case 'budget':
        target = const BudgetScreen();
        break;
      case 'investments':
        target = const InvestmentScreen();
        break;
      case 'receipt':
        target = const ReceiptScannerScreen();
        break;
      case 'analytics':
        target = const AnalyticsScreen();
        break;
      case 'xray':
        _showFullXRayModal();
        return;
      case 'simulator':
        _showWhatIfModal();
        return;
      default:
        return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => target));
  }

  @override
  Widget build(BuildContext context) {
    final aiProvider = context.watch<AIProvider>();
    final xray = aiProvider.currentFinancialXRay;
    final messages = aiProvider.chatMessages;
    final bool hasUserSentMessage = messages.any((m) => m.isUser);

    return Scaffold(
      backgroundColor: AppColors.obsidian,
      resizeToAvoidBottomInset: true,
      body: AuraBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(aiProvider, xray),
              Expanded(
                child: GestureDetector(
                  onTap: () => FocusScope.of(context).unfocus(),
                  child: ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    children: [
                      // Before first user message: show welcome hero and prominent suggestion chips
                      if (!hasUserSentMessage) ...[
                        _buildWelcomeHeroCard(xray),
                        const SizedBox(height: 18),
                        _buildInitialSuggestionChipsSection(),
                        const SizedBox(height: 18),
                      ],

                      // Chat Messages list
                      ...messages.map(
                        (msg) => _buildMessageBubble(msg, aiProvider),
                      ),

                      // Typing indicator
                      if (aiProvider.isTyping) _buildTypingIndicator(),

                      // Error and retry state
                      if (aiProvider.lastError != null)
                        _buildErrorCard(aiProvider),

                      const SizedBox(height: 14),
                    ],
                  ),
                ),
              ),

              // Persistent quick chips bar above composer
              _buildHorizontalQuickChipsBar(),

              // Input composer bar
              _buildInputComposer(aiProvider),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================
  Widget _buildHeader(AIProvider aiProvider, FinancialXRayReport xray) {
    final isConfigured = aiProvider.isBackendConfigured;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.obsidian.withValues(alpha: 0.85),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          FinPilotAuraOrb(
            size: 32,
            state: aiProvider.isTyping
                ? AuraOrbState.thinking
                : AuraOrbState.idle,
            showOuterHalo: false,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text(
                      'AI Coach',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'FINPILOT',
                      style: TextStyle(
                        color: AppColors.auroraCyan,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: _showHealthCheckModal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isConfigured
                              ? AppColors.success
                              : AppColors.auroraCyan,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isConfigured
                            ? 'Gemini AI Ready • Tap to Test'
                            : 'Local Intelligence Active • Tap to Test',
                        style: TextStyle(
                          color: isConfigured
                              ? AppColors.success
                              : AppColors.textSecondary,
                          fontSize: 10.5,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Health score pill
          GestureDetector(
            onTap: _showFullXRayModal,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.auroraViolet.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.shield_rounded,
                    color: AppColors.auroraCyan,
                    size: 14,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${xray.overallScore.toStringAsFixed(0)}/100',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: () => context.read<AIProvider>().clearChat(),
            icon: const Icon(
              Icons.refresh_rounded,
              color: AppColors.textSecondary,
              size: 20,
            ),
            tooltip: 'Reset Conversation',
          ),
        ],
      ),
    );
  }

  // ============================================================
  // WELCOME HERO CARD
  // ============================================================
  Widget _buildWelcomeHeroCard(FinancialXRayReport xray) {
    return AuraGlassCard(
      level: AuraGlassLevel.level3,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          FinPilotAuraOrb(
            size: 52,
            state: AuraOrbState.speaking,
            showOuterHalo: true,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Private AI Coach',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Continuous cash flow audit active. Operating at ${xray.rating.toLowerCase()} financial health.',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // INITIAL PROMINENT SUGGESTION CHIPS (BEFORE 1ST MESSAGE)
  // ============================================================
  Widget _buildInitialSuggestionChipsSection() {
    final suggestions = [
      {
        'label': 'Tax Regime Audit (Old vs New)',
        'desc': 'Budget 2024 slabs, ₹75k standard deduction & breakeven math',
        'icon': Icons.account_balance_wallet_outlined,
        'query': 'Which tax regime should I choose (Old vs New)?',
      },
      {
        'label': 'Prepay Home Loan vs Equity SIP',
        'desc': '8.5% loan vs 12% equity CAGR opportunity cost audit',
        'icon': Icons.home_work_outlined,
        'query': 'Should I prepay my home loan or invest in mutual funds?',
      },
      {
        'label': 'Calculate Retirement (FIRE)',
        'desc': '30× annual expenses rule adjusted for 6% inflation',
        'icon': Icons.beach_access_outlined,
        'query': 'How much do I need to retire?',
      },
      {
        'label': 'Can I Afford This Purchase?',
        'desc': 'Audit liquid runway impact before buying',
        'icon': Icons.shopping_bag_outlined,
        'query': 'Can I afford to buy an iPhone for ₹80,000?',
      },
      {
        'label': 'Analyze My Spending',
        'desc': 'Deep-dive into highest categories & burn rate',
        'icon': Icons.insights_rounded,
        'query': 'Analyze my spending and show where my money is going',
      },
      {
        'label': 'Check Budget Overspending',
        'desc': 'Review category limits & current utilization',
        'icon': Icons.pie_chart_outline_rounded,
        'query': 'Check my budget status and alert me to any overspending',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'WHAT WOULD YOU LIKE TO EXPLORE?',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10.5,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        ...suggestions.map(
          (s) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _submitQuery(s['query'] as String),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.auroraViolet.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          s['icon'] as IconData,
                          color: AppColors.auroraCyan,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s['label'] as String,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              s['desc'] as String,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: AppColors.textMuted,
                        size: 12,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // MESSAGE BUBBLES (USER & ASSISTANT)
  // ============================================================
  Widget _buildMessageBubble(AIMessageModel msg, AIProvider aiProvider) {
    if (msg.isUser) {
      return _buildUserBubble(msg);
    }
    return _buildAssistantBubble(msg, aiProvider);
  }

  Widget _buildUserBubble(AIMessageModel msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const SizedBox(width: 48),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.secondaryBackground,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(4),
                ),
                border: Border.all(
                  color: AppColors.auroraCyan.withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    msg.message,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13.5,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('h:mm a').format(msg.timestamp),
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 9.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.cardBackground,
            ),
            child: const Icon(
              Icons.person_rounded,
              color: AppColors.auroraCyan,
              size: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssistantBubble(AIMessageModel msg, AIProvider aiProvider) {
    // Check if there is a matching advisor response with structured card payload
    AdvisorResponse? matchingResponse;
    for (final r in aiProvider.advisorResponses.reversed) {
      if (r.id == msg.id || msg.message.contains(r.verdict)) {
        matchingResponse = r;
        break;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FinPilotAuraOrb(
            size: 26,
            state: AuraOrbState.idle,
            showOuterHalo: false,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardBackground.withValues(alpha: 0.95),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                border: Border.all(
                  color: AppColors.auroraViolet.withValues(alpha: 0.2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Bot label
                  const Row(
                    children: [
                      Text(
                        'FINPILOT AI',
                        style: TextStyle(
                          color: AppColors.auroraCyan,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Markdown Body
                  MarkdownBody(
                    data: msg.message,
                    styleSheet: MarkdownStyleSheet(
                      p: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13.5,
                        height: 1.45,
                      ),
                      h1: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      h2: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      h3: const TextStyle(
                        color: AppColors.auroraCyan,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      strong: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      em: const TextStyle(
                        color: AppColors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                      listBullet: const TextStyle(
                        color: AppColors.auroraCyan,
                        fontSize: 13,
                      ),
                      blockquoteDecoration: BoxDecoration(
                        color: AppColors.secondaryBackground,
                        borderRadius: BorderRadius.circular(8),
                        border: const Border(
                          left: BorderSide(
                            color: AppColors.auroraCyan,
                            width: 3,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // If matched response has an interactive action route
                  if (matchingResponse != null &&
                      matchingResponse.actionRoute != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.touch_app_rounded,
                            color: AppColors.auroraCyan,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              matchingResponse.nextAction,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () =>
                                _navigateToRoute(matchingResponse!.actionRoute),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.auroraViolet,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Open',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      DateFormat('h:mm a').format(msg.timestamp),
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 9.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TYPING & ERROR STATES
  // ============================================================
  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(left: 36, bottom: 12),
      child: Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.auroraCyan,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Analyzing cash flow, budget limits, and risk parameters...',
            style: TextStyle(
              color: AppColors.auroraCyan.withValues(alpha: 0.8),
              fontSize: 11.5,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(AIProvider aiProvider) {
    return Container(
      margin: const EdgeInsets.only(left: 36, bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.danger,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              aiProvider.lastError ?? 'Unable to process question.',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          ElevatedButton(
            onPressed: _showConfigureKeyDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.auroraCyan,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Set Key',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 6),
          ElevatedButton(
            onPressed: () => aiProvider.retryLastMessage(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.auroraViolet,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Retry',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HORIZONTAL QUICK CHIPS BAR
  // ============================================================
  Widget _buildHorizontalQuickChipsBar() {
    final chips = [
      {
        'label': 'Analyze Spending',
        'icon': Icons.insights_rounded,
        'query': 'Where am I spending the most?',
      },
      {
        'label': 'Save More',
        'icon': Icons.savings_outlined,
        'query': 'How can I save more this month?',
      },
      {
        'label': 'Check Budget',
        'icon': Icons.pie_chart_outline,
        'query': 'Am I overspending against my budget?',
      },
      {
        'label': 'Review Goals',
        'icon': Icons.flag_outlined,
        'query': 'Can I reach my savings goals on time?',
      },
      {
        'label': 'Affordability',
        'icon': Icons.shopping_bag_outlined,
        'action': () => _showPurchaseAnalyzerModal(),
      },
      {
        'label': 'Financial X-Ray',
        'icon': Icons.biotech_outlined,
        'action': () => _showFullXRayModal(),
      },
      {
        'label': 'What-If Simulator',
        'icon': Icons.tune_rounded,
        'action': () => _showWhatIfModal(),
      },
    ];

    return Container(
      height: 38,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final c = chips[index];
          return ActionChip(
            avatar: Icon(
              c['icon'] as IconData,
              color: AppColors.auroraCyan,
              size: 13,
            ),
            label: Text(
              c['label'] as String,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            backgroundColor: AppColors.cardBackground,
            side: BorderSide(
              color: AppColors.auroraViolet.withValues(alpha: 0.25),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            onPressed: () {
              if (c.containsKey('action')) {
                (c['action'] as VoidCallback)();
              } else {
                _submitQuery(c['query'] as String);
              }
            },
          );
        },
      ),
    );
  }

  // ============================================================
  // NATURAL LANGUAGE INPUT COMPOSER
  // ============================================================
  Widget _buildInputComposer(AIProvider aiProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _queryController,
              focusNode: _inputFocusNode,
              style: const TextStyle(color: Colors.white, fontSize: 13.5),
              onSubmitted: _submitQuery,
              decoration: InputDecoration(
                hintText: 'Ask FinPilot about spending, budgets, goals...',
                hintStyle: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                ),
                filled: true,
                fillColor: AppColors.secondaryBackground,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(
                    color: AppColors.auroraCyan,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Opacity(
            opacity: aiProvider.isTyping ? 0.35 : 1.0,
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppColors.auroraViolet, AppColors.auroraCyan],
                ),
              ),
              child: IconButton(
                onPressed: aiProvider.isTyping
                    ? null
                    : () => _submitQuery(_queryController.text),
                icon: const Icon(
                  Icons.arrow_upward_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // INTERACTIVE MODALS (PURCHASE ANALYZER, WHAT-IF, X-RAY)
  // ============================================================
  void _showPurchaseAnalyzerModal() {
    final productCtrl = TextEditingController(text: 'MacBook Pro');
    final priceCtrl = TextEditingController(text: '120000');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Purchase Decision Analyzer',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(
                      Icons.close,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: productCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Product / Item Name',
                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.secondaryBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Target Price (\u20B9)',
                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.secondaryBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    final p = productCtrl.text.trim();
                    final amt = priceCtrl.text.trim();
                    Navigator.pop(ctx);
                    _submitQuery('Can I afford to buy $p for \u20B9$amt?');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.auroraViolet,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Run Affordability Analysis',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showWhatIfModal() {
    double incomeDelta = 15000;
    double expenseCut = 5000;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'What-If Scenario Engine',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(
                          Icons.close,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Projected Monthly Income Hike: ${CurrencyFormatter.format(incomeDelta)}',
                    style: const TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Slider(
                    value: incomeDelta,
                    min: 0,
                    max: 50000,
                    divisions: 10,
                    activeColor: AppColors.success,
                    onChanged: (v) => setModalState(() => incomeDelta = v),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Target Monthly Expense Cut: ${CurrencyFormatter.format(expenseCut)}',
                    style: const TextStyle(
                      color: AppColors.auroraCyan,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Slider(
                    value: expenseCut,
                    min: 0,
                    max: 20000,
                    divisions: 10,
                    activeColor: AppColors.auroraCyan,
                    onChanged: (v) => setModalState(() => expenseCut = v),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _submitQuery(
                          'What if my income increases by \u20B9${incomeDelta.toInt()} and I cut expenses by \u20B9${expenseCut.toInt()}?',
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.auroraViolet,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Simulate Scenario',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showFullXRayModal() {
    final xray = context.read<AIProvider>().currentFinancialXRay;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (_, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: ListView(
                controller: scrollController,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '8-Pillar Financial X-Ray',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${xray.overallScore.toStringAsFixed(0)}/100 • ${xray.rating}',
                            style: const TextStyle(
                              color: AppColors.auroraCyan,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(
                          Icons.close,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...xray.pillars.map((p) {
                    final color = p.score >= 80
                        ? AppColors.success
                        : (p.score >= 60
                              ? AppColors.auroraCyan
                              : (p.score >= 45
                                    ? AppColors.warning
                                    : AppColors.danger));

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryBackground,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                p.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${p.score.toStringAsFixed(0)}/100 (${p.status})',
                                style: TextStyle(
                                  color: color,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            p.description,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Formula: ${p.calculationDetails}',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 10,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showHealthCheckModal() async {
    final aiProvider = context.read<AIProvider>();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: AppColors.auroraCyan),
      ),
    );

    final result = await aiProvider.checkHealth();
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // dismiss loading dialog

    final status = result['status'] as String? ?? 'unknown';
    final isOk = status == 'ok';
    final isUnconfigured = status == 'unconfigured';
    final message = result['message'] as String? ?? 'No details available.';
    final model = result['model'] as String? ?? 'gemini-1.5-flash';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.secondaryBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              isOk
                  ? Icons.check_circle_rounded
                  : (isUnconfigured
                      ? Icons.info_outline_rounded
                      : Icons.warning_rounded),
              color: isOk
                  ? AppColors.success
                  : (isUnconfigured
                      ? AppColors.auroraCyan
                      : AppColors.warningOrange),
            ),
            const SizedBox(width: 8),
            Text(
              isOk
                  ? 'AI Backend Ready'
                  : (isUnconfigured ? 'Local Intelligence' : 'Connection Notice'),
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (isOk
                        ? AppColors.success
                        : (isUnconfigured
                            ? AppColors.auroraCyan
                            : AppColors.warningOrange))
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (isOk
                          ? AppColors.success
                          : (isUnconfigured
                              ? AppColors.auroraCyan
                              : AppColors.warningOrange))
                      .withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Target Model: $model\nArchitecture: Zero-Credential Client + Secure Backend Proxy',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
        actions: [
          if (!isOk)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _showConfigureKeyDialog();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.auroraViolet,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Configure Key', style: TextStyle(color: Colors.white)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: AppColors.auroraCyan)),
          ),
        ],
      ),
    );
  }

  void _showConfigureKeyDialog() {
    final storage = context.read<StorageService>();
    final currentKey = storage.getString('ai_backend_api_key') ?? '';
    final controller = TextEditingController(text: currentKey);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.secondaryBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.key_rounded, color: AppColors.auroraCyan),
            SizedBox(width: 8),
            Text(
              'Gemini API Key',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your Google Gemini API key to activate the AI Coach directly on your browser:',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'AQ.Ab8RN6...',
                hintStyle: const TextStyle(color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.cardBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.auroraCyan),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newKey = controller.text.trim();
              await storage.setString('ai_backend_api_key', newKey);
              if (mounted) {
                Navigator.pop(ctx);
                final ai = context.read<AIProvider>();
                ai.refreshBackendConfig();
                await ai.checkHealth();
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      newKey.isEmpty
                          ? 'API key removed.'
                          : 'Gemini API key saved & activated!',
                    ),
                    backgroundColor: AppColors.successGreen,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.auroraCyan,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Save & Connect', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
