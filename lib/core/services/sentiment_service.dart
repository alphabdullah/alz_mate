import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_config.dart';
import 'translation_service.dart';

class SentimentService {
  static final SentimentService _instance = SentimentService._internal();
  factory SentimentService() => _instance;
  SentimentService._internal();

  // Positive words for sentiment analysis
  final List<String> _positiveWords = [
    'happy',
    'joy',
    'love',
    'excellent',
    'amazing',
    'wonderful',
    'great',
    'good',
    'fantastic',
    'awesome',
    'brilliant',
    'perfect',
    'beautiful',
    'excited',
    'thrilled',
    'delighted',
    'pleased',
    'satisfied',
    'grateful',
    'thankful',
    'blessed',
    'lucky',
    'proud',
    'confident',
    'optimistic',
    'hopeful',
    'peaceful',
    'calm',
    'relaxed',
    'comfortable',
    'content',
    'cheerful',
    'bright',
    'sunny',
    'positive',
    'upbeat',
    'energetic',
    'vibrant',
    'lively',
    'enthusiastic',
    'passionate',
    'motivated',
    'inspired',
    'creative',
    'successful',
    'accomplished',
    'achieved',
    'victory',
    'win',
    'triumph',
    'celebrate',
    'party',
    'fun',
    'enjoy',
    'laugh',
    'smile',
    'giggle',
    'chuckle',
    'humor',
    'funny',
    'amusing',
  ];

  // Negative words for sentiment analysis
  final List<String> _negativeWords = [
    'sad',
    'angry',
    'hate',
    'terrible',
    'awful',
    'horrible',
    'bad',
    'worst',
    'disgusting',
    'annoying',
    'frustrated',
    'disappointed',
    'upset',
    'worried',
    'anxious',
    'stressed',
    'depressed',
    'lonely',
    'isolated',
    'rejected',
    'abandoned',
    'betrayed',
    'hurt',
    'pain',
    'suffering',
    'miserable',
    'devastated',
    'heartbroken',
    'crushed',
    'defeated',
    'failure',
    'lost',
    'confused',
    'overwhelmed',
    'exhausted',
    'tired',
    'weak',
    'sick',
    'ill',
    'uncomfortable',
    'restless',
    'disturbed',
    'troubled',
    'concerned',
    'fearful',
    'scared',
    'afraid',
    'terrified',
    'panicked',
    'nervous',
    'tense',
    'agitated',
    'irritated',
    'annoyed',
    'bothered',
    'disturbed',
    'offended',
    'insulted',
    'humiliated',
  ];

  // Map emotion from API to sentiment label and score
  Map<String, dynamic> _mapEmotionToSentiment(String emotion) {
    final emotionUpper = emotion.toUpperCase();
    
    // Positive emotions
    final positiveEmotions = [
      'HAPPY', 'JOY', 'JOYFUL', 'EXCITED', 'EXCITEMENT', 'THRILLED',
      'DELIGHTED', 'PLEASED', 'CONTENT', 'CONTENTED', 'PEACEFUL',
      'CALM', 'RELAXED', 'COMFORTABLE', 'CHEERFUL', 'OPTIMISTIC',
      'HOPEFUL', 'GRATEFUL', 'THANKFUL', 'BLESSED', 'PROUD',
      'CONFIDENT', 'LOVE', 'LOVING', 'AFFECTIONATE'
    ];
    
    // Negative emotions
    final negativeEmotions = [
      'SAD', 'SADNESS', 'ANGRY', 'ANGER', 'FEAR', 'FEARFUL',
      'ANXIETY', 'ANXIOUS', 'DISGUST', 'DISGUSTED', 'WORRIED',
      'STRESSED', 'DEPRESSED', 'LONELY', 'FRUSTRATED', 'DISAPPOINTED',
      'UPSET', 'TERRIFIED', 'SCARED', 'AFRAID', 'NERVOUS',
      'TENSE', 'AGITATED', 'IRRITATED', 'ANNOYED', 'HURT',
      'PAIN', 'SUFFERING', 'MISERABLE', 'HEARTBROKEN', 'CRUSHED',
      'DEFEATED', 'FAILURE', 'LOST', 'CONFUSED', 'OVERWHELMED',
      'EXHAUSTED', 'TIRED', 'SICK', 'ILL'
    ];
    
    String label;
    double score;
    
    if (positiveEmotions.contains(emotionUpper)) {
      label = 'positive';
      // Map positive emotions to scores between 0.3 and 1.0
      // Strong positive emotions get higher scores
      if (['HAPPY', 'JOY', 'JOYFUL', 'EXCITED', 'THRILLED', 'DELIGHTED'].contains(emotionUpper)) {
        score = 0.8;
      } else if (['LOVE', 'LOVING', 'GRATEFUL', 'THANKFUL', 'BLESSED'].contains(emotionUpper)) {
        score = 0.9;
      } else {
        score = 0.5;
      }
    } else if (negativeEmotions.contains(emotionUpper)) {
      label = 'negative';
      // Map negative emotions to scores between -1.0 and -0.3
      // Strong negative emotions get lower scores
      if (['SAD', 'SADNESS', 'DEPRESSED', 'MISERABLE', 'HEARTBROKEN'].contains(emotionUpper)) {
        score = -0.8;
      } else if (['ANGRY', 'ANGER', 'TERRIFIED', 'FEAR', 'FEARFUL'].contains(emotionUpper)) {
        score = -0.9;
      } else {
        score = -0.5;
      }
    } else {
      label = 'neutral';
      score = 0.0;
    }
    
    return {
      'label': label,
      'score': score,
      'emotion': emotionUpper,
    };
  }

  // Analyze sentiment using Flask API
  Future<Map<String, dynamic>> analyzeSentimentFromAPI(String text) async {
    try {
      print('🌐 SENTIMENT: === Sentiment API Analysis Started ===');
      print('🌐 SENTIMENT: Original text: $text');
      
      if (text.trim().isEmpty) {
        print('⚠️ SENTIMENT: Empty text provided, returning neutral sentiment');
        return {'score': 0.0, 'label': 'neutral', 'confidence': 0.0};
      }

      // Translate text to English before sending to API
      print('🌐 SENTIMENT: Translating text to English...');
      final translationService = TranslationService();
      final englishText = await translationService.translateToEnglish(text);
      print('🌐 SENTIMENT: English text: $englishText');

      final url = Uri.parse('${ApiConfig.sentimentApiUrl}/predict');
      print('🌐 SENTIMENT: API URL: $url');
      
      final requestBody = json.encode({'text': englishText});
      print('🌐 SENTIMENT: Request body: $requestBody');
      
      print('🌐 SENTIMENT: Sending POST request to sentiment API...');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: requestBody,
      ).timeout(ApiConfig.apiTimeout);

      print('🌐 SENTIMENT: Response status code: ${response.statusCode}');
      print('🌐 SENTIMENT: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('🌐 SENTIMENT: Parsed response data: $data');
        
        final emotion = data['emotion'] as String?;
        
        if (emotion == null || emotion.isEmpty) {
          print('❌ SENTIMENT: ERROR - Invalid API response - emotion field missing');
          throw Exception('Invalid API response: emotion field missing');
        }
        
        print('🎭 SENTIMENT: Detected emotion: $emotion');
        final sentimentMapping = _mapEmotionToSentiment(emotion);
        print('💭 SENTIMENT: Mapped sentiment: $sentimentMapping');
        
        final result = {
          'score': sentimentMapping['score'] as double,
          'label': sentimentMapping['label'] as String,
          'emotion': sentimentMapping['emotion'] as String,
          'confidence': 0.9, // High confidence for ML model predictions
          'source': 'api',
        };
        
        print('✅ SENTIMENT: === Sentiment API Analysis Completed Successfully ===');
        print('✅ SENTIMENT: Final result: $result');
        return result;
      } else {
        print('❌ SENTIMENT: ERROR - API request failed with status ${response.statusCode}');
        print('❌ SENTIMENT: Response body: ${response.body}');
        throw Exception(
          'API request failed with status ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e, stackTrace) {
      print('❌ SENTIMENT: ERROR - Exception in analyzeSentimentFromAPI: $e');
      print('❌ SENTIMENT: Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Analyze sentiment of text
  Future<Map<String, dynamic>> analyzeSentiment(String text) async {
    print('💭 SENTIMENT: === Sentiment Analysis Started ===');
    print('💭 SENTIMENT: Input text: $text');
    print('💭 SENTIMENT: API enabled: ${ApiConfig.enableSentimentApi}');
    
    // Try API first if enabled
    if (ApiConfig.enableSentimentApi) {
      try {
        print('💭 SENTIMENT: Attempting API-based sentiment analysis...');
        final result = await analyzeSentimentFromAPI(text);
        print('✅ SENTIMENT: API analysis successful, returning result');
        return result;
      } catch (e, stackTrace) {
        print('⚠️ SENTIMENT: WARNING - Sentiment API failed, falling back to local analysis');
        print('⚠️ SENTIMENT: Error: $e');
        print('⚠️ SENTIMENT: Stack trace: $stackTrace');
        // Fall through to local analysis
      }
    }
    
    // Fallback to local keyword-based analysis
    print('💭 SENTIMENT: Using local keyword-based sentiment analysis...');
    try {
      if (text.trim().isEmpty) {
        return {'score': 0.0, 'label': 'neutral', 'confidence': 0.0};
      }

      // Convert to lowercase and split into words
      final words = text
          .toLowerCase()
          .replaceAll(RegExp(r'[^\w\s]'), ' ')
          .split(RegExp(r'\s+'))
          .where((word) => word.isNotEmpty)
          .toList();

      if (words.isEmpty) {
        return {'score': 0.0, 'label': 'neutral', 'confidence': 0.0};
      }

      int positiveCount = 0;
      int negativeCount = 0;

      // Count positive and negative words
      for (final word in words) {
        if (_positiveWords.contains(word)) {
          positiveCount++;
        } else if (_negativeWords.contains(word)) {
          negativeCount++;
        }
      }

      // Calculate sentiment score (-1.0 to 1.0)
      final totalSentimentWords = positiveCount + negativeCount;
      double score = 0.0;
      String label = 'neutral';
      double confidence = 0.0;

      if (totalSentimentWords > 0) {
        score =
            (positiveCount - negativeCount) / totalSentimentWords.toDouble();
        confidence = totalSentimentWords / words.length.toDouble();

        // Normalize confidence to 0.0-1.0 range
        confidence = min(confidence * 2, 1.0);

        // Determine label based on score
        if (score > 0.1) {
          label = 'positive';
        } else if (score < -0.1) {
          label = 'negative';
        } else {
          label = 'neutral';
        }
      }

      final result = {
        'score': score,
        'label': label,
        'confidence': confidence,
        'positiveWords': positiveCount,
        'negativeWords': negativeCount,
        'totalWords': words.length,
        'source': 'local',
      };
      
      print('✅ SENTIMENT: Local analysis completed');
      print('💭 SENTIMENT: Result: $result');
      print('✅ SENTIMENT: === Sentiment Analysis Completed ===');
      
      return result;
    } catch (e, stackTrace) {
      print('❌ SENTIMENT: ERROR - Failed to analyze sentiment: $e');
      print('❌ SENTIMENT: Stack trace: $stackTrace');
      throw Exception('Failed to analyze sentiment: $e');
    }
  }

  // Analyze sentiment with more detailed emotions
  Future<Map<String, dynamic>> analyzeDetailedSentiment(String text) async {
    try {
      final basicSentiment = await analyzeSentiment(text);

      // Emotion categories
      final emotions = {
        'joy': ['happy', 'joy', 'excited', 'thrilled', 'delighted', 'cheerful'],
        'love': ['love', 'adore', 'cherish', 'affection', 'romantic', 'caring'],
        'anger': ['angry', 'furious', 'rage', 'mad', 'irritated', 'annoyed'],
        'sadness': [
          'sad',
          'depressed',
          'miserable',
          'heartbroken',
          'grief',
          'sorrow',
        ],
        'fear': [
          'afraid',
          'scared',
          'terrified',
          'anxious',
          'worried',
          'nervous',
        ],
        'surprise': ['surprised', 'amazed', 'astonished', 'shocked', 'stunned'],
        'disgust': [
          'disgusting',
          'revolting',
          'repulsive',
          'nauseating',
          'gross',
        ],
      };

      final words = text
          .toLowerCase()
          .replaceAll(RegExp(r'[^\w\s]'), ' ')
          .split(RegExp(r'\s+'))
          .where((word) => word.isNotEmpty)
          .toList();

      final emotionScores = <String, int>{};

      for (final word in words) {
        for (final emotion in emotions.keys) {
          if (emotions[emotion]!.contains(word)) {
            emotionScores[emotion] = (emotionScores[emotion] ?? 0) + 1;
          }
        }
      }

      // Find dominant emotion
      String? dominantEmotion;
      int maxEmotionScore = 0;

      emotionScores.forEach((emotion, score) {
        if (score > maxEmotionScore) {
          maxEmotionScore = score;
          dominantEmotion = emotion;
        }
      });

      return {
        ...basicSentiment,
        'emotions': emotionScores,
        'dominantEmotion': dominantEmotion,
        'emotionIntensity': maxEmotionScore / words.length.toDouble(),
      };
    } catch (e) {
      throw Exception('Failed to analyze detailed sentiment: $e');
    }
  }

  // Get sentiment trend over time
  Future<List<Map<String, dynamic>>> getSentimentTrend(
    List<String> texts,
    List<DateTime> timestamps,
  ) async {
    try {
      if (texts.length != timestamps.length) {
        throw Exception('Texts and timestamps must have the same length');
      }

      final trendData = <Map<String, dynamic>>[];

      for (int i = 0; i < texts.length; i++) {
        final sentiment = await analyzeSentiment(texts[i]);
        trendData.add({
          'timestamp': timestamps[i],
          'sentiment': sentiment,
          'text': texts[i],
        });
      }

      // Sort by timestamp
      trendData.sort(
        (a, b) =>
            (a['timestamp'] as DateTime).compareTo(b['timestamp'] as DateTime),
      );

      return trendData;
    } catch (e) {
      throw Exception('Failed to get sentiment trend: $e');
    }
  }

  // Calculate sentiment statistics
  Map<String, dynamic> calculateSentimentStats(
    List<Map<String, dynamic>> sentiments,
  ) {
    if (sentiments.isEmpty) {
      return {
        'averageScore': 0.0,
        'positiveCount': 0,
        'negativeCount': 0,
        'neutralCount': 0,
        'totalCount': 0,
        'positivePercentage': 0.0,
        'negativePercentage': 0.0,
        'neutralPercentage': 0.0,
      };
    }

    double totalScore = 0.0;
    int positiveCount = 0;
    int negativeCount = 0;
    int neutralCount = 0;

    for (final sentiment in sentiments) {
      final score = sentiment['score'] as double;
      final label = sentiment['label'] as String;

      totalScore += score;

      switch (label) {
        case 'positive':
          positiveCount++;
          break;
        case 'negative':
          negativeCount++;
          break;
        case 'neutral':
          neutralCount++;
          break;
      }
    }

    final totalCount = sentiments.length;
    final averageScore = totalScore / totalCount;

    return {
      'averageScore': averageScore,
      'positiveCount': positiveCount,
      'negativeCount': negativeCount,
      'neutralCount': neutralCount,
      'totalCount': totalCount,
      'positivePercentage': (positiveCount / totalCount) * 100,
      'negativePercentage': (negativeCount / totalCount) * 100,
      'neutralPercentage': (neutralCount / totalCount) * 100,
    };
  }

  // Suggest mood improvement activities based on sentiment
  List<String> suggestMoodImprovementActivities(String sentimentLabel) {
    switch (sentimentLabel) {
      case 'negative':
        return [
          'Take a few deep breaths and practice mindfulness',
          'Go for a short walk outside',
          'Listen to your favorite music',
          'Call a friend or family member',
          'Write down three things you\'re grateful for',
          'Do some light stretching or yoga',
          'Watch a funny video or read something uplifting',
          'Take a warm bath or shower',
          'Practice progressive muscle relaxation',
          'Engage in a hobby you enjoy',
        ];
      case 'neutral':
        return [
          'Try a new activity or hobby',
          'Reach out to connect with someone',
          'Set a small, achievable goal for today',
          'Take a nature walk',
          'Practice gratitude journaling',
          'Do something creative',
          'Learn something new',
          'Help someone else',
          'Exercise or move your body',
          'Meditate for a few minutes',
        ];
      case 'positive':
        return [
          'Share your positive mood with others',
          'Celebrate your good feelings',
          'Use this energy to tackle a challenging task',
          'Express gratitude to someone important to you',
          'Document this positive moment in your journal',
          'Plan something fun for the future',
          'Help someone who might be struggling',
          'Engage in activities that bring you joy',
          'Practice mindfulness to savor the moment',
          'Set positive intentions for the day',
        ];
      default:
        return [
          'Take time to check in with yourself',
          'Practice self-care activities',
          'Connect with supportive people',
          'Engage in activities you enjoy',
        ];
    }
  }

  // Get sentiment color for UI representation
  String getSentimentColor(String sentimentLabel) {
    switch (sentimentLabel) {
      case 'positive':
        return '#4CAF50'; // Green
      case 'negative':
        return '#F44336'; // Red
      case 'neutral':
        return '#FF9800'; // Orange
      default:
        return '#9E9E9E'; // Grey
    }
  }

  // Get sentiment emoji
  String getSentimentEmoji(String sentimentLabel) {
    switch (sentimentLabel) {
      case 'positive':
        return '😊';
      case 'negative':
        return '😔';
      case 'neutral':
        return '😐';
      default:
        return '🤔';
    }
  }
}
