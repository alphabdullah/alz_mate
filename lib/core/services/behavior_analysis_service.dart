import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/behavior_analysis_model.dart';
import '../models/journal_entry_model.dart';
import '../models/reminder_model.dart';
import '../models/game_score_model.dart';
import 'firestore_service.dart';

class BehaviorAnalysisService {
  static final BehaviorAnalysisService _instance =
      BehaviorAnalysisService._internal();
  factory BehaviorAnalysisService() => _instance;
  BehaviorAnalysisService._internal();

  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Weights for each component
  static const double sentimentWeight = 0.30; // 30%
  static const double reminderWeight = 0.50; // 50%
  static const double gameWeight = 0.20; // 20%

  /// Main analysis method - analyzes patient behavior and saves to Firebase.
  /// Uses only today's data by default (sentiment from today's journals, today's reminders, today's games).
  Future<BehaviorAnalysisModel> analyzePatientBehavior(
    String patientId, {
    DateTime? startDate,
    DateTime? endDate,
    bool saveToFirebase = true,
  }) async {
    try {
      // Default: today only
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);
      final end = endDate ?? now;
      final start = startDate ?? startOfToday;

      // Fetch patient data
      final patient = await _firestoreService.getUserById(patientId);
      if (patient == null) {
        throw Exception('Patient not found');
      }

      // Fetch all data for user (no composite indexes required), then filter by date in memory
      final results = await Future.wait([
        _firestoreService.getJournalEntriesByUserId(patientId),
        _firestoreService.getRemindersByUserId(patientId),
        _firestoreService.getGameScoresByUserId(patientId),
      ]);

      final allJournalEntries = results[0] as List<JournalEntryModel>;
      final allReminders = results[1] as List<ReminderModel>;
      final allGameScores = results[2] as List<GameScoreModel>;

      // Filter by date range in memory
      final journalEntries = allJournalEntries
          .where((e) =>
              !e.timestamp.isBefore(start) && !e.timestamp.isAfter(end))
          .toList();
      final reminders = allReminders
          .where((r) => !r.time.isBefore(start) && !r.time.isAfter(end))
          .toList();
      final gameScores = allGameScores
          .where((g) =>
              !g.playedAt.isBefore(start) && !g.playedAt.isAfter(end))
          .toList();

      // Calculate individual scores
      final sentimentScore = _calculateSentimentScore(journalEntries);
      final reminderScore = _calculateReminderScore(reminders);
      final gameScore = _calculateGameScore(gameScores);

      // Calculate overall score (weighted average)
      final overallScore = (sentimentScore * sentimentWeight) +
          (reminderScore * reminderWeight) +
          (gameScore * gameWeight);

      // Calculate additional metrics
      final completedReminders =
          reminders.where((r) => r.isCompleted).length;
      final averageSentiment = journalEntries.isNotEmpty
          ? journalEntries
                  .where((e) => e.sentimentScore != null)
                  .map((e) => e.sentimentScore!)
                  .fold(0.0, (sum, score) => sum + score) /
              journalEntries.where((e) => e.sentimentScore != null).length
          : 0.0;
      final reminderCompletionRate =
          reminders.isNotEmpty ? completedReminders / reminders.length : 0.0;
      final averageGamePerformance = gameScores.isNotEmpty
          ? gameScores.map((g) => g.scorePercentage / 100).fold(
                  0.0, (sum, perf) => sum + perf) /
              gameScores.length
          : 0.0;

      // Create analysis model
      final analysis = BehaviorAnalysisModel(
        id: '', // Will be set by Firestore
        patientId: patientId,
        patientName: patient.name,
        overallScore: overallScore,
        sentimentScore: sentimentScore,
        reminderScore: reminderScore,
        gameScore: gameScore,
        overallGrade: _getOverallGrade(overallScore),
        healthStatus: _getHealthStatus(overallScore),
        analyzedAt: DateTime.now(),
        periodStart: start,
        periodEnd: end,
        totalJournalEntries: journalEntries.length,
        totalReminders: reminders.length,
        completedReminders: completedReminders,
        totalGames: gameScores.length,
        averageSentiment: averageSentiment,
        reminderCompletionRate: reminderCompletionRate,
        averageGamePerformance: averageGamePerformance,
      );

      // Save to Firebase if requested
      if (saveToFirebase) {
        final savedAnalysis = await _saveAnalysisToFirebase(analysis);
        return savedAnalysis;
      }

      return analysis;
    } catch (e) {
      print('Error analyzing patient behavior: $e');
      rethrow;
    }
  }

  /// Calculate sentiment score from journal entries (0-100)
  double _calculateSentimentScore(List<JournalEntryModel> entries) {
    if (entries.isEmpty) return 0.0;

    // Filter entries that have sentiment scores
    final entriesWithSentiment =
        entries.where((e) => e.sentimentScore != null).toList();

    if (entriesWithSentiment.isEmpty) return 0.0;

    // Average sentiment score (-1.0 to 1.0)
    final avgSentiment = entriesWithSentiment
            .map((e) => e.sentimentScore!)
            .fold(0.0, (sum, score) => sum + score) /
        entriesWithSentiment.length;

    // Normalize to 0-100 (convert -1.0 to 1.0 range to 0-100)
    // -1.0 -> 0, 0.0 -> 50, 1.0 -> 100
    return ((avgSentiment + 1.0) / 2.0) * 100;
  }

  /// Calculate reminder completion score (0-100)
  double _calculateReminderScore(List<ReminderModel> reminders) {
    if (reminders.isEmpty) return 0.0;

    final completedCount = reminders.where((r) => r.isCompleted).length;
    return (completedCount / reminders.length) * 100;
  }

  /// Calculate game performance score (0-100)
  double _calculateGameScore(List<GameScoreModel> scores) {
    if (scores.isEmpty) return 0.0;

    // Average score percentage
    final avgScorePercentage =
        scores.map((s) => s.scorePercentage).fold(0.0, (sum, p) => sum + p) /
            scores.length;

    // Time performance bonus (faster = better)
    // Games completed in less time get bonus points
    final avgDurationSeconds =
        scores.map((s) => s.duration.inSeconds).fold(0, (sum, d) => sum + d) /
            scores.length;

    // Bonus for completing games quickly (max 10 points)
    // Assuming average good time is 60 seconds, give bonus for completing faster
    double timeBonus = 0.0;
    if (avgDurationSeconds > 0 && avgDurationSeconds < 120) {
      timeBonus = (120 - avgDurationSeconds) / 120 * 10;
    }

    // Combine score percentage (90%) and time bonus (10%)
    return (avgScorePercentage * 0.9) + timeBonus.clamp(0.0, 10.0);
  }

  /// Convert score to letter grade
  String _getOverallGrade(double score) {
    if (score >= 95) return 'A+';
    if (score >= 90) return 'A';
    if (score >= 85) return 'A-';
    if (score >= 80) return 'B+';
    if (score >= 75) return 'B';
    if (score >= 70) return 'B-';
    if (score >= 65) return 'C+';
    if (score >= 60) return 'C';
    if (score >= 55) return 'C-';
    if (score >= 50) return 'D';
    return 'F';
  }

  /// Get health status based on score
  String _getHealthStatus(double score) {
    if (score >= 80) return 'Excellent';
    if (score >= 60) return 'Good';
    if (score >= 40) return 'Fair';
    return 'Needs Attention';
  }

  /// Save analysis to Firebase
  Future<BehaviorAnalysisModel> _saveAnalysisToFirebase(
      BehaviorAnalysisModel analysis) async {
    try {
      final docRef = await _firestore.collection('behavior_analyses').add(
            analysis.toMap(),
          );

      return analysis.copyWith(id: docRef.id);
    } catch (e) {
      print('Error saving behavior analysis to Firebase: $e');
      rethrow;
    }
  }

  /// Get saved analyses for a patient (no composite index required).
  /// Fetches by patientId only, then sorts by analyzedAt descending in memory.
  Future<List<BehaviorAnalysisModel>> getPatientAnalyses(
    String patientId, {
    int limit = 500,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection('behavior_analyses')
          .where('patientId', isEqualTo: patientId)
          .get();

      final list = querySnapshot.docs
          .map((doc) => BehaviorAnalysisModel.fromMap(
              {...doc.data(), 'id': doc.id}))
          .toList();

      list.sort((a, b) => b.analyzedAt.compareTo(a.analyzedAt));
      return limit > 0 && list.length > limit
          ? list.sublist(0, limit)
          : list;
    } catch (e) {
      print('Error fetching patient analyses: $e');
      return [];
    }
  }

  /// Get latest analysis for a patient
  Future<BehaviorAnalysisModel?> getLatestAnalysis(String patientId) async {
    try {
      final analyses = await getPatientAnalyses(patientId, limit: 1);
      return analyses.isNotEmpty ? analyses.first : null;
    } catch (e) {
      print('Error fetching latest analysis: $e');
      return null;
    }
  }

  /// Get analyses for all patients assigned to a caregiver
  Future<Map<String, BehaviorAnalysisModel>> getCaregiverPatientsAnalyses(
    String caregiverId,
  ) async {
    try {
      // Get all patients for this caregiver
      final patients =
          await _firestoreService.getCaregiverPatients(caregiverId);

      final analysesMap = <String, BehaviorAnalysisModel>{};

      // Fetch latest analysis for each patient
      for (final patient in patients) {
        final latestAnalysis = await getLatestAnalysis(patient.id);
        if (latestAnalysis != null) {
          analysesMap[patient.id] = latestAnalysis;
        }
      }

      return analysesMap;
    } catch (e) {
      print('Error fetching caregiver patients analyses: $e');
      return {};
    }
  }

  /// Delete an analysis
  Future<void> deleteAnalysis(String analysisId) async {
    try {
      await _firestore.collection('behavior_analyses').doc(analysisId).delete();
    } catch (e) {
      print('Error deleting analysis: $e');
      rethrow;
    }
  }
}
