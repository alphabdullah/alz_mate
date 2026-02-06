import 'package:cloud_firestore/cloud_firestore.dart';

class BehaviorAnalysisModel {
  final String id;
  final String patientId;
  final String patientName;
  final double overallScore; // 0-100
  final double sentimentScore; // 0-100
  final double reminderScore; // 0-100
  final double gameScore; // 0-100
  final String overallGrade; // A+ to F
  final String healthStatus; // Excellent, Good, Fair, Needs Attention
  final DateTime analyzedAt;
  final DateTime periodStart;
  final DateTime periodEnd;
  final int totalJournalEntries;
  final int totalReminders;
  final int completedReminders;
  final int totalGames;
  final double averageSentiment; // -1.0 to 1.0
  final double reminderCompletionRate; // 0.0 to 1.0
  final double averageGamePerformance; // 0.0 to 1.0
  final Map<String, dynamic>? metadata;

  BehaviorAnalysisModel({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.overallScore,
    required this.sentimentScore,
    required this.reminderScore,
    required this.gameScore,
    required this.overallGrade,
    required this.healthStatus,
    required this.analyzedAt,
    required this.periodStart,
    required this.periodEnd,
    required this.totalJournalEntries,
    required this.totalReminders,
    required this.completedReminders,
    required this.totalGames,
    required this.averageSentiment,
    required this.reminderCompletionRate,
    required this.averageGamePerformance,
    this.metadata,
  });

  factory BehaviorAnalysisModel.fromMap(Map<String, dynamic> map) {
    return BehaviorAnalysisModel(
      id: map['id'] ?? '',
      patientId: map['patientId'] ?? '',
      patientName: map['patientName'] ?? '',
      overallScore: map['overallScore']?.toDouble() ?? 0.0,
      sentimentScore: map['sentimentScore']?.toDouble() ?? 0.0,
      reminderScore: map['reminderScore']?.toDouble() ?? 0.0,
      gameScore: map['gameScore']?.toDouble() ?? 0.0,
      overallGrade: map['overallGrade'] ?? 'F',
      healthStatus: map['healthStatus'] ?? 'Unknown',
      analyzedAt: map['analyzedAt'] != null
          ? (map['analyzedAt'] as Timestamp).toDate()
          : DateTime.now(),
      periodStart: map['periodStart'] != null
          ? (map['periodStart'] as Timestamp).toDate()
          : DateTime.now(),
      periodEnd: map['periodEnd'] != null
          ? (map['periodEnd'] as Timestamp).toDate()
          : DateTime.now(),
      totalJournalEntries: map['totalJournalEntries']?.toInt() ?? 0,
      totalReminders: map['totalReminders']?.toInt() ?? 0,
      completedReminders: map['completedReminders']?.toInt() ?? 0,
      totalGames: map['totalGames']?.toInt() ?? 0,
      averageSentiment: map['averageSentiment']?.toDouble() ?? 0.0,
      reminderCompletionRate: map['reminderCompletionRate']?.toDouble() ?? 0.0,
      averageGamePerformance: map['averageGamePerformance']?.toDouble() ?? 0.0,
      metadata: map['metadata'],
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'patientId': patientId,
        'patientName': patientName,
        'overallScore': overallScore,
        'sentimentScore': sentimentScore,
        'reminderScore': reminderScore,
        'gameScore': gameScore,
        'overallGrade': overallGrade,
        'healthStatus': healthStatus,
        'analyzedAt': Timestamp.fromDate(analyzedAt),
        'periodStart': Timestamp.fromDate(periodStart),
        'periodEnd': Timestamp.fromDate(periodEnd),
        'totalJournalEntries': totalJournalEntries,
        'totalReminders': totalReminders,
        'completedReminders': completedReminders,
        'totalGames': totalGames,
        'averageSentiment': averageSentiment,
        'reminderCompletionRate': reminderCompletionRate,
        'averageGamePerformance': averageGamePerformance,
        'metadata': metadata,
      };

  BehaviorAnalysisModel copyWith({
    String? id,
    String? patientId,
    String? patientName,
    double? overallScore,
    double? sentimentScore,
    double? reminderScore,
    double? gameScore,
    String? overallGrade,
    String? healthStatus,
    DateTime? analyzedAt,
    DateTime? periodStart,
    DateTime? periodEnd,
    int? totalJournalEntries,
    int? totalReminders,
    int? completedReminders,
    int? totalGames,
    double? averageSentiment,
    double? reminderCompletionRate,
    double? averageGamePerformance,
    Map<String, dynamic>? metadata,
  }) {
    return BehaviorAnalysisModel(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      overallScore: overallScore ?? this.overallScore,
      sentimentScore: sentimentScore ?? this.sentimentScore,
      reminderScore: reminderScore ?? this.reminderScore,
      gameScore: gameScore ?? this.gameScore,
      overallGrade: overallGrade ?? this.overallGrade,
      healthStatus: healthStatus ?? this.healthStatus,
      analyzedAt: analyzedAt ?? this.analyzedAt,
      periodStart: periodStart ?? this.periodStart,
      periodEnd: periodEnd ?? this.periodEnd,
      totalJournalEntries: totalJournalEntries ?? this.totalJournalEntries,
      totalReminders: totalReminders ?? this.totalReminders,
      completedReminders: completedReminders ?? this.completedReminders,
      totalGames: totalGames ?? this.totalGames,
      averageSentiment: averageSentiment ?? this.averageSentiment,
      reminderCompletionRate:
          reminderCompletionRate ?? this.reminderCompletionRate,
      averageGamePerformance:
          averageGamePerformance ?? this.averageGamePerformance,
      metadata: metadata ?? this.metadata,
    );
  }

  // Utility getters
  bool get isExcellent => overallScore >= 80;
  bool get isGood => overallScore >= 60 && overallScore < 80;
  bool get isFair => overallScore >= 40 && overallScore < 60;
  bool get needsAttention => overallScore < 40;

  String get scoreColor {
    if (overallScore >= 80) return '0xFF4CAF50'; // Green
    if (overallScore >= 60) return '0xFFFFC107'; // Yellow
    if (overallScore >= 40) return '0xFFFF9800'; // Orange
    return '0xFFF44336'; // Red
  }

  @override
  String toString() {
    return 'BehaviorAnalysisModel(patientName: $patientName, overallScore: $overallScore, grade: $overallGrade)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BehaviorAnalysisModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
