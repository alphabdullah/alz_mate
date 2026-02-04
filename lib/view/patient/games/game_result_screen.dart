import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_styles.dart';
import '../../../core/models/game_score_model.dart';
import '../../../widgets/custom_button.dart';

class GameResultScreen extends StatelessWidget {
  final GameScoreModel score;
  final int? previousBestScore;
  final VoidCallback onPlayAgain;
  final VoidCallback onFinish;

  const GameResultScreen({
    super.key,
    required this.score,
    this.previousBestScore,
    required this.onPlayAgain,
    required this.onFinish,
  });

  bool get isNewHighScore =>
      previousBestScore == null || score.score > previousBestScore!;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
          child: Column(
            children: [
              const SizedBox(height: 20),
              // Trophy Icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: isNewHighScore
                      ? AppColors.accent.withOpacity(0.1)
                      : AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isNewHighScore ? Icons.emoji_events : Icons.check_circle,
                  size: 50,
                  color: isNewHighScore ? AppColors.accent : AppColors.primary,
                ),
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                isNewHighScore ? 'New High Score!' : 'Game Complete!',
                style: AppStyles.displaySmall.copyWith(
                  color: AppColors.text,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                score.gameName,
                style: AppStyles.titleMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 32),

              // Score Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: AppStyles.elevatedCard,
                child: Column(
                  children: [
                    // Current Score
                    _buildScoreRow(
                      'Your Score',
                      score.score.toString(),
                      isHighlighted: true,
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),

                    // Best Score Comparison
                    if (previousBestScore != null)
                      _buildScoreRow(
                        'Best Score',
                        previousBestScore.toString(),
                        isHighlighted: false,
                      ),
                    if (previousBestScore == null)
                      _buildScoreRow('Best Score', 'N/A', isHighlighted: false),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),

                    // Stats
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem('Level', score.level.toString()),
                        _buildStatItem('Time', score.durationText),
                        _buildStatItem('Grade', score.performanceGrade),
                      ],
                    ),
                    if (score.accuracy > 0) ...[
                      const SizedBox(height: 16),
                      _buildStatItem(
                        'Accuracy',
                        '${(score.accuracy * 100).round()}%',
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Performance Message
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _getPerformanceColor().withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _getPerformanceColor().withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(_getPerformanceIcon(), color: _getPerformanceColor()),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _getPerformanceMessage(),
                        style: TextStyle(color: _getPerformanceColor()),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: CustomButton(
                      text: 'Finish',
                      onPressed: onFinish,
                      isOutlined: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CustomButton(
                      text: 'Play Again',
                      onPressed: onPlayAgain,
                      backgroundColor: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreRow(
    String label,
    String value, {
    required bool isHighlighted,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppStyles.bodyLarge.copyWith(color: AppColors.textSecondary),
        ),
        Text(
          value,
          style: AppStyles.headlineSmall.copyWith(
            color: isHighlighted ? AppColors.primary : AppColors.text,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: AppStyles.titleMedium.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppStyles.bodySmall.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Color _getPerformanceColor() {
    if (score.scorePercentage >= 90) return AppColors.success;
    if (score.scorePercentage >= 70) return AppColors.accent;
    if (score.scorePercentage >= 50) return AppColors.warning;
    return AppColors.danger;
  }

  IconData _getPerformanceIcon() {
    if (score.scorePercentage >= 90) return Icons.star;
    if (score.scorePercentage >= 70) return Icons.thumb_up;
    if (score.scorePercentage >= 50) return Icons.check;
    return Icons.trending_up;
  }

  String _getPerformanceMessage() {
    if (score.scorePercentage >= 90) {
      return 'Excellent performance! Your cognitive skills are sharp.';
    }
    if (score.scorePercentage >= 70) {
      return 'Great job! You\'re doing very well.';
    }
    if (score.scorePercentage >= 50) {
      return 'Good work! Keep practicing to improve.';
    }
    return 'Keep practicing! Every game helps strengthen your mind.';
  }
}
