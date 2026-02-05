import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_styles.dart';
import '../core/models/journal_entry_model.dart';

class JournalEntryCard extends StatelessWidget {
  final JournalEntryModel entry;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const JournalEntryCard({
    super.key,
    required this.entry,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // Debug: Print emotion and sentiment for troubleshooting
    if (entry.emotion != null) {
      print('🎭 CARD: Entry ${entry.id} - Emotion: ${entry.emotion}, Sentiment: ${entry.sentimentLabel}');
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _getTypeColor().withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _getTypeIcon(),
                        color: _getTypeColor(),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getTypeLabel(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            _formatDate(entry.timestamp),
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          onEdit?.call();
                        } else if (value == 'delete') {
                          onDelete?.call();
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 20),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete,
                                size: 20,
                                color: AppColors.danger,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Delete',
                                style: TextStyle(color: AppColors.danger),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  entry.content,
                  style: AppStyles.body,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                // Display emotion badge (priority) or sentiment badge (fallback)
                if (entry.emotion != null && entry.emotion!.isNotEmpty) ...[
                  // Show emotion badge
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getEmotionColor(entry.emotion!).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _getEmotionColor(entry.emotion!).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getEmotionIcon(entry.emotion!),
                          size: 16,
                          color: _getEmotionColor(entry.emotion!),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _formatEmotionText(entry.emotion!),
                          style: TextStyle(
                            color: _getEmotionColor(entry.emotion!),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (entry.sentimentLabel != null && entry.sentimentLabel!.isNotEmpty) ...[
                  // Fallback to sentiment badge only if emotion is not available
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getSentimentColor(entry.sentimentLabel!).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _getSentimentColor(entry.sentimentLabel!).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getSentimentIcon(entry.sentimentLabel!),
                          size: 16,
                          color: _getSentimentColor(entry.sentimentLabel!),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          entry.sentimentLabel!.toUpperCase(),
                          style: TextStyle(
                            color: _getSentimentColor(entry.sentimentLabel!),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (entry.mediaUrl != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    height: 60,
                    width: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Image.network(
                      entry.mediaUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.broken_image,
                          color: Colors.grey,
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getTypeColor() {
    switch (entry.type) {
      case 'voice':
        return AppColors.accent;
      case 'image':
        return AppColors.success;
      default:
        return AppColors.primary;
    }
  }

  IconData _getTypeIcon() {
    switch (entry.type) {
      case 'voice':
        return Icons.mic;
      case 'image':
        return Icons.image;
      default:
        return Icons.text_fields;
    }
  }

  String _getTypeLabel() {
    switch (entry.type) {
      case 'voice':
        return 'Voice Entry';
      case 'image':
        return 'Photo Entry';
      default:
        return 'Text Entry';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Color _getEmotionColor(String emotion) {
    final emotionUpper = emotion.toUpperCase();
    switch (emotionUpper) {
      case 'HAPPY':
      case 'JOY':
      case 'JOYFUL':
      case 'EXCITED':
      case 'THRILLED':
      case 'DELIGHTED':
        return Colors.orange;
      case 'SAD':
      case 'SADNESS':
      case 'DEPRESSED':
      case 'MISERABLE':
        return Colors.blue;
      case 'ANGRY':
      case 'ANGER':
      case 'FURIOUS':
        return Colors.red;
      case 'FEAR':
      case 'FEARFUL':
      case 'TERRIFIED':
      case 'SCARED':
        return Colors.purple;
      case 'LOVE':
      case 'LOVING':
      case 'AFFECTIONATE':
        return Colors.pink;
      case 'PEACEFUL':
      case 'CALM':
      case 'RELAXED':
        return Colors.green;
      case 'ANXIOUS':
      case 'ANXIETY':
      case 'WORRIED':
      case 'NERVOUS':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  IconData _getEmotionIcon(String emotion) {
    final emotionUpper = emotion.toUpperCase();
    switch (emotionUpper) {
      case 'HAPPY':
      case 'JOY':
      case 'JOYFUL':
      case 'EXCITED':
      case 'THRILLED':
      case 'DELIGHTED':
        return Icons.sentiment_very_satisfied;
      case 'SAD':
      case 'SADNESS':
      case 'DEPRESSED':
      case 'MISERABLE':
        return Icons.sentiment_very_dissatisfied;
      case 'ANGRY':
      case 'ANGER':
      case 'FURIOUS':
        return Icons.mood_bad;
      case 'FEAR':
      case 'FEARFUL':
      case 'TERRIFIED':
      case 'SCARED':
        return Icons.warning;
      case 'LOVE':
      case 'LOVING':
      case 'AFFECTIONATE':
        return Icons.favorite;
      case 'PEACEFUL':
      case 'CALM':
      case 'RELAXED':
        return Icons.spa;
      case 'ANXIOUS':
      case 'ANXIETY':
      case 'WORRIED':
      case 'NERVOUS':
        return Icons.psychology;
      default:
        return Icons.sentiment_neutral;
    }
  }

  Color _getSentimentColor(String sentiment) {
    switch (sentiment.toLowerCase()) {
      case 'positive':
        return Colors.green;
      case 'negative':
        return Colors.red;
      case 'neutral':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _getSentimentIcon(String sentiment) {
    switch (sentiment.toLowerCase()) {
      case 'positive':
        return Icons.sentiment_satisfied;
      case 'negative':
        return Icons.sentiment_dissatisfied;
      case 'neutral':
        return Icons.sentiment_neutral;
      default:
        return Icons.sentiment_neutral;
    }
  }

  String _formatEmotionText(String emotion) {
    // Convert emotion to readable format
    // e.g., "JOY" -> "Joy", "HAPPY" -> "Happy", "SAD" -> "Sad"
    final emotionUpper = emotion.toUpperCase();
    
    // Map common emotions to readable format
    final emotionMap = {
      'JOY': 'Joy',
      'JOYFUL': 'Joyful',
      'HAPPY': 'Happy',
      'EXCITED': 'Excited',
      'THRILLED': 'Thrilled',
      'DELIGHTED': 'Delighted',
      'SAD': 'Sad',
      'SADNESS': 'Sadness',
      'DEPRESSED': 'Depressed',
      'MISERABLE': 'Miserable',
      'ANGRY': 'Angry',
      'ANGER': 'Anger',
      'FURIOUS': 'Furious',
      'FEAR': 'Fear',
      'FEARFUL': 'Fearful',
      'TERRIFIED': 'Terrified',
      'SCARED': 'Scared',
      'LOVE': 'Love',
      'LOVING': 'Loving',
      'AFFECTIONATE': 'Affectionate',
      'PEACEFUL': 'Peaceful',
      'CALM': 'Calm',
      'RELAXED': 'Relaxed',
      'ANXIOUS': 'Anxious',
      'ANXIETY': 'Anxiety',
      'WORRIED': 'Worried',
      'NERVOUS': 'Nervous',
      'CONTENT': 'Content',
      'CONTENTED': 'Contented',
      'GRATEFUL': 'Grateful',
      'THANKFUL': 'Thankful',
      'BLESSED': 'Blessed',
      'OPTIMISTIC': 'Optimistic',
      'HOPEFUL': 'Hopeful',
      'CHEERFUL': 'Cheerful',
      'DISGUST': 'Disgust',
      'DISGUSTED': 'Disgusted',
      'FRUSTRATED': 'Frustrated',
      'DISAPPOINTED': 'Disappointed',
      'UPSET': 'Upset',
      'STRESSED': 'Stressed',
      'LONELY': 'Lonely',
      'HURT': 'Hurt',
      'PAIN': 'Pain',
      'SUFFERING': 'Suffering',
      'HEARTBROKEN': 'Heartbroken',
      'CRUSHED': 'Crushed',
      'DEFEATED': 'Defeated',
      'CONFUSED': 'Confused',
      'OVERWHELMED': 'Overwhelmed',
      'EXHAUSTED': 'Exhausted',
      'TIRED': 'Tired',
    };
    
    // Return mapped emotion or format as title case
    if (emotionMap.containsKey(emotionUpper)) {
      return emotionMap[emotionUpper]!;
    }
    
    // Fallback: Convert to title case (e.g., "JOY" -> "Joy")
    if (emotion.length <= 1) {
      return emotion.toUpperCase();
    }
    return emotion[0].toUpperCase() + emotion.substring(1).toLowerCase();
  }
}
