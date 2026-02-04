// progress_tracking_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/progress_tracking_model.dart';
import '../../core/constants/api_config.dart';

class ProgressTrackingService {
  static final ProgressTrackingService _instance =
      ProgressTrackingService._internal();
  factory ProgressTrackingService() => _instance;
  ProgressTrackingService._internal();

  // Backend API base URL
  static String get _baseUrl => ApiConfig.backendBaseUrl;

  // Get weekly cognitive performance score
  Future<WeeklyScore> getWeeklyScore(String patientId) async {
    try {
      final url = Uri.parse('$_baseUrl/progress/weekly-score/$patientId');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return WeeklyScore.fromJson(data);
      } else {
        throw Exception(
            'Failed to get weekly score: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting weekly score: $e');
    }
  }

  // Get weekly progress report
  Future<WeeklyProgressReport> getWeeklyReport(String patientId) async {
    try {
      final url = Uri.parse('$_baseUrl/progress/weekly-report/$patientId');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return WeeklyProgressReport.fromJson(data);
      } else {
        throw Exception(
            'Failed to get weekly report: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting weekly report: $e');
    }
  }

  // Check for cognitive decline
  Future<DeclineDetection> checkDecline(String patientId) async {
    try {
      final url = Uri.parse('$_baseUrl/progress/decline-detection/$patientId');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return DeclineDetection.fromJson(data);
      } else {
        throw Exception(
            'Failed to check decline: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error checking decline: $e');
    }
  }
}

