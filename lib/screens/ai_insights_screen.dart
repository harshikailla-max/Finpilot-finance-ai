import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ai_provider.dart';
import '../services/ai_finance_service.dart';
import '../utils/constants.dart';
import '../widgets/glass_card.dart';

class AIInsightsScreen extends StatefulWidget {
  const AIInsightsScreen({super.key});

  @override
  State<AIInsightsScreen> createState() => _AIInsightsScreenState();
}

class _AIInsightsScreenState extends State<AIInsightsScreen> {
  String _activeTypeFilter = 'All'; // All, Warnings, Opportunities, Tips

  List<AIInsight> _getFilteredInsights(List<AIInsight> allInsights) {
    if (_activeTypeFilter == 'All') return allInsights;
    if (_activeTypeFilter == 'Warnings') {
      return allInsights.where((i) => i.type == 'warning').toList();
    }
    if (_activeTypeFilter == 'Opportunities') {
      return allInsights.where((i) => i.type == 'opportunity' || i.type == 'positive').toList();
    }
    return allInsights.where((i) => i.type == 'tip').toList();
  }

  @override
  Widget build(BuildContext context) {
    final aiProvider = context.watch<AIProvider>();
    final allInsights = aiProvider.insights;
    final filteredInsights = _getFilteredInsights(allInsights);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Financial Insights'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.cyan.withValues(alpha: 0.05),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Filter Tags
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('All Insights', 'All'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Warnings ⚠️', 'Warnings'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Opportunities 💡', 'Opportunities'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Financial Tips 🎓', 'Tips'),
                      ],
                    ),
                  ),
                ),

                // Insights List
                Expanded(
                  child: filteredInsights.isEmpty
                      ? const Center(
                          child: Text(
                            'No insights found for this filter.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                          itemCount: filteredInsights.length,
                          itemBuilder: (context, index) {
                            final item = filteredInsights[index];
                            final icon = _getInsightIcon(item.type);
                            final color = _getInsightColor(item.type);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              child: GlassCard(
                                border: Border.all(
                                  color: color.withValues(alpha: 0.25),
                                  width: 1,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        icon,
                                        color: color,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.title,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            item.message,
                                            style: TextStyle(
                                              color: AppColors.textSecondary.withValues(alpha: 0.85),
                                              fontSize: 13,
                                              height: 1.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String filterKey) {
    final isActive = _activeTypeFilter == filterKey;
    return ChoiceChip(
      label: Text(label),
      selected: isActive,
      selectedColor: AppColors.primaryPurple,
      backgroundColor: AppColors.cardBackground,
      labelStyle: TextStyle(
        color: isActive ? Colors.white : AppColors.textSecondary,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (val) {
        if (val) {
          setState(() {
            _activeTypeFilter = filterKey;
          });
        }
      },
    );
  }

  IconData _getInsightIcon(String type) {
    switch (type) {
      case 'positive':
        return Icons.check_circle_rounded;
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'opportunity':
        return Icons.lightbulb_outline_rounded;
      case 'tip':
        return Icons.school_rounded;
      default:
        return Icons.insights_rounded;
    }
  }

  Color _getInsightColor(String type) {
    switch (type) {
      case 'positive':
        return AppColors.successGreen;
      case 'warning':
        return AppColors.dangerRed;
      case 'opportunity':
        return AppColors.cyan;
      case 'tip':
        return AppColors.warningOrange;
      default:
        return AppColors.primaryPurple;
    }
  }
}
