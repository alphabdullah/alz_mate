// emotion_analysis_model.dart
class EmotionAnalysisResult {
  final String patientId;
  final String? entryId;
  final String timestamp;
  final EmotionAnalysis analysis;
  final String? audioUrl;

  EmotionAnalysisResult({
    required this.patientId,
    this.entryId,
    required this.timestamp,
    required this.analysis,
    this.audioUrl,
  });

  factory EmotionAnalysisResult.fromJson(Map<String, dynamic> json) {
    return EmotionAnalysisResult(
      patientId: json['patient_id'] ?? '',
      entryId: json['entry_id'],
      timestamp: json['timestamp'] ?? '',
      analysis: EmotionAnalysis.fromJson(json['analysis'] ?? {}),
      audioUrl: json['audio_url'],
    );
  }

  Map<String, dynamic> toJson() => {
        'patient_id': patientId,
        'entry_id': entryId,
        'timestamp': timestamp,
        'analysis': analysis.toJson(),
        'audio_url': audioUrl,
      };
}

class EmotionAnalysis {
  final EmotionData primaryEmotion;
  final EmotionData? secondaryEmotion;
  final String interpretationTag;
  final bool moodRisk;
  final String? processedText;

  EmotionAnalysis({
    required this.primaryEmotion,
    this.secondaryEmotion,
    required this.interpretationTag,
    required this.moodRisk,
    this.processedText,
  });

  factory EmotionAnalysis.fromJson(Map<String, dynamic> json) {
    return EmotionAnalysis(
      primaryEmotion: EmotionData.fromJson(
          json['primary_emotion'] ?? json['primaryEmotion'] ?? {}),
      secondaryEmotion: json['secondary_emotion'] != null ||
              json['secondaryEmotion'] != null
          ? EmotionData.fromJson(
              json['secondary_emotion'] ?? json['secondaryEmotion'] ?? {})
          : null,
      interpretationTag:
          json['interpretation_tag'] ?? json['interpretationTag'] ?? '',
      moodRisk: json['mood_risk'] ?? json['moodRisk'] ?? false,
      processedText: json['processed_text'] ?? json['processedText'],
    );
  }

  Map<String, dynamic> toJson() => {
        'primary_emotion': primaryEmotion.toJson(),
        'secondary_emotion': secondaryEmotion?.toJson(),
        'interpretation_tag': interpretationTag,
        'mood_risk': moodRisk,
        'processed_text': processedText,
      };
}

class EmotionData {
  final String emotion;
  final double confidence;
  final int intensity;
  final String? interpretationTag;

  EmotionData({
    required this.emotion,
    required this.confidence,
    required this.intensity,
    this.interpretationTag,
  });

  factory EmotionData.fromJson(Map<String, dynamic> json) {
    return EmotionData(
      emotion: json['emotion'] ?? '',
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      intensity: json['intensity'] ?? 0,
      interpretationTag: json['interpretation_tag'] ?? json['interpretationTag'],
    );
  }

  Map<String, dynamic> toJson() => {
        'emotion': emotion,
        'confidence': confidence,
        'intensity': intensity,
        'interpretation_tag': interpretationTag,
      };
}

class EmotionEntry {
  final String id;
  final String patientId;
  final String timestamp;
  final String? journalText;
  final String? processedText;
  final String primaryEmotion;
  final int primaryIntensity;
  final double primaryConfidence;
  final String? secondaryEmotion;
  final int? secondaryIntensity;
  final double? secondaryConfidence;
  final String? interpretationTag;
  final bool moodRisk;

  EmotionEntry({
    required this.id,
    required this.patientId,
    required this.timestamp,
    this.journalText,
    this.processedText,
    required this.primaryEmotion,
    required this.primaryIntensity,
    required this.primaryConfidence,
    this.secondaryEmotion,
    this.secondaryIntensity,
    this.secondaryConfidence,
    this.interpretationTag,
    required this.moodRisk,
  });

  factory EmotionEntry.fromJson(Map<String, dynamic> json) {
    return EmotionEntry(
      id: json['id'] ?? '',
      patientId: json['patientId'] ?? json['patient_id'] ?? '',
      timestamp: json['timestamp'] ?? '',
      journalText: json['journalText'] ?? json['journal_text'],
      processedText: json['processedText'] ?? json['processed_text'],
      primaryEmotion:
          json['primaryEmotion'] ?? json['primary_emotion'] ?? '',
      primaryIntensity:
          json['primaryIntensity'] ?? json['primary_intensity'] ?? 0,
      primaryConfidence:
          (json['primaryConfidence'] ?? json['primary_confidence'] ?? 0.0)
              .toDouble(),
      secondaryEmotion:
          json['secondaryEmotion'] ?? json['secondary_emotion'],
      secondaryIntensity:
          json['secondaryIntensity'] ?? json['secondary_intensity'],
      secondaryConfidence: json['secondaryConfidence'] != null ||
              json['secondary_confidence'] != null
          ? (json['secondaryConfidence'] ?? json['secondary_confidence'] ?? 0.0)
              .toDouble()
          : null,
      interpretationTag:
          json['interpretationTag'] ?? json['interpretation_tag'],
      moodRisk: json['moodRisk'] ?? json['mood_risk'] ?? false,
    );
  }
}

class EmotionTrends {
  final String patientId;
  final int periodDays;
  final int totalEntries;
  final Map<String, int> emotionCounts;
  final Map<String, double> averageIntensities;
  final int moodRiskCount;
  final double moodRiskPercentage;
  final List<EmotionTrend> trends;
  final String startDate;
  final String endDate;

  EmotionTrends({
    required this.patientId,
    required this.periodDays,
    required this.totalEntries,
    required this.emotionCounts,
    required this.averageIntensities,
    required this.moodRiskCount,
    required this.moodRiskPercentage,
    required this.trends,
    required this.startDate,
    required this.endDate,
  });

  factory EmotionTrends.fromJson(Map<String, dynamic> json) {
    return EmotionTrends(
      patientId: json['patient_id'] ?? json['patientId'] ?? '',
      periodDays: json['period_days'] ?? json['periodDays'] ?? 0,
      totalEntries: json['total_entries'] ?? json['totalEntries'] ?? 0,
      emotionCounts: Map<String, int>.from(
          json['emotion_counts'] ?? json['emotionCounts'] ?? {}),
      averageIntensities: Map<String, double>.from(
          (json['average_intensities'] ?? json['averageIntensities'] ?? {})
              .map((k, v) => MapEntry(k, (v as num).toDouble()))),
      moodRiskCount: json['mood_risk_count'] ?? json['moodRiskCount'] ?? 0,
      moodRiskPercentage:
          (json['mood_risk_percentage'] ?? json['moodRiskPercentage'] ?? 0.0)
              .toDouble(),
      trends: (json['trends'] as List? ?? [])
          .map((t) => EmotionTrend.fromJson(t))
          .toList(),
      startDate: json['start_date'] ?? json['startDate'] ?? '',
      endDate: json['end_date'] ?? json['endDate'] ?? '',
    );
  }
}

class EmotionTrend {
  final String emotion;
  final int count;
  final double percentage;
  final double averageIntensity;
  final String description;

  EmotionTrend({
    required this.emotion,
    required this.count,
    required this.percentage,
    required this.averageIntensity,
    required this.description,
  });

  factory EmotionTrend.fromJson(Map<String, dynamic> json) {
    return EmotionTrend(
      emotion: json['emotion'] ?? '',
      count: json['count'] ?? 0,
      percentage: (json['percentage'] ?? 0.0).toDouble(),
      averageIntensity: (json['average_intensity'] ??
              json['averageIntensity'] ??
              0.0)
          .toDouble(),
      description: json['description'] ?? '',
    );
  }
}

class DailyEmotionSummary {
  final String patientId;
  final String date;
  final int totalEntries;
  final List<DailyEmotion> emotions;
  final bool moodRisk;

  DailyEmotionSummary({
    required this.patientId,
    required this.date,
    required this.totalEntries,
    required this.emotions,
    required this.moodRisk,
  });

  factory DailyEmotionSummary.fromJson(Map<String, dynamic> json) {
    return DailyEmotionSummary(
      patientId: json['patient_id'] ?? json['patientId'] ?? '',
      date: json['date'] ?? '',
      totalEntries: json['total_entries'] ?? json['totalEntries'] ?? 0,
      emotions: (json['emotions'] as List? ?? [])
          .map((e) => DailyEmotion.fromJson(e))
          .toList(),
      moodRisk: json['mood_risk'] ?? json['moodRisk'] ?? false,
    );
  }
}

class DailyEmotion {
  final String emotion;
  final int count;
  final double maxIntensity;
  final double avgIntensity;

  DailyEmotion({
    required this.emotion,
    required this.count,
    required this.maxIntensity,
    required this.avgIntensity,
  });

  factory DailyEmotion.fromJson(Map<String, dynamic> json) {
    return DailyEmotion(
      emotion: json['emotion'] ?? '',
      count: json['count'] ?? 0,
      maxIntensity: (json['max_intensity'] ?? json['maxIntensity'] ?? 0.0)
          .toDouble(),
      avgIntensity: (json['avg_intensity'] ?? json['avgIntensity'] ?? 0.0)
          .toDouble(),
    );
  }
}

class WeeklyEmotionSummary {
  final EmotionTrends trends;
  final List<String> summaryInsights;

  WeeklyEmotionSummary({
    required this.trends,
    required this.summaryInsights,
  });

  factory WeeklyEmotionSummary.fromJson(Map<String, dynamic> json) {
    return WeeklyEmotionSummary(
      trends: EmotionTrends.fromJson(json),
      summaryInsights:
          (json['summary_insights'] ?? json['summaryInsights'] ?? [])
              .map((s) => s.toString())
              .toList(),
    );
  }
}

class EmotionShift {
  final bool shiftDetected;
  final String emotion;
  final double? earlyAverage;
  final double? lateAverage;
  final double? increase;
  final double threshold;
  final int periodDays;
  final String? reason;

  EmotionShift({
    required this.shiftDetected,
    required this.emotion,
    this.earlyAverage,
    this.lateAverage,
    this.increase,
    required this.threshold,
    required this.periodDays,
    this.reason,
  });

  factory EmotionShift.fromJson(Map<String, dynamic> json) {
    return EmotionShift(
      shiftDetected: json['shiftDetected'] ?? json['shift_detected'] ?? false,
      emotion: json['emotion'] ?? '',
      earlyAverage: json['earlyAverage'] != null ||
              json['early_average'] != null
          ? (json['earlyAverage'] ?? json['early_average'] ?? 0.0).toDouble()
          : null,
      lateAverage: json['lateAverage'] != null || json['late_average'] != null
          ? (json['lateAverage'] ?? json['late_average'] ?? 0.0).toDouble()
          : null,
      increase: json['increase'] != null
          ? (json['increase'] as num).toDouble()
          : null,
      threshold: (json['threshold'] ?? 20.0).toDouble(),
      periodDays: json['periodDays'] ?? json['period_days'] ?? 7,
      reason: json['reason'],
    );
  }
}

class PersistentNegativeEmotions {
  final bool persistentNegativeDetected;
  final int daysWithHighNegativeEmotions;
  final int requiredDays;
  final List<String> emotions;
  final int threshold;

  PersistentNegativeEmotions({
    required this.persistentNegativeDetected,
    required this.daysWithHighNegativeEmotions,
    required this.requiredDays,
    required this.emotions,
    required this.threshold,
  });

  factory PersistentNegativeEmotions.fromJson(Map<String, dynamic> json) {
    return PersistentNegativeEmotions(
      persistentNegativeDetected: json['persistentNegativeDetected'] ??
          json['persistent_negative_detected'] ??
          false,
      daysWithHighNegativeEmotions:
          json['daysWithHighNegativeEmotions'] ??
              json['days_with_high_negative_emotions'] ??
              0,
      requiredDays: json['requiredDays'] ?? json['required_days'] ?? 3,
      emotions: (json['emotions'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
      threshold: json['threshold'] ?? 70,
    );
  }
}

class EmotionVolatility {
  final bool volatilityDetected;
  final double coefficientOfVariation;
  final double threshold;
  final double meanScore;
  final double stdDeviation;
  final int daysAnalyzed;
  final int periodDays;
  final String? reason;

  EmotionVolatility({
    required this.volatilityDetected,
    required this.coefficientOfVariation,
    required this.threshold,
    required this.meanScore,
    required this.stdDeviation,
    required this.daysAnalyzed,
    required this.periodDays,
    this.reason,
  });

  factory EmotionVolatility.fromJson(Map<String, dynamic> json) {
    return EmotionVolatility(
      volatilityDetected:
          json['volatilityDetected'] ?? json['volatility_detected'] ?? false,
      coefficientOfVariation:
          (json['coefficientOfVariation'] ??
                  json['coefficient_of_variation'] ??
                  0.0)
              .toDouble(),
      threshold: (json['threshold'] ?? 0.4).toDouble(),
      meanScore: (json['meanScore'] ?? json['mean_score'] ?? 0.0).toDouble(),
      stdDeviation:
          (json['stdDeviation'] ?? json['std_deviation'] ?? 0.0).toDouble(),
      daysAnalyzed: json['daysAnalyzed'] ?? json['days_analyzed'] ?? 0,
      periodDays: json['periodDays'] ?? json['period_days'] ?? 7,
      reason: json['reason'],
    );
  }
}

class EmotionTrendSummary {
  final String trend; // 'improving', 'stable', 'worsening', 'no_data'
  final String description;
  final String patientId;
  final double? averageNegativeIntensity;
  final double? earlyAverage;
  final double? lateAverage;
  final int? totalEntries;
  final int? moodRiskCount;

  EmotionTrendSummary({
    required this.trend,
    required this.description,
    required this.patientId,
    this.averageNegativeIntensity,
    this.earlyAverage,
    this.lateAverage,
    this.totalEntries,
    this.moodRiskCount,
  });

  factory EmotionTrendSummary.fromJson(Map<String, dynamic> json) {
    return EmotionTrendSummary(
      trend: json['trend'] ?? 'no_data',
      description: json['description'] ?? '',
      patientId: json['patientId'] ?? json['patient_id'] ?? '',
      averageNegativeIntensity: json['averageNegativeIntensity'] != null ||
              json['average_negative_intensity'] != null
          ? (json['averageNegativeIntensity'] ??
                  json['average_negative_intensity'] ??
                  0.0)
              .toDouble()
          : null,
      earlyAverage: json['earlyAverage'] != null ||
              json['early_average'] != null
          ? (json['earlyAverage'] ?? json['early_average'] ?? 0.0).toDouble()
          : null,
      lateAverage: json['lateAverage'] != null || json['late_average'] != null
          ? (json['lateAverage'] ?? json['late_average'] ?? 0.0).toDouble()
          : null,
      totalEntries: json['totalEntries'] ?? json['total_entries'],
      moodRiskCount: json['moodRiskCount'] ?? json['mood_risk_count'],
    );
  }
}

