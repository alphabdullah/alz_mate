import 'package:cloud_firestore/cloud_firestore.dart';

class MoodEntryModel {
  final String id;
  final String userId;
  final String mood; // 'happy', 'sad', 'anxious', 'confused', 'content', 'neutral', etc.
  final double score; // 0.0 to 1.0 (low to high intensity)
  final DateTime timestamp;
  final String? notes;
  final List<String>? triggers; // What caused this mood
  final String? location;
  final Map<String, dynamic>? symptoms; // Associated symptoms
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? metadata;

  MoodEntryModel({
    required this.id,
    required this.userId,
    required this.mood,
    required this.score,
    required this.timestamp,
    this.notes,
    this.triggers,
    this.location,
    this.symptoms,
    required this.createdAt,
    required this.updatedAt,
    this.metadata,
  });

  factory MoodEntryModel.fromMap(Map<String, dynamic> map) {
    return MoodEntryModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      mood: map['mood'] ?? 'neutral',
      score: map['score']?.toDouble() ?? 0.5,
      timestamp: map['timestamp'] != null 
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      notes: map['notes'],
      triggers: map['triggers'] != null ? List<String>.from(map['triggers']) : null,
      location: map['location'],
      symptoms: map['symptoms'],
      createdAt: map['createdAt'] != null 
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null 
          ? (map['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
      metadata: map['metadata'],
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'mood': mood,
        'score': score,
        'timestamp': Timestamp.fromDate(timestamp),
        'notes': notes,
        'triggers': triggers,
        'location': location,
        'symptoms': symptoms,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
        'metadata': metadata,
      };

  MoodEntryModel copyWith({
    String? id,
    String? userId,
    String? mood,
    double? score,
    DateTime? timestamp,
    String? notes,
    List<String>? triggers,
    String? location,
    Map<String, dynamic>? symptoms,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return MoodEntryModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      mood: mood ?? this.mood,
      score: score ?? this.score,
      timestamp: timestamp ?? this.timestamp,
      notes: notes ?? this.notes,
      triggers: triggers ?? this.triggers,
      location: location ?? this.location,
      symptoms: symptoms ?? this.symptoms,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  bool get isPositive => _isPositiveMood(mood);
  bool get isNegative => _isNegativeMood(mood);
  bool get isNeutral => mood == 'neutral' || mood == 'content';
  bool get isHighIntensity => score > 0.7;
  bool get isMediumIntensity => score > 0.4 && score <= 0.7;
  bool get isLowIntensity => score <= 0.4;
  bool get isToday => _isSameDay(timestamp, DateTime.now());
  bool get isYesterday => _isSameDay(timestamp, DateTime.now().subtract(const Duration(days: 1)));
  bool get hasNotes => notes != null && notes!.isNotEmpty;
  bool get hasTriggers => triggers != null && triggers!.isNotEmpty;

  String get moodDisplayName {
    switch (mood) {
      case 'happy':
        return 'Happy';
      case 'sad':
        return 'Sad';
      case 'anxious':
        return 'Anxious';
      case 'confused':
        return 'Confused';
      case 'content':
        return 'Content';
      case 'neutral':
        return 'Neutral';
      case 'angry':
        return 'Angry';
      case 'excited':
        return 'Excited';
      case 'frustrated':
        return 'Frustrated';
      case 'peaceful':
        return 'Peaceful';
      default:
        return mood.substring(0, 1).toUpperCase() + mood.substring(1);
    }
  }

  String get moodEmoji {
    switch (mood) {
      case 'happy':
        return '😊';
      case 'sad':
        return '😢';
      case 'anxious':
        return '😰';
      case 'confused':
        return '😕';
      case 'content':
        return '😌';
      case 'neutral':
        return '😐';
      case 'angry':
        return '😠';
      case 'excited':
        return '🤩';
      case 'frustrated':
        return '😤';
      case 'peaceful':
        return '😇';
      default:
        return '😐';
    }
  }

  String get intensityText {
    if (isHighIntensity) return 'High';
    if (isMediumIntensity) return 'Medium';
    return 'Low';
  }

  int get moodColorValue {
    switch (mood) {
      case 'happy':
        return 0xFF66BB6A; // Green
      case 'content':
        return 0xFFFFB74D; // Orange
      case 'excited':
        return 0xFF42A5F5; // Blue
      case 'peaceful':
        return 0xFF81C784; // Light Green
      case 'neutral':
        return 0xFF9E9E9E; // Grey
      case 'confused':
        return 0xFFFF9800; // Orange
      case 'frustrated':
        return 0xFFFF7043; // Deep Orange
      case 'anxious':
        return 0xFFE91E63; // Pink
      case 'angry':
        return 0xFFEF5350; // Red
      case 'sad':
        return 0xFFEF5350; // Red
      default:
        return 0xFF9E9E9E; // Grey
    }
  }

  bool _isPositiveMood(String mood) {
    return ['happy', 'content', 'excited', 'peaceful'].contains(mood);
  }

  bool _isNegativeMood(String mood) {
    return ['sad', 'anxious', 'angry', 'frustrated', 'confused'].contains(mood);
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  @override
  String toString() {
    return 'MoodEntryModel(id: $id, mood: $mood, score: $score, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MoodEntryModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
