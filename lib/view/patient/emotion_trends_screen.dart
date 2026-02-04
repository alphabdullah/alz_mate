import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_styles.dart';
import '../../core/models/emotion_analysis_model.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/emotion_analysis_service.dart';

class EmotionTrendsScreen extends StatefulWidget {
  const EmotionTrendsScreen({super.key});

  @override
  State<EmotionTrendsScreen> createState() => _EmotionTrendsScreenState();
}

class _EmotionTrendsScreenState extends State<EmotionTrendsScreen> {
  bool _isLoading = false;
  String? _error;
  EmotionTrends? _trends;

  @override
  void initState() {
    super.initState();
    _loadTrends();
  }

  Future<void> _loadTrends() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;

      if (user == null) {
        throw Exception('User not authenticated');
      }

      final emotionService = EmotionAnalysisService();
      final trends = await emotionService.getEmotionTrends(
        patientId: user.uid,
        days: 7,
      );

      if (!mounted) return;
      setState(() {
        _trends = trends;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Emotion Trends'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadTrends,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildErrorCard(_error!),
        ],
      );
    }

    if (_trends == null || _trends!.totalEntries == 0) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildEmptyState(),
        ],
      );
    }

    final trends = _trends!;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSummaryCard(trends),
        const SizedBox(height: 16),
        _buildEmotionDistribution(trends),
        const SizedBox(height: 16),
        _buildAverageIntensity(trends),
        const SizedBox(height: 16),
        _buildInsights(trends),
      ],
    );
  }

  Widget _buildErrorCard(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppStyles.elevatedCard.copyWith(
        color: Colors.red.shade50,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Could not load emotion trends',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppStyles.elevatedCard,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(40),
            ),
            child: const Icon(
              Icons.mood,
              color: AppColors.primary,
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No emotion data yet',
            style: AppStyles.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Write a few journal entries so we can start analyzing your emotional trends.',
            style: TextStyle(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(EmotionTrends trends) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppStyles.elevatedCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Last ${trends.periodDays} Days', style: AppStyles.titleMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildSummaryItem(
                label: 'Entries',
                value: trends.totalEntries.toString(),
                icon: Icons.edit_note,
                color: AppColors.primary,
              ),
              const SizedBox(width: 12),
              _buildSummaryItem(
                label: 'Mood Risk Days',
                value: trends.moodRiskCount.toString(),
                icon: Icons.warning_amber_rounded,
                color: AppColors.danger,
              ),
              const SizedBox(width: 12),
              _buildSummaryItem(
                label: 'Risk %',
                value: '${trends.moodRiskPercentage.toStringAsFixed(0)}%',
                icon: Icons.trending_up,
                color: AppColors.accent,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmotionDistribution(EmotionTrends trends) {
    if (trends.emotionCounts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppStyles.elevatedCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Emotion Frequency', style: AppStyles.titleMedium),
          const SizedBox(height: 12),
          ...trends.emotionCounts.entries.map((entry) {
            final emotion = entry.key;
            final count = entry.value;
            final percentage =
                (count / trends.totalEntries * 100).clamp(0, 100).toDouble();

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatEmotion(emotion),
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${percentage.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: percentage / 100,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _colorForEmotion(emotion),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildAverageIntensity(EmotionTrends trends) {
    if (trends.averageIntensities.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppStyles.elevatedCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Average Intensity', style: AppStyles.titleMedium),
          const SizedBox(height: 12),
          ...trends.averageIntensities.entries.map((entry) {
            final emotion = entry.key;
            final intensity = entry.value; // already 0–100

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatEmotion(emotion),
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    '${intensity.toStringAsFixed(0)} / 100',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildInsights(EmotionTrends trends) {
    if (trends.trends.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppStyles.elevatedCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Key Insights', style: AppStyles.titleMedium),
          const SizedBox(height: 12),
          ...trends.trends.map((t) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.circle,
                    size: 8,
                    color: _colorForEmotion(t.emotion),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t.description.isNotEmpty
                          ? t.description
                          : '${_formatEmotion(t.emotion)} appeared ${t.count} times with avg intensity ${t.averageIntensity.toStringAsFixed(0)}.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  String _formatEmotion(String emotion) {
    return emotion.isEmpty
        ? 'Unknown'
        : emotion[0].toUpperCase() + emotion.substring(1).replaceAll('_', ' ');
  }

  Color _colorForEmotion(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'happy':
      case 'joy':
        return AppColors.success;
      case 'sad':
      case 'depressed/low mood':
        return AppColors.danger;
      case 'anxious':
      case 'fearful':
        return AppColors.accent;
      case 'angry':
      case 'frustrated':
        return Colors.deepOrange;
      case 'calm':
        return AppColors.primary;
      default:
        return AppColors.primary.withOpacity(0.8);
    }
  }
}


