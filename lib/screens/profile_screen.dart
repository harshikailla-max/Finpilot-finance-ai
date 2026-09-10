import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../providers/financial_health_provider.dart';
import '../providers/goal_provider.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';
import '../utils/currency_formatter.dart';
import '../widgets/glass_card.dart';
import 'settings_screen.dart';
import 'login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _showPersonalInfoDialog(BuildContext context, String currentName, String currentEmail) {
    final nameController = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.secondaryBackground,
          title: const Text('Personal Information', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Display Name',
                  prefixIcon: Icon(Icons.person, color: AppColors.textMuted),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                enabled: false,
                controller: TextEditingController(text: currentEmail),
                style: const TextStyle(color: AppColors.textMuted),
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon: Icon(Icons.email, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () async {
                final newName = nameController.text.trim();
                if (newName.isNotEmpty) {
                  final storage = context.read<StorageService>();
                  await storage.setString('user_name', newName);
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text('Save', style: TextStyle(color: AppColors.cyan)),
            ),
          ],
        );
      },
    );
  }

  void _showInfoDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.secondaryBackground,
          title: Text(title, style: const TextStyle(color: Colors.white)),
          content: Text(content, style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: AppColors.cyan)),
            ),
          ],
        );
      },
    );
  }

  void _logout(BuildContext context) async {
    final storage = context.read<StorageService>();
    await storage.setBool('isLoggedIn', false);

    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final storage = context.watch<StorageService>();
    final financeProvider = context.watch<FinanceProvider>();
    final healthProvider = context.watch<FinancialHealthProvider>();
    final goalProvider = context.watch<GoalProvider>();

    final userName = storage.getString('user_name') ?? 'Kumar';
    final userEmail = storage.getString('user_email') ?? 'kumar@finpilot.ai';

    final totalScore = healthProvider.healthScore;
    final totalSavings = financeProvider.savings;
    final activeGoalsCount = goalProvider.goals.length;
    final totalTransactionsCount = financeProvider.transactions.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            children: [
              // User Avatar & Info
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [AppColors.primaryPurple, AppColors.cyan],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryPurple.withValues(alpha: 0.4),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      userName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      userEmail,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Financial Summary Cards
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'FINANCIAL SUMMARY',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.4,
                children: [
                  _buildSummaryCard(
                    title: 'Health Score',
                    value: '${totalScore.toStringAsFixed(0)} / 100',
                    icon: Icons.insights_rounded,
                    color: AppColors.primaryPurple,
                  ),
                  _buildSummaryCard(
                    title: 'Total Savings',
                    value: CurrencyFormatter.format(totalSavings),
                    icon: Icons.savings_rounded,
                    color: AppColors.successGreen,
                  ),
                  _buildSummaryCard(
                    title: 'Active Goals',
                    value: '$activeGoalsCount Goals',
                    icon: Icons.flag_rounded,
                    color: AppColors.cyan,
                  ),
                  _buildSummaryCard(
                    title: 'Transactions',
                    value: '$totalTransactionsCount Logs',
                    icon: Icons.receipt_long_rounded,
                    color: AppColors.warningOrange,
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Options Menu
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'PREFERENCES & DETAILS',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              GlassCard(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    _buildOptionTile(
                      icon: Icons.person_outline_rounded,
                      title: 'Personal Information',
                      subtitle: 'Edit name and profile details',
                      onTap: () => _showPersonalInfoDialog(context, userName, userEmail),
                    ),
                    const Divider(height: 1, color: Colors.white10),
                    _buildOptionTile(
                      icon: Icons.security_rounded,
                      title: 'Security',
                      subtitle: 'Biometrics & passcodes',
                      onTap: () => _showInfoDialog(
                        context,
                        'Security',
                        'FinPilot AI is secured with local biometric authentication and sandbox encryption.',
                      ),
                    ),
                    const Divider(height: 1, color: Colors.white10),
                    _buildOptionTile(
                      icon: Icons.notifications_none_rounded,
                      title: 'Notifications',
                      subtitle: 'Budget alerts and savings updates',
                      onTap: () => _showInfoDialog(
                        context,
                        'Notifications',
                        'In-app budget and savings push alerts are active.',
                      ),
                    ),
                    const Divider(height: 1, color: Colors.white10),
                    _buildOptionTile(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Data & Privacy',
                      subtitle: 'On-device private storage',
                      onTap: () => _showInfoDialog(
                        context,
                        'Data & Privacy',
                        'All transaction data and budgets are stored securely on your local device with zero telemetry selling.',
                      ),
                    ),
                    const Divider(height: 1, color: Colors.white10),
                    _buildOptionTile(
                      icon: Icons.settings_outlined,
                      title: 'Settings',
                      subtitle: 'Currencies, themes & backups',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const SettingsScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Log Out Button
              TextButton.icon(
                onPressed: () => _logout(context),
                icon: const Icon(Icons.logout_rounded, color: AppColors.dangerRed),
                label: const Text(
                  'Log Out',
                  style: TextStyle(
                    color: AppColors.dangerRed,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.cyan, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
      ),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textMuted, size: 14),
      onTap: onTap,
    );
  }
}
