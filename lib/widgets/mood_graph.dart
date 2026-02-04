import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/models/mood_entry_model.dart';

class MoodGraph extends StatelessWidget {
  final List<MoodEntryModel> moodEntries;

  const MoodGraph({
    super.key,
    required this.moodEntries,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mood Trends (Last 7 Days)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: CustomPaint(
              painter: MoodGraphPainter(moodEntries),
              size: Size.infinite,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildLegendItem('Happy', AppColors.success),
              _buildLegendItem('Neutral', AppColors.accent),
              _buildLegendItem('Sad', AppColors.danger),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}

class MoodGraphPainter extends CustomPainter {
  final List<MoodEntryModel> moodEntries;

  MoodGraphPainter(this.moodEntries);

  @override
  void paint(Canvas canvas, Size size) {
    if (moodEntries.isEmpty) return;

    final paint = Paint()
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final path = Path();
    final pointPaint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < moodEntries.length; i++) {
      final x = (i / (moodEntries.length - 1)) * size.width;
      final y = size.height - (moodEntries[i].score * size.height);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }

      // Draw points
      pointPaint.color = _getMoodColor(moodEntries[i].score);
      canvas.drawCircle(Offset(x, y), 4, pointPaint);
    }

    paint.color = AppColors.primary;
    canvas.drawPath(path, paint);
  }

  Color _getMoodColor(double score) {
    if (score > 0.6) return AppColors.success;
    if (score > 0.4) return AppColors.accent;
    return AppColors.danger;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
