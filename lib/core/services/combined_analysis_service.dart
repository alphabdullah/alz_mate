// combined_analysis_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/progress_tracking_model.dart';
import '../../core/constants/api_config.dart';

class CombinedAnalysisService {
  static final CombinedAnalysisService _instance =
      CombinedAnalysisService._internal();
  factory CombinedAnalysisService() => _instance;
  CombinedAnalysisService._internal();

  // Backend API base URL
  static String get _baseUrl => ApiConfig.backendBaseUrl;

  // Get combined weekly report
  Future<CombinedWeeklyReport> getCombinedWeeklyReport(String patientId) async {
    try {
      final url = Uri.parse('$_baseUrl/combined/weekly-report/$patientId');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return CombinedWeeklyReport.fromJson(data);
      } else {
        throw Exception(
            'Failed to get combined report: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting combined report: $e');
    }
  }
}

