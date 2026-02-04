import 'package:flutter/material.dart';
import '../../core/constants/app_styles.dart';

class AlertsPage extends StatelessWidget {
  const AlertsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'System Alerts',
            style: AppStyles.titleLarge,
          ),
          const SizedBox(height: 16),
          Text(
            'Monitor SOS alerts and system notifications here.',
            style: AppStyles.bodyMedium,
          ),
        ],
      ),
    );
  }
}

