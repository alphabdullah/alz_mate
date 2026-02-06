import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_styles.dart';
import '../../core/models/behavior_analysis_model.dart';

class BehaviorAnalysisResultScreen extends StatelessWidget {
  final BehaviorAnalysisModel analysis;

  const BehaviorAnalysisResultScreen({
    super.key,
    required this.analysis,
  });

  Color _healthStatusColor(String status) {
    switch (status) {
      case 'Excellent':
        return AppColors.success;
      case 'Good':
        return Colors.green;
      case 'Fair':
        return AppColors.warning;
      case 'Needs Attention':
        return AppColors.danger;
      default:
        return AppColors.textSecondary;
    }
  }

  Color _scoreColor(double score) {
    if (score >= 80) return AppColors.success;
    if (score >= 60) return AppColors.primary;
    if (score >= 40) return AppColors.warning;
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _healthStatusColor(analysis.healthStatus);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Behaviour Analysis',
          style: AppStyles.titleLarge,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.text),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              analysis.patientName,
              style: AppStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),

            // Overall score card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: statusColor.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Text(
                    analysis.overallScore.toStringAsFixed(0),
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Overall score',
                    style: AppStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          analysis.overallGrade,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: statusColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        analysis.healthStatus,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Period
            Text(
              'Analysis period: ${DateFormat.yMMMd().format(analysis.periodStart)} – ${DateFormat.yMMMd().format(analysis.periodEnd)}',
              style: AppStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),

            // Weights note
            Text(
              'Sentiment 30% · Reminders 50% · Games 20%',
              style: AppStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),

            // Breakdown cards
            _buildBreakdownCard(
              context,
              'Sentiment (30%)',
              analysis.sentimentScore,
              Icons.sentiment_satisfied_alt,
              analysis.totalJournalEntries == 0
                  ? 'No journal entries in this period'
                  : 'Based on ${analysis.totalJournalEntries} journal entries',
            ),
            const SizedBox(height: 12),
            _buildBreakdownCard(
              context,
              'Reminders (50%)',
              analysis.reminderScore,
              Icons.notifications_active,
              analysis.totalReminders == 0
                  ? 'No reminders in this period'
                  : '${analysis.completedReminders} of ${analysis.totalReminders} completed',
            ),
            const SizedBox(height: 12),
            _buildBreakdownCard(
              context,
              'Games (20%)',
              analysis.gameScore,
              Icons.games,
              analysis.totalGames == 0
                  ? 'No games played in this period'
                  : 'Performance and completion time (${analysis.totalGames} games)',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownCard(
    BuildContext context,
    String label,
    double score,
    IconData icon,
    String subtitle,
  ) {
    final color = _scoreColor(score);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppStyles.elevatedCard,
      child: Row(
        children: [
          Icon(icon, size: 28, color: color),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: AppStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${score.toStringAsFixed(0)}%',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
