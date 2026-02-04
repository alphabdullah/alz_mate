// progress_tracking_model.dart
import 'emotion_analysis_model.dart';

class WeeklyScore {
  final String patientId;
  final String weekStart;
  final String weekEnd;
  final double score;
  final double earnedPoints;
  final double totalPossiblePoints;
  final String patientState;
  final TaskBreakdown breakdown;
  final String calculatedAt;

  WeeklyScore({
    required this.patientId,
    required this.weekStart,
    required this.weekEnd,
    required this.score,
    required this.earnedPoints,
    required this.totalPossiblePoints,
    required this.patientState,
    required this.breakdown,
    required this.calculatedAt,
  });

  factory WeeklyScore.fromJson(Map<String, dynamic> json) {
    return WeeklyScore(
      patientId: json['patientId'] ?? json['patient_id'] ?? '',
      weekStart: json['weekStart'] ?? json['week_start'] ?? '',
      weekEnd: json['weekEnd'] ?? json['week_end'] ?? '',
      score: (json['score'] ?? 0.0).toDouble(),
      earnedPoints: (json['earnedPoints'] ?? json['earned_points'] ?? 0.0)
          .toDouble(),
      totalPossiblePoints:
          (json['totalPossiblePoints'] ?? json['total_possible_points'] ?? 0.0)
              .toDouble(),
      patientState: json['patientState'] ?? json['patient_state'] ?? 'stable',
      breakdown: TaskBreakdown.fromJson(json['breakdown'] ?? {}),
      calculatedAt: json['calculatedAt'] ?? json['calculated_at'] ?? '',
    );
  }
}

class TaskBreakdown {
  final TaskStats medication;
  final TaskStats appointment;
  final TaskStats meal;
  final TaskStats brainTraining;

  TaskBreakdown({
    required this.medication,
    required this.appointment,
    required this.meal,
    required this.brainTraining,
  });

  factory TaskBreakdown.fromJson(Map<String, dynamic> json) {
    return TaskBreakdown(
      medication: TaskStats.fromJson(json['medication'] ?? {}),
      appointment: TaskStats.fromJson(json['appointment'] ?? {}),
      meal: TaskStats.fromJson(json['meal'] ?? {}),
      brainTraining: TaskStats.fromJson(json['brain_training'] ?? {}),
    );
  }
}

class TaskStats {
  final int completed;
  final int missed;
  final int total;
  final double pointsEarned;
  final double pointsPossible;

  TaskStats({
    required this.completed,
    required this.missed,
    required this.total,
    required this.pointsEarned,
    required this.pointsPossible,
  });

  factory TaskStats.fromJson(Map<String, dynamic> json) {
    return TaskStats(
      completed: json['completed'] ?? 0,
      missed: json['missed'] ?? 0,
      total: json['total'] ?? 0,
      pointsEarned:
          (json['points_earned'] ?? json['pointsEarned'] ?? 0.0).toDouble(),
      pointsPossible: (json['points_possible'] ??
              json['pointsPossible'] ??
              0.0)
          .toDouble(),
    );
  }
}

class WeeklyProgressReport {
  final String patientId;
  final String reportDate;
  final String weekStart;
  final String weekEnd;
  final double weeklyScore;
  final String patientState;
  final String stateDescription;
  final String trend;
  final String trendDescription;
  final double? previousScore;
  final TaskBreakdown breakdown;
  final DeclineDetection declineDetection;
  final String scoreId;

  WeeklyProgressReport({
    required this.patientId,
    required this.reportDate,
    required this.weekStart,
    required this.weekEnd,
    required this.weeklyScore,
    required this.patientState,
    required this.stateDescription,
    required this.trend,
    required this.trendDescription,
    this.previousScore,
    required this.breakdown,
    required this.declineDetection,
    required this.scoreId,
  });

  factory WeeklyProgressReport.fromJson(Map<String, dynamic> json) {
    return WeeklyProgressReport(
      patientId: json['patientId'] ?? json['patient_id'] ?? '',
      reportDate: json['reportDate'] ?? json['report_date'] ?? '',
      weekStart: json['weekStart'] ?? json['week_start'] ?? '',
      weekEnd: json['weekEnd'] ?? json['week_end'] ?? '',
      weeklyScore: (json['weeklyScore'] ?? json['weekly_score'] ?? 0.0)
          .toDouble(),
      patientState: json['patientState'] ?? json['patient_state'] ?? 'stable',
      stateDescription:
          json['stateDescription'] ?? json['state_description'] ?? '',
      trend: json['trend'] ?? 'stable',
      trendDescription:
          json['trendDescription'] ?? json['trend_description'] ?? '',
      previousScore: json['previousScore'] != null ||
              json['previous_score'] != null
          ? (json['previousScore'] ?? json['previous_score'] ?? 0.0).toDouble()
          : null,
      breakdown: TaskBreakdown.fromJson(json['breakdown'] ?? {}),
      declineDetection:
          DeclineDetection.fromJson(json['declineDetection'] ?? {}),
      scoreId: json['scoreId'] ?? json['score_id'] ?? '',
    );
  }
}

class DeclineDetection {
  final bool declineDetected;
  final double? baseline;
  final double currentScore;
  final double? difference;
  final int threshold;
  final int consecutiveWeeks;
  final String? reason;

  DeclineDetection({
    required this.declineDetected,
    this.baseline,
    required this.currentScore,
    this.difference,
    required this.threshold,
    required this.consecutiveWeeks,
    this.reason,
  });

  factory DeclineDetection.fromJson(Map<String, dynamic> json) {
    return DeclineDetection(
      declineDetected:
          json['declineDetected'] ?? json['decline_detected'] ?? false,
      baseline: json['baseline'] != null
          ? (json['baseline'] as num).toDouble()
          : null,
      currentScore: (json['currentScore'] ?? json['current_score'] ?? 0.0)
          .toDouble(),
      difference: json['difference'] != null
          ? (json['difference'] as num).toDouble()
          : null,
      threshold: json['threshold'] ?? 15,
      consecutiveWeeks:
          json['consecutiveWeeks'] ?? json['consecutive_weeks'] ?? 0,
      reason: json['reason'],
    );
  }
}

class CombinedWeeklyReport {
  final WeeklyProgressReport progressReport;
  final EmotionAnalysisSummary emotionAnalysis;
  final CombinedRiskAssessment combinedRiskAssessment;

  CombinedWeeklyReport({
    required this.progressReport,
    required this.emotionAnalysis,
    required this.combinedRiskAssessment,
  });

  factory CombinedWeeklyReport.fromJson(Map<String, dynamic> json) {
    return CombinedWeeklyReport(
      progressReport:
          WeeklyProgressReport.fromJson(json['progressReport'] ?? json),
      emotionAnalysis: EmotionAnalysisSummary.fromJson(
          json['emotionAnalysis'] ?? json['emotion_analysis'] ?? {}),
      combinedRiskAssessment: CombinedRiskAssessment.fromJson(
          json['combinedRiskAssessment'] ??
              json['combined_risk_assessment'] ??
              {}),
    );
  }
}

class EmotionAnalysisSummary {
  final EmotionTrendSummary trendSummary;
  final Map<String, dynamic> weeklyTrends;
  final PersistentNegativeEmotions persistentNegativeEmotions;
  final EmotionVolatility volatility;

  EmotionAnalysisSummary({
    required this.trendSummary,
    required this.weeklyTrends,
    required this.persistentNegativeEmotions,
    required this.volatility,
  });

  factory EmotionAnalysisSummary.fromJson(Map<String, dynamic> json) {
    return EmotionAnalysisSummary(
      trendSummary: EmotionTrendSummary.fromJson(
          json['trendSummary'] ?? json['trend_summary'] ?? {}),
      weeklyTrends: Map<String, dynamic>.from(
          json['weeklyTrends'] ?? json['weekly_trends'] ?? {}),
      persistentNegativeEmotions: PersistentNegativeEmotions.fromJson(
          json['persistentNegativeEmotions'] ??
              json['persistent_negative_emotions'] ??
              {}),
      volatility: EmotionVolatility.fromJson(json['volatility'] ?? {}),
    );
  }
}

class CombinedRiskAssessment {
  final String combinedRiskLevel;
  final String baseRiskLevel;
  final bool riskRaised;
  final String reason;
  final bool declineDetected;
  final bool persistentNegativeDetected;
  final String emotionTrend;
  final String recommendation;

  CombinedRiskAssessment({
    required this.combinedRiskLevel,
    required this.baseRiskLevel,
    required this.riskRaised,
    required this.reason,
    required this.declineDetected,
    required this.persistentNegativeDetected,
    required this.emotionTrend,
    required this.recommendation,
  });

  factory CombinedRiskAssessment.fromJson(Map<String, dynamic> json) {
    return CombinedRiskAssessment(
      combinedRiskLevel:
          json['combinedRiskLevel'] ?? json['combined_risk_level'] ?? 'medium',
      baseRiskLevel:
          json['baseRiskLevel'] ?? json['base_risk_level'] ?? 'medium',
      riskRaised: json['riskRaised'] ?? json['risk_raised'] ?? false,
      reason: json['reason'] ?? '',
      declineDetected:
          json['declineDetected'] ?? json['decline_detected'] ?? false,
      persistentNegativeDetected: json['persistentNegativeDetected'] ??
          json['persistent_negative_detected'] ??
          false,
      emotionTrend: json['emotionTrend'] ?? json['emotion_trend'] ?? 'stable',
      recommendation: json['recommendation'] ?? '',
    );
  }
}

