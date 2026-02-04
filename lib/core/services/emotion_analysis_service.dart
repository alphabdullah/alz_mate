// emotion_analysis_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/emotion_analysis_model.dart';
import '../../core/constants/api_config.dart';

class EmotionAnalysisService {
  static final EmotionAnalysisService _instance =
      EmotionAnalysisService._internal();
  factory EmotionAnalysisService() => _instance;
  EmotionAnalysisService._internal();

  // Backend API base URL
  static String get _baseUrl => ApiConfig.backendBaseUrl;

  // Analyze emotion from journal text
  Future<EmotionAnalysisResult> analyzeEmotion({
    required String patientId,
    required String journalText,
    String? timestamp,
    String? journalEntryId,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/analyze-emotion');
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'patient_id': patientId,
          'journal_text': journalText,
          'timestamp': timestamp,
          'journal_entry_id': journalEntryId,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return EmotionAnalysisResult.fromJson(data);
      } else {
        throw Exception(
            'Failed to analyze emotion: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error analyzing emotion: $e');
    }
  }

  // Analyze emotion with audio file upload
  Future<EmotionAnalysisResult> analyzeEmotionWithAudio({
    required String patientId,
    required String journalText,
    required String audioFilePath,
    String? timestamp,
    String? journalEntryId,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/analyze-emotion-with-audio');
      
      final request = http.MultipartRequest('POST', url);
      request.fields['patient_id'] = patientId;
      request.fields['journal_text'] = journalText;
      if (timestamp != null) request.fields['timestamp'] = timestamp;
      if (journalEntryId != null) {
        request.fields['journal_entry_id'] = journalEntryId;
      }
      
      request.files.add(
        await http.MultipartFile.fromPath('audio_file', audioFilePath),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return EmotionAnalysisResult.fromJson(data);
      } else {
        throw Exception(
            'Failed to analyze emotion with audio: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error analyzing emotion with audio: $e');
    }
  }

  // Get emotion entries for a patient
  Future<List<EmotionEntry>> getEmotionEntries({
    required String patientId,
    String? startDate,
    String? endDate,
    int? limit,
  }) async {
    try {
      final queryParams = <String, String>{
        if (startDate != null) 'start_date': startDate,
        if (endDate != null) 'end_date': endDate,
        if (limit != null) 'limit': limit.toString(),
      };

      final url = Uri.parse('$_baseUrl/emotion-entries/$patientId')
          .replace(queryParameters: queryParams);

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final entries = (data['entries'] as List)
            .map((e) => EmotionEntry.fromJson(e))
            .toList();
        return entries;
      } else {
        throw Exception(
            'Failed to get emotion entries: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting emotion entries: $e');
    }
  }

  // Get emotion trends
  Future<EmotionTrends> getEmotionTrends({
    required String patientId,
    int days = 7,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/emotion-trends/$patientId')
          .replace(queryParameters: {'days': days.toString()});

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return EmotionTrends.fromJson(data);
      } else {
        throw Exception('Failed to get emotion trends: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting emotion trends: $e');
    }
  }

  // Get daily emotion summary
  Future<DailyEmotionSummary> getDailySummary({
    required String patientId,
    String? date,
  }) async {
    try {
      final queryParams = <String, String>{
        if (date != null) 'date': date,
      };

      final url = Uri.parse('$_baseUrl/daily-summary/$patientId')
          .replace(queryParameters: queryParams);

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return DailyEmotionSummary.fromJson(data);
      } else {
        throw Exception(
            'Failed to get daily summary: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting daily summary: $e');
    }
  }

  // Get weekly emotion summary
  Future<WeeklyEmotionSummary> getWeeklySummary({
    required String patientId,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/weekly-summary/$patientId');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return WeeklyEmotionSummary.fromJson(data);
      } else {
        throw Exception(
            'Failed to get weekly summary: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting weekly summary: $e');
    }
  }

  // Detect emotion shift
  Future<EmotionShift> detectEmotionShift({
    required String patientId,
    required String emotion,
    int days = 7,
    double intensityIncrease = 20.0,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/emotion/shift-detection/$patientId')
          .replace(queryParameters: {
        'emotion': emotion,
        'days': days.toString(),
        'intensity_increase': intensityIncrease.toString(),
      });

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return EmotionShift.fromJson(data);
      } else {
        throw Exception(
            'Failed to detect emotion shift: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error detecting emotion shift: $e');
    }
  }

  // Check persistent negative emotions
  Future<PersistentNegativeEmotions> checkPersistentNegative({
    required String patientId,
    int days = 3,
  }) async {
    try {
      final url =
          Uri.parse('$_baseUrl/emotion/persistent-negative/$patientId')
              .replace(queryParameters: {'days': days.toString()});

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return PersistentNegativeEmotions.fromJson(data);
      } else {
        throw Exception(
            'Failed to check persistent negative emotions: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error checking persistent negative emotions: $e');
    }
  }

  // Detect emotion volatility
  Future<EmotionVolatility> detectVolatility({
    required String patientId,
    int days = 7,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/emotion/volatility/$patientId')
          .replace(queryParameters: {'days': days.toString()});

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return EmotionVolatility.fromJson(data);
      } else {
        throw Exception(
            'Failed to detect volatility: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error detecting volatility: $e');
    }
  }

  // Get emotion trend summary
  Future<EmotionTrendSummary> getTrendSummary({
    required String patientId,
    int days = 7,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/emotion/trend-summary/$patientId')
          .replace(queryParameters: {'days': days.toString()});

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return EmotionTrendSummary.fromJson(data);
      } else {
        throw Exception(
            'Failed to get trend summary: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting trend summary: $e');
    }
  }
}

