import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/advisor_models.dart';
import '../providers/ai_provider.dart';
import '../utils/currency_formatter.dart';
import 'budget_screen.dart';
import 'goals_screen.dart';
import 'investment_screen.dart';
import 'receipt_scanner_screen.dart';
import 'analytics_screen.dart';

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen>
    with SingleTickerProviderStateMixin {
  // Theme palette matching FinPilot AI luxury futuristic fintech aesthetic
  static const Color bgDark = Color(0xFF050914);
  static const Color cardDark = Color(0xFF0D1528);
  static const Color cardLight = Color(0xFF152238);
  static const Color primaryPurple = Color(0xFF6C5CE7);
  static const Color cyanAccent = Color(0xFF4CC9F0);
  static const Color successGreen = Color(0xFF2DD4A8);
  static const Color warningOrange = Color(0xFFFFB86B);
  static const Color dangerRed = Color(0xFFFF6B81);
  static const Color textMuted = Color(0xFF9AA4B2);

  final TextEditingController _queryController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late AnimationController _orbAnimationController;

  @override
  void initState() {
    super.initState();
    _orbAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _queryController.dispose();
    _scrollController.dispose();
    _orbAnimationController.dispose();
    super.dispose();
  }

  void _submitQuery(String text) async {
    final clean = text.trim();
    if (clean.isEmpty) return;
    _queryController.clear();

    final ai = context.read<AIProvider>();
    await ai.sendMessage(clean);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
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
    final moneyMoves = aiProvider.todayMoneyMoves;
    final responses = aiProvider.advisorResponses;

    return Scaffold(
      backgroundColor: bgDark,
      body: SafeArea(
        child: Column(
          children: [
            _buildAdvisorHeader(xray),
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _buildOrbAndGreeting(xray),
                  const SizedBox(height: 16),
                  _buildFinancialXRaySummaryCard(xray),
                  const SizedBox(height: 20),
                  _buildMoneyMovesSection(moneyMoves),
                  const SizedBox(height: 20),
                  _buildQuickActionChips(),
                  const SizedBox(height: 24),
                  if (responses.isNotEmpty) ...[
                    _buildSectionDivider('ADVISOR REASONING & DECISIONS'),
                    const SizedBox(height: 14),
                    ...responses.map((resp) => _buildAdvisorResponseCard(resp)),
                  ],
                  if (aiProvider.isTyping) _buildTypingIndicator(),
                  const SizedBox(height: 20),
                  _buildDisclaimer(),
                ],
              ),
            ),
            _buildNaturalLanguageInputBar(aiProvider),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================
  Widget _buildAdvisorHeader(FinancialXRayReport xray) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: cardDark.withValues(alpha: 0.95),
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [primaryPurple, cyanAccent]),
              boxShadow: [
                BoxShadow(color: primaryPurple.withValues(alpha: 0.35), blurRadius: 10),
              ],
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FINPILOT AI',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                'PRIVATE FINANCIAL INTELLIGENCE',
                style: TextStyle(
                  color: cyanAccent,
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const Spacer(),
          // X-Ray Quick Score Pill
          GestureDetector(
            onTap: _showFullXRayModal,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: primaryPurple.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: primaryPurple.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_rounded, color: cyanAccent, size: 14),
                  const SizedBox(width: 5),
                  Text(
                    '${xray.overallScore.toStringAsFixed(0)}/100',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: () => context.read<AIProvider>().clearChat(),
            icon: const Icon(Icons.refresh_rounded, color: textMuted, size: 20),
            tooltip: 'Reset Conversation',
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ORB & GREETING
  // ============================================================
  Widget _buildOrbAndGreeting(FinancialXRayReport xray) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryPurple.withValues(alpha: 0.22),
            cyanAccent.withValues(alpha: 0.08),
            cardDark,
          ],
        ),
        border: Border.all(color: primaryPurple.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          // Animated Glowing AI Orb
          AnimatedBuilder(
            animation: _orbAnimationController,
            builder: (context, child) {
              final scale = 1.0 + (_orbAnimationController.value * 0.08);
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [cyanAccent, primaryPurple, Color(0xFF030A1A)],
                      stops: [0.0, 0.65, 1.0],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: cyanAccent.withValues(alpha: 0.35 + (_orbAnimationController.value * 0.25)),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.psychology_rounded, color: Colors.white, size: 28),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Private Financial Advisor',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Continuous audit active. Operating at ${xray.rating.toLowerCase()} financial health.',
                  style: const TextStyle(color: textMuted, fontSize: 11.5, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FINANCIAL X-RAY OVERVIEW CARD
  // ============================================================
  Widget _buildFinancialXRaySummaryCard(FinancialXRayReport xray) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.biotech_rounded, color: cyanAccent, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'FINANCIAL X-RAY AUDIT',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                  ),
                ],
              ),
              GestureDetector(
                onTap: _showFullXRayModal,
                child: const Text(
                  'View All 8 Pillars \u2192',
                  style: TextStyle(color: cyanAccent, fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 4 Key Pillar Preview Bars
          Row(
            children: [
              Expanded(child: _buildPillarMiniMeter(xray.pillars[0])), // Cash Flow
              const SizedBox(width: 8),
              Expanded(child: _buildPillarMiniMeter(xray.pillars[1])), // Savings
              const SizedBox(width: 8),
              Expanded(child: _buildPillarMiniMeter(xray.pillars[5])), // Emergency Fund
              const SizedBox(width: 8),
              Expanded(child: _buildPillarMiniMeter(xray.pillars[2])), // Debt
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPillarMiniMeter(XRayPillarScore pillar) {
    final color = pillar.score >= 80
        ? successGreen
        : (pillar.score >= 60 ? cyanAccent : (pillar.score >= 45 ? warningOrange : dangerRed));

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cardLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(pillar.name, style: const TextStyle(color: textMuted, fontSize: 9.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('${pillar.score.toStringAsFixed(0)}%', style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: (pillar.score / 100).clamp(0.0, 1.0),
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TODAY'S MONEY MOVES
  // ============================================================
  Widget _buildMoneyMovesSection(List<MoneyMove> moves) {
    if (moves.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.bolt_rounded, color: warningOrange, size: 18),
            SizedBox(width: 8),
            Text(
              "TODAY'S MONEY MOVES",
              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.8),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 148,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: moves.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final move = moves[index];
              return Container(
                width: 260,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardDark,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: primaryPurple.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: primaryPurple.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            move.category.toUpperCase(),
                            style: const TextStyle(color: cyanAccent, fontSize: 9, fontWeight: FontWeight.w800),
                          ),
                        ),
                        Text(
                          move.impact,
                          style: const TextStyle(color: successGreen, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      move.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Text(
                        move.reason,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: textMuted, fontSize: 10.5, height: 1.3),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _navigateToRoute(move.actionRoute),
                      child: Row(
                        children: [
                          Text(
                            move.actionLabel,
                            style: const TextStyle(color: cyanAccent, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward_rounded, color: cyanAccent, size: 12),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ============================================================
  // QUICK ACTION CHIPS
  // ============================================================
  Widget _buildQuickActionChips() {
    final actions = [
      {'label': 'Can I afford this?', 'icon': Icons.shopping_bag_outlined, 'action': () => _showPurchaseAnalyzerModal()},
      {'label': 'Analyze My Finances', 'icon': Icons.biotech_outlined, 'action': () => _submitQuery('Analyze my finances')},
      {'label': 'Where to invest?', 'icon': Icons.trending_up_rounded, 'action': () => _submitQuery('Where should I invest?')},
      {'label': 'Optimize My Goals', 'icon': Icons.flag_outlined, 'action': () => _submitQuery('Optimize my goals')},
      {'label': 'What-If Simulator', 'icon': Icons.tune_rounded, 'action': () => _showWhatIfModal()},
      {'label': 'Financial DNA', 'icon': Icons.fingerprint_rounded, 'action': () => _submitQuery('What is my financial DNA?')},
      {'label': 'Should I repay my loan?', 'icon': Icons.credit_card_outlined, 'action': () => _submitQuery('Should I repay my loan or invest?')},
    ];

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: actions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final a = actions[index];
          return ActionChip(
            avatar: Icon(a['icon'] as IconData, color: cyanAccent, size: 14),
            label: Text(a['label'] as String, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
            backgroundColor: cardDark,
            side: BorderSide(color: primaryPurple.withValues(alpha: 0.25)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onPressed: a['action'] as VoidCallback,
          );
        },
      ),
    );
  }

  // ============================================================
  // ADVISOR RESPONSE CARD (Structured 8-Section Card)
  // ============================================================
  Widget _buildAdvisorResponseCard(AdvisorResponse resp) {
    Color verdictColor = successGreen;
    if (resp.verdict.contains('NOT') || resp.verdict.contains('DEFICIT')) {
      verdictColor = dangerRed;
    } else if (resp.verdict.contains('TIGHT') || resp.verdict.contains('POSSIBLE') || resp.verdict.contains('WARNING')) {
      verdictColor = warningOrange;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: primaryPurple.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(color: primaryPurple.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: User Query
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: cardLight.withValues(alpha: 0.7),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              children: [
                const Icon(Icons.person_outline_rounded, color: textMuted, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '"${resp.userQuery}"',
                    style: const TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. VERDICT BADGE
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: verdictColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: verdictColor.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_rounded, color: verdictColor, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        resp.verdict,
                        style: TextStyle(color: verdictColor, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // DYNAMIC SPECIALIZED CARD PAYLOAD (if present)
                if (resp.cardType != AdvisorCardType.none) ...[
                  _buildDynamicCardPayload(resp),
                  const SizedBox(height: 14),
                ],

                // 2. CURRENT POSITION & CALCULATION
                _buildResponseBlock(
                  label: 'CURRENT POSITION & CALCULATION',
                  icon: Icons.calculate_outlined,
                  color: cyanAccent,
                  content: '${resp.currentPosition}\n\n${resp.calculation}',
                ),
                const SizedBox(height: 12),

                // 3. REASONING
                _buildResponseBlock(
                  label: 'FINANCIAL REASONING',
                  icon: Icons.psychology_outlined,
                  color: primaryPurple,
                  content: resp.reasoning,
                ),
                const SizedBox(height: 12),

                // 4. RISKS
                _buildResponseBlock(
                  label: 'DOWNSIDE RISKS',
                  icon: Icons.warning_amber_rounded,
                  color: warningOrange,
                  content: resp.risks,
                ),
                const SizedBox(height: 12),

                // 5. ALTERNATIVES
                _buildResponseBlock(
                  label: 'STRATEGIC ALTERNATIVE',
                  icon: Icons.alt_route_rounded,
                  color: cyanAccent,
                  content: resp.alternatives,
                ),
                const SizedBox(height: 16),

                // 6. NEXT BEST ACTION BUTTON
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cardLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: primaryPurple.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.touch_app_rounded, color: cyanAccent, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('NEXT BEST ACTION', style: TextStyle(color: textMuted, fontSize: 9.5, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text(resp.nextAction, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      if (resp.actionRoute != null)
                        ElevatedButton(
                          onPressed: () => _navigateToRoute(resp.actionRoute),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryPurple,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Execute', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResponseBlock({
    required String label,
    required IconData icon,
    required Color color,
    required String content,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.6),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          content,
          style: const TextStyle(color: Colors.white, fontSize: 12.5, height: 1.4),
        ),
      ],
    );
  }

  // ============================================================
  // DYNAMIC PAYLOAD CARD BUILDER
  // ============================================================
  Widget _buildDynamicCardPayload(AdvisorResponse resp) {
    final payload = resp.cardPayload;
    if (payload == null) return const SizedBox.shrink();

    switch (resp.cardType) {
      case AdvisorCardType.affordability:
        final score = (payload['affordabilityScore'] as num?)?.toDouble() ?? 50.0;
        final runway = (payload['remainingEmergencyMonths'] as num?)?.toDouble() ?? 3.0;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardLight,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  const Text('Affordability Score', style: TextStyle(color: textMuted, fontSize: 10)),
                  const SizedBox(height: 4),
                  Text('${score.toStringAsFixed(0)}/100', style: const TextStyle(color: cyanAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              Container(width: 1, height: 32, color: Colors.white12),
              Column(
                children: [
                  const Text('Remaining Runway', style: TextStyle(color: textMuted, fontSize: 10)),
                  const SizedBox(height: 4),
                  Text('${runway.toStringAsFixed(1)} Months', style: TextStyle(color: runway >= 3.0 ? successGreen : warningOrange, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        );

      case AdvisorCardType.investment:
        final sip = (payload['sip'] as num?)?.toDouble() ?? 5000.0;
        final allocation = payload['allocation'] as Map<String, dynamic>? ?? {};
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardLight,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Recommended Monthly SIP', style: TextStyle(color: textMuted, fontSize: 11)),
                  Text(CurrencyFormatter.format(sip), style: const TextStyle(color: successGreen, fontSize: 15, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 10),
              ...allocation.entries.map((e) {
                final pct = (e.value as num).toDouble();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(flex: 3, child: Text(e.key, style: const TextStyle(color: Colors.white70, fontSize: 11))),
                      Expanded(
                        flex: 2,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: pct / 100,
                            backgroundColor: Colors.white10,
                            valueColor: const AlwaysStoppedAnimation<Color>(cyanAccent),
                            minHeight: 5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('${pct.toStringAsFixed(0)}%', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              }),
            ],
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  // ============================================================
  // NATURAL LANGUAGE INPUT BAR
  // ============================================================
  Widget _buildNaturalLanguageInputBar(AIProvider aiProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cardDark,
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _queryController,
              style: const TextStyle(color: Colors.white, fontSize: 13.5),
              onSubmitted: _submitQuery,
              decoration: InputDecoration(
                hintText: 'What financial decision are you trying to solve?',
                hintStyle: const TextStyle(color: textMuted, fontSize: 12.5),
                filled: true,
                fillColor: cardLight,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: cyanAccent, width: 1.5)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [primaryPurple, cyanAccent]),
            ),
            child: IconButton(
              onPressed: () => _submitQuery(_queryController.text),
              icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: cyanAccent)),
          const SizedBox(width: 10),
          Text(
            'Analyzing cash flow, budget limits, and risk parameters...',
            style: TextStyle(color: cyanAccent.withValues(alpha: 0.8), fontSize: 11.5, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text(
        'FinPilot AI provides educational financial intelligence and decision simulations. Projections are illustrative and not guaranteed. Consult a certified financial planner for individual advice.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Color(0x60FFFFFF), fontSize: 10, height: 1.3),
      ),
    );
  }

  Widget _buildSectionDivider(String title) {
    return Row(
      children: [
        const Expanded(child: Divider(color: Colors.white12)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(title, style: const TextStyle(color: textMuted, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
        ),
        const Expanded(child: Divider(color: Colors.white12)),
      ],
    );
  }

  // ============================================================
  // INTERACTIVE MODAL: PURCHASE ANALYZER
  // ============================================================
  void _showPurchaseAnalyzerModal() {
    final productCtrl = TextEditingController(text: 'MacBook Pro');
    final priceCtrl = TextEditingController(text: '120000');
    String timeframe = 'immediately';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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
                  const Text('Purchase Decision Analyzer', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close, color: textMuted)),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: productCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Product / Item Name',
                  labelStyle: const TextStyle(color: textMuted),
                  filled: true,
                  fillColor: cardLight,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Target Price (\u20B9)',
                  labelStyle: const TextStyle(color: textMuted),
                  filled: true,
                  fillColor: cardLight,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
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
                    _submitQuery('Can I afford to buy $p for \u20B9$amt $timeframe?');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryPurple,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Run Affordability Analysis', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // INTERACTIVE MODAL: WHAT-IF SIMULATOR
  // ============================================================
  void _showWhatIfModal() {
    double incomeDelta = 15000;
    double expenseCut = 5000;

    showModalBottomSheet(
      context: context,
      backgroundColor: cardDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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
                      const Text('What-If Scenario Engine', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                      IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close, color: textMuted)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Projected Monthly Income Hike: ${CurrencyFormatter.format(incomeDelta)}', style: const TextStyle(color: successGreen, fontWeight: FontWeight.bold)),
                  Slider(
                    value: incomeDelta,
                    min: 0,
                    max: 50000,
                    divisions: 10,
                    activeColor: successGreen,
                    onChanged: (v) => setModalState(() => incomeDelta = v),
                  ),
                  const SizedBox(height: 10),
                  Text('Target Monthly Expense Cut: ${CurrencyFormatter.format(expenseCut)}', style: const TextStyle(color: cyanAccent, fontWeight: FontWeight.bold)),
                  Slider(
                    value: expenseCut,
                    min: 0,
                    max: 20000,
                    divisions: 10,
                    activeColor: cyanAccent,
                    onChanged: (v) => setModalState(() => expenseCut = v),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _submitQuery('What if my income increases by \u20B9${incomeDelta.toInt()} and I cut expenses by \u20B9${expenseCut.toInt()}?');
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: primaryPurple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      child: const Text('Simulate Scenario', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  // ============================================================
  // INTERACTIVE MODAL: FINANCIAL X-RAY
  // ============================================================
  void _showFullXRayModal() {
    final xray = context.read<AIProvider>().currentFinancialXRay;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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
                          const Text('8-Pillar Financial X-Ray', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('${xray.overallScore.toStringAsFixed(0)}/100 • ${xray.rating}', style: const TextStyle(color: cyanAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close, color: textMuted)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...xray.pillars.map((p) {
                    final color = p.score >= 80
                        ? successGreen
                        : (p.score >= 60 ? cyanAccent : (p.score >= 45 ? warningOrange : dangerRed));

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: cardLight, borderRadius: BorderRadius.circular(16)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(p.name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                              Text('${p.score.toStringAsFixed(0)}/100 (${p.status})', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(p.description, style: const TextStyle(color: textMuted, fontSize: 11.5)),
                          const SizedBox(height: 4),
                          Text('Formula: ${p.calculationDetails}', style: const TextStyle(color: Colors.white38, fontSize: 10, fontStyle: FontStyle.italic)),
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
}
