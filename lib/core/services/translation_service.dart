import 'dart:convert';
import 'package:http/http.dart' as http;

class TranslationService {
  static final TranslationService _instance = TranslationService._internal();
  factory TranslationService() => _instance;
  TranslationService._internal();

  // Google Translate API endpoint (free, no API key required)
  static const String _translateUrl = 'https://translate.googleapis.com/translate_a/single';

  /// Translate text to English
  /// Returns the translated text, or original text if translation fails
  Future<String> translateToEnglish(String text) async {
    try {
      if (text.trim().isEmpty) {
        print('🌍 TRANSLATE: Empty text, skipping translation');
        return text;
      }

      print('🌍 TRANSLATE: Translating text to English...');
      print('🌍 TRANSLATE: Original text: $text');

      // Check if text is already in English (simple heuristic)
      if (_isLikelyEnglish(text)) {
        print('🌍 TRANSLATE: Text appears to be English, skipping translation');
        return text;
      }

      final url = Uri.parse(_translateUrl).replace(queryParameters: {
        'client': 'gtx',
        'sl': 'auto', // Source language: auto-detect
        'tl': 'en', // Target language: English
        'dt': 't',
        'q': text,
      });

      print('🌍 TRANSLATE: Making request to Google Translate API...');
      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('⚠️ TRANSLATE: Request timeout');
          throw Exception('Translation timeout');
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Google Translate API returns nested arrays
        // Extract the translated text from the response
        String translatedText = text; // Default to original
        
        if (data is List && data.isNotEmpty && data[0] is List) {
          final translations = data[0] as List;
          if (translations.isNotEmpty && translations[0] is List) {
            final firstTranslation = translations[0] as List;
            if (firstTranslation.isNotEmpty) {
              translatedText = firstTranslation[0] as String;
            }
          }
        }

        print('✅ TRANSLATE: Translation successful');
        print('🌍 TRANSLATE: Translated text: $translatedText');
        
        return translatedText;
      } else {
        print('⚠️ TRANSLATE: API error - Status ${response.statusCode}');
        print('⚠️ TRANSLATE: Response body: ${response.body}');
        // Return original text on error
        return text;
      }
    } catch (e) {
      print('⚠️ TRANSLATE: Error translating text: $e');
      print('⚠️ TRANSLATE: Returning original text due to error');
      // Return original text if translation fails
      return text;
    }
  }

  /// Simple heuristic to check if text is likely English
  /// Checks for common English words and character patterns
  bool _isLikelyEnglish(String text) {
    // Common English words
    final englishWords = [
      'the', 'be', 'to', 'of', 'and', 'a', 'in', 'that', 'have', 'i',
      'it', 'for', 'not', 'on', 'with', 'he', 'as', 'you', 'do', 'at',
      'this', 'but', 'his', 'by', 'from', 'they', 'we', 'say', 'her', 'she',
      'or', 'an', 'will', 'my', 'one', 'all', 'would', 'there', 'their',
      'what', 'so', 'up', 'out', 'if', 'about', 'who', 'get', 'which', 'go',
      'me', 'when', 'make', 'can', 'like', 'time', 'no', 'just', 'him', 'know',
      'take', 'people', 'into', 'year', 'your', 'good', 'some', 'could', 'them',
      'see', 'other', 'than', 'then', 'now', 'look', 'only', 'come', 'its',
      'over', 'think', 'also', 'back', 'after', 'use', 'two', 'how', 'our',
      'work', 'first', 'well', 'way', 'even', 'new', 'want', 'because', 'any',
      'these', 'give', 'day', 'most', 'us', 'is', 'are', 'was', 'were', 'been',
      'being', 'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would',
      'should', 'could', 'may', 'might', 'must', 'can', 'cannot'
    ];

    final lowerText = text.toLowerCase();
    final words = lowerText.split(RegExp(r'\s+'));
    
    // Count English words
    int englishWordCount = 0;
    for (final word in words) {
      final cleanWord = word.replaceAll(RegExp(r'[^\w]'), '');
      if (englishWords.contains(cleanWord)) {
        englishWordCount++;
      }
    }

    // If more than 30% of words are common English words, consider it English
    final englishRatio = words.isNotEmpty ? englishWordCount / words.length : 0.0;
    
    print('🌍 TRANSLATE: English word ratio: $englishRatio');
    
    return englishRatio > 0.3;
  }
}
