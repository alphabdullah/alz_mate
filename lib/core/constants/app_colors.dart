import 'package:flutter/material.dart';

class AppColors {
  // Primary brand colors
  static const Color primary = Color(0xFF6A5AE0);
  static const Color primaryLight = Color(0xFF8B7CE8);
  static const Color primaryDark = Color(0xFF5A4BCF);

  // Secondary colors
  static const Color secondary = Color(0xFFF2F2F7);
  static const Color secondaryLight = Color(0xFFF8F8FC);
  static const Color secondaryDark = Color(0xFFE5E5EA);

  // Accent colors
  static const Color accent = Color(0xFFFFB74D);
  static const Color accentLight = Color(0xFFFFCC80);
  static const Color accentDark = Color(0xFFFF9800);

  // Status colors
  static const Color success = Color(0xFF66BB6A);
  static const Color successLight = Color(0xFF81C784);
  static const Color successDark = Color(0xFF4CAF50);

  static const Color warning = Color(0xFFFFB74D);
  static const Color warningLight = Color(0xFFFFCC80);
  static const Color warningDark = Color(0xFFFF9800);

  static const Color danger = Color(0xFFEF5350);
  static const Color dangerLight = Color(0xFFE57373);
  static const Color dangerDark = Color(0xFFD32F2F);
  static const Color error = Color(0xFFD32F2F);

  static const Color info = Color(0xFF42A5F5);
  static const Color infoLight = Color(0xFF64B5F6);
  static const Color infoDark = Color(0xFF1976D2);

  // Neutral colors
  static const Color background = Color(0xFFF7F8FC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF5F5F5);

  // Text colors
  static const Color text = Color(0xFF2E2E2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color textLight = Color(0xFFD1D5DB);

  // Border colors
  static const Color border = Color(0xFFE5E7EB);
  static const Color borderLight = Color(0xFFF3F4F6);
  static const Color borderDark = Color(0xFFD1D5DB);

  // Shadow colors
  static const Color cardShadow = Color(0x1A000000); // 10% opacity
  static const Color buttonShadow = Color(0x26000000); // 15% opacity
  static const Color modalShadow = Color(0x33000000); // 20% opacity

  // Gradient colors
  static const List<Color> primaryGradient = [
    Color(0xFF6A5AE0),
    Color(0xFF8B7CE8),
  ];

  static const List<Color> successGradient = [
    Color(0xFF66BB6A),
    Color(0xFF81C784),
  ];

  static const List<Color> warningGradient = [
    Color(0xFFFFB74D),
    Color(0xFFFFCC80),
  ];

  static const List<Color> dangerGradient = [
    Color(0xFFEF5350),
    Color(0xFFE57373),
  ];

  // Mood-specific colors
  static const Color moodHappy = Color(0xFF66BB6A);
  static const Color moodContent = Color(0xFFFFB74D);
  static const Color moodNeutral = Color(0xFF9E9E9E);
  static const Color moodSad = Color(0xFFEF5350);
  static const Color moodAnxious = Color(0xFFE91E63);
  static const Color moodConfused = Color(0xFFFF9800);

  // Game category colors
  static const Color gameMemory = Color(0xFF6A5AE0);
  static const Color gameLogic = Color(0xFFFFB74D);
  static const Color gameSpeed = Color(0xFF66BB6A);
  static const Color gameCreativity = Color(0xFFE91E63);
  static const Color gameLanguage = Color(0xFF00BCD4);
  static const Color gamePattern = Color(0xFF9C27B0);

  // Emergency colors
  static const Color emergency = Color(0xFFD32F2F);
  static const Color emergencyLight = Color(0xFFEF5350);
  static const Color emergencyBackground = Color(0xFFFFEBEE);

  // Disabled colors
  static const Color disabled = Color(0xFFE0E0E0);
  static const Color disabledText = Color(0xFFBDBDBD);

  // Overlay colors
  static const Color overlay = Color(0x80000000); // 50% opacity
  static const Color overlayLight = Color(0x40000000); // 25% opacity
  static const Color overlayDark = Color(0xB3000000); // 70% opacity
}
