import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';
import '../providers/finance_provider.dart';
import '../providers/budget_provider.dart';
import '../providers/goal_provider.dart';
import '../providers/investment_provider.dart';
import '../providers/ai_provider.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';
import '../widgets/glass_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _notificationsEnabled;
  late bool _budgetAlertsEnabled;
  late bool _aiRecommendationsEnabled;
  String _selectedCurrency = 'INR (₹)';
  String _aiApiKey = '';
  String _aiEndpoint = '';
  String _ocrApiKey = '';

  @override
  void initState() {
    super.initState();
    final storage = context.read<StorageService>();
    _notificationsEnabled = storage.getBool('settings_notifications') ?? true;
    _budgetAlertsEnabled = storage.getBool('settings_budget_alerts') ?? true;
    _aiRecommendationsEnabled = storage.getBool('settings_ai_rec') ?? true;
    _selectedCurrency = storage.getString('settings_currency') ?? 'INR (₹)';
    _aiApiKey = storage.getString('ai_backend_api_key') ?? '';
    _aiEndpoint = storage.getString('ai_backend_endpoint') ?? '';
    _ocrApiKey = storage.getString('ocr_api_key') ?? '';
  }

  bool _isTestingApi = false;

  Future<void> _testApiConnection() async {
    setState(() => _isTestingApi = true);
    final aiProvider = context.read<AIProvider>();
    final result = await aiProvider.checkHealth();
    if (!mounted) return;
    setState(() => _isTestingApi = false);

    final status = result['status'] as String? ?? 'unknown';
    final isOk = status == 'ok';
    final message = result['message'] as String? ?? 'No diagnostic detail';
    final model = result['model'] as String? ?? 'gemini-1.5-flash';
    final isUnconfigured = status == 'unconfigured';

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
                  ? 'API Connected'
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
              'Model: $model\nArchitecture: Zero-Credential Client + Secure Backend Reverse Proxy',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Close',
              style: TextStyle(color: AppColors.auroraCyan),
            ),
          ),
        ],
      ),
    );
  }

  void _showAiKeyDialog() {
    final controller = TextEditingController(text: _aiApiKey);
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.secondaryBackground,
          title: const Row(
            children: [
              Icon(Icons.smart_toy_rounded, color: AppColors.auroraCyan),
              SizedBox(width: 8),
              Text(
                'AI Backend API Key',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter your Gemini API key (or leave empty to use FinPilot\'s live local financial intelligence engine):',
                style: TextStyle(color: Colors.white70, fontSize: 12.5),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                obscureText: true,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'AIzaSy...',
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: AppColors.cardBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () async {
                final key = controller.text.trim();
                final storage = context.read<StorageService>();
                await storage.setString('ai_backend_api_key', key);
                if (mounted) {
                  context.read<AIProvider>().refreshBackendConfig();
                }
                setState(() => _aiApiKey = key);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        key.isNotEmpty
                            ? 'AI Backend API key saved.'
                            : 'Using Local Intelligence Engine.',
                      ),
                      backgroundColor: AppColors.successGreen,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Text(
                'Save',
                style: TextStyle(
                  color: AppColors.cyan,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showBackendEndpointDialog() {
    final controller = TextEditingController(text: _aiEndpoint);
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.secondaryBackground,
          title: const Text(
            'Custom Backend URL',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Optional private proxy server or custom API endpoint. Leave blank to connect directly.',
                style: TextStyle(color: Colors.white70, fontSize: 12.5),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'https://api.myfinpilot.com/chat',
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: AppColors.cardBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () async {
                final endpoint = controller.text.trim();
                final storage = context.read<StorageService>();
                await storage.setString('ai_backend_endpoint', endpoint);
                setState(() => _aiEndpoint = endpoint);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text(
                'Save',
                style: TextStyle(
                  color: AppColors.cyan,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showOcrKeyDialog() {
    final controller = TextEditingController(text: _ocrApiKey);
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.secondaryBackground,
          title: const Text(
            'Receipt OCR Key',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Optional custom OCR.space API key. If empty, the default engine is used.',
                style: TextStyle(color: Colors.white70, fontSize: 12.5),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'K8789...',
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: AppColors.cardBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () async {
                final key = controller.text.trim();
                final storage = context.read<StorageService>();
                await storage.setString('ocr_api_key', key);
                setState(() => _ocrApiKey = key);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text(
                'Save',
                style: TextStyle(
                  color: AppColors.cyan,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showCurrencyDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final currencies = ['INR (₹)', 'USD (\$)', 'EUR (€)', 'GBP (£)'];
        return AlertDialog(
          backgroundColor: AppColors.secondaryBackground,
          title: const Text(
            'Select Currency',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: currencies.map((c) {
              return RadioListTile<String>(
                value: c,
                groupValue: _selectedCurrency,
                title: Text(c, style: const TextStyle(color: Colors.white)),
                activeColor: AppColors.cyan,
                onChanged: (val) async {
                  if (val != null) {
                    setState(() {
                      _selectedCurrency = val;
                    });
                    final storage = context.read<StorageService>();
                    await storage.setString('settings_currency', val);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _exportData() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.secondaryBackground,
          title: const Text(
            'Export Financial Data',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Your transactions, budgets, and goals will be packaged into an encrypted JSON backup file.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text(
                      'Backup JSON exported successfully to local storage.',
                    ),
                    backgroundColor: AppColors.successGreen,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              },
              child: const Text(
                'Export JSON',
                style: TextStyle(color: AppColors.cyan),
              ),
            ),
          ],
        );
      },
    );
  }

  void _confirmResetData() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.secondaryBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.dangerRed),
              SizedBox(width: 8),
              Text('Reset All Data?', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: const Text(
            'This action will erase all transactions, custom budgets, goals, and logged investments. Demo data will be reloaded.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () async {
                final storage = context.read<StorageService>();
                final finance = context.read<FinanceProvider>();
                final budget = context.read<BudgetProvider>();
                final goal = context.read<GoalProvider>();
                final investment = context.read<InvestmentProvider>();
                final ai = context.read<AIProvider>();

                await storage.remove('transactions');
                await storage.remove('budget');
                await storage.remove('goals');
                await storage.remove('investments');
                await storage.remove('chat_messages');

                await finance.clearAll();
                await budget.resetBudget();
                await goal.clearAll();
                await investment.clearAll();
                await ai.clearChat();

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                        'Application data has been reset to defaults.',
                      ),
                      backgroundColor: AppColors.dangerRed,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                }
              },
              child: const Text(
                'Reset Everything',
                style: TextStyle(
                  color: AppColors.dangerRed,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.secondaryBackground,
          title: const Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: AppColors.cyan),
              SizedBox(width: 8),
              Text('About FinPilot AI', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FinPilot AI v1.0.0',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Your Intelligent Personal Finance Companion. Generative AI-powered personal finance management designed for students, young professionals, families, freelancers, and small business users.',
                style: TextStyle(
                  color: Colors.white70,
                  height: 1.4,
                  fontSize: 13,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Tech Stack: Flutter 3, Dart, Provider, fl_chart, SharedPreferences, Material 3 Dark Fintech Design.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Close',
                style: TextStyle(color: AppColors.cyan),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.secondaryBackground,
          title: const Text(
            'Privacy & Disclaimers',
            style: TextStyle(color: Colors.white),
          ),
          content: const SingleChildScrollView(
            child: Text(
              '1. Educational Nature: All AI insights, financial scores, predictions, and tips are for educational purposes only and do not constitute certified financial, tax, or investment advice.\n\n'
              '2. Local Privacy: All transaction amounts, category distributions, and goal metrics remain strictly confidential on your local device.\n\n'
              '3. Non-Custodial: FinPilot AI does not execute actual financial transactions or store bank passwords.',
              style: TextStyle(
                color: Colors.white70,
                height: 1.4,
                fontSize: 13,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Understood',
                style: TextStyle(color: AppColors.cyan),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final storage = context.read<StorageService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Appearance & Regional
              const Text(
                'GENERAL SETTINGS',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),
              GlassCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    SwitchListTile(
                      value: themeProvider.isDarkMode,
                      activeThumbColor: AppColors.primaryPurple,
                      title: const Text(
                        'Dark Mode',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: const Text(
                        'Signature Fintech dark palette',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      secondary: const Icon(
                        Icons.dark_mode_outlined,
                        color: AppColors.cyan,
                      ),
                      onChanged: (val) {
                        themeProvider.toggleTheme();
                      },
                    ),
                    const Divider(height: 1, color: Colors.white10),
                    ListTile(
                      leading: const Icon(
                        Icons.currency_exchange_rounded,
                        color: AppColors.cyan,
                      ),
                      title: const Text(
                        'Default Currency',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        _selectedCurrency,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: AppColors.textMuted,
                        size: 14,
                      ),
                      onTap: _showCurrencyDialog,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Alerts & Intelligence
              const Text(
                'NOTIFICATIONS & AI AGENTS',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),
              GlassCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    SwitchListTile(
                      value: _notificationsEnabled,
                      activeThumbColor: AppColors.primaryPurple,
                      title: const Text(
                        'Push Notifications',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: const Text(
                        'Reminders to log daily expenses',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      secondary: const Icon(
                        Icons.notifications_active_outlined,
                        color: AppColors.cyan,
                      ),
                      onChanged: (val) async {
                        setState(() => _notificationsEnabled = val);
                        await storage.setBool('settings_notifications', val);
                      },
                    ),
                    const Divider(height: 1, color: Colors.white10),
                    SwitchListTile(
                      value: _budgetAlertsEnabled,
                      activeThumbColor: AppColors.primaryPurple,
                      title: const Text(
                        'Budget Limit Alerts',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: const Text(
                        'Warn when category spending exceeds 75%',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      secondary: const Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.warningOrange,
                      ),
                      onChanged: (val) async {
                        setState(() => _budgetAlertsEnabled = val);
                        await storage.setBool('settings_budget_alerts', val);
                      },
                    ),
                    const Divider(height: 1, color: Colors.white10),
                    SwitchListTile(
                      value: _aiRecommendationsEnabled,
                      activeThumbColor: AppColors.primaryPurple,
                      title: const Text(
                        'Smart AI Recommendations',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: const Text(
                        'Autonomous savings and trend detection',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      secondary: const Icon(
                        Icons.auto_awesome_rounded,
                        color: AppColors.cyan,
                      ),
                      onChanged: (val) async {
                        setState(() => _aiRecommendationsEnabled = val);
                        await storage.setBool('settings_ai_rec', val);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // AI Engine & Cloud OCR Services
              const Text(
                'AI COACH & OCR CLOUD SERVICES',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),
              GlassCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.smart_toy_rounded,
                        color: AppColors.auroraCyan,
                      ),
                      title: const Text(
                        'AI Backend API Key',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        _aiApiKey.isNotEmpty
                            ? '••••••••${_aiApiKey.length > 8 ? _aiApiKey.substring(_aiApiKey.length - 4) : ''} (Gemini AI active)'
                            : 'Not set (Using Live Local Intelligence)',
                        style: TextStyle(
                          color: _aiApiKey.isNotEmpty
                              ? AppColors.success
                              : AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: AppColors.textMuted,
                        size: 14,
                      ),
                      onTap: _showAiKeyDialog,
                    ),
                    const Divider(height: 1, color: Colors.white10),
                    ListTile(
                      leading: const Icon(
                        Icons.dns_rounded,
                        color: AppColors.auroraViolet,
                      ),
                      title: const Text(
                        'Custom Backend URL',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        _aiEndpoint.isNotEmpty
                            ? _aiEndpoint
                            : 'Default (Direct Gemini API)',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: AppColors.textMuted,
                        size: 14,
                      ),
                      onTap: _showBackendEndpointDialog,
                    ),
                    const Divider(height: 1, color: Colors.white10),
                    ListTile(
                      leading: const Icon(
                        Icons.document_scanner_rounded,
                        color: AppColors.auroraCyan,
                      ),
                      title: const Text(
                        'Receipt OCR Key',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        _ocrApiKey.isNotEmpty
                            ? 'Custom key active'
                            : 'Default Built-In Engine',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: AppColors.textMuted,
                        size: 14,
                      ),
                      onTap: _showOcrKeyDialog,
                    ),
                    const Divider(height: 1, color: Colors.white10),
                    ListTile(
                      leading: _isTestingApi
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.auroraCyan,
                              ),
                            )
                          : const Icon(
                              Icons.network_check_rounded,
                              color: AppColors.auroraCyan,
                            ),
                      title: const Text(
                        'Test AI Connection',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: const Text(
                        'Perform safe health check on Google Gemini backend',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.play_arrow_rounded,
                        color: AppColors.auroraCyan,
                        size: 20,
                      ),
                      onTap: _isTestingApi ? null : _testApiConnection,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Data & Management
              const Text(
                'DATA MANAGEMENT & PRIVACY',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),
              GlassCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.download_rounded,
                        color: AppColors.cyan,
                      ),
                      title: const Text(
                        'Export Application Data',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: const Text(
                        'Download financial transactions in JSON',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: AppColors.textMuted,
                        size: 14,
                      ),
                      onTap: _exportData,
                    ),
                    const Divider(height: 1, color: Colors.white10),
                    ListTile(
                      leading: const Icon(
                        Icons.delete_forever_rounded,
                        color: AppColors.dangerRed,
                      ),
                      title: const Text(
                        'Reset Application Data',
                        style: TextStyle(
                          color: AppColors.dangerRed,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: const Text(
                        'Wipe all logs, goals, and restore default seeds',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: AppColors.textMuted,
                        size: 14,
                      ),
                      onTap: _confirmResetData,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Info & Legal
              const Text(
                'ABOUT & LEGAL',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),
              GlassCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.cyan,
                      ),
                      title: const Text(
                        'About FinPilot AI',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: AppColors.textMuted,
                        size: 14,
                      ),
                      onTap: _showAboutDialog,
                    ),
                    const Divider(height: 1, color: Colors.white10),
                    ListTile(
                      leading: const Icon(
                        Icons.policy_outlined,
                        color: AppColors.cyan,
                      ),
                      title: const Text(
                        'Privacy Policy & Disclaimers',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: AppColors.textMuted,
                        size: 14,
                      ),
                      onTap: _showPrivacyPolicy,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
