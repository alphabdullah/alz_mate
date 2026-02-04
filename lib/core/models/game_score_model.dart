import 'package:cloud_firestore/cloud_firestore.dart';

class GameScoreModel {
  final String id;
  final String userId;
  final String gameId;
  final String gameName;
  final String gameType;
  final int score;
  final int maxScore;
  final DateTime playedAt;
  final Duration duration;
  final String difficulty;
  final int level;
  final Map<String, dynamic>? gameData;
  final List<String>? achievements;
  final double accuracy;
  final int attempts;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? metadata;

  GameScoreModel({
    required this.id,
    required this.userId,
    required this.gameId,
    required this.gameName,
    required this.gameType,
    required this.score,
    required this.maxScore,
    required this.playedAt,
    required this.duration,
    this.difficulty = 'medium',
    this.level = 1,
    this.gameData,
    this.achievements,
    this.accuracy = 0.0,
    this.attempts = 1,
    required this.createdAt,
    required this.updatedAt,
    this.metadata,
  });

  factory GameScoreModel.fromMap(Map<String, dynamic> map) {
    return GameScoreModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      gameId: map['gameId'] ?? '',
      gameName: map['gameName'] ?? '',
      gameType: map['gameType'] ?? 'memory',
      score: map['score']?.toInt() ?? 0,
      maxScore: map['maxScore']?.toInt() ?? 1000,
      playedAt: map['playedAt'] != null
          ? (map['playedAt'] as Timestamp).toDate()
          : DateTime.now(),
      duration: Duration(seconds: map['duration']?.toInt() ?? 0),
      difficulty: map['difficulty'] ?? 'medium',
      level: map['level']?.toInt() ?? 1,
      gameData: map['gameData'],
      achievements: map['achievements'] != null
          ? List<String>.from(map['achievements'])
          : null,
      accuracy: map['accuracy']?.toDouble() ?? 0.0,
      attempts: map['attempts']?.toInt() ?? 1,
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
    'gameId': gameId,
    'gameName': gameName,
    'gameType': gameType,
    'score': score,
    'maxScore': maxScore,
    'playedAt': Timestamp.fromDate(playedAt),
    'duration': duration.inSeconds,
    'difficulty': difficulty,
    'level': level,
    'gameData': gameData,
    'achievements': achievements,
    'accuracy': accuracy,
    'attempts': attempts,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
    'metadata': metadata,
  };

  GameScoreModel copyWith({
    String? id,
    String? userId,
    String? gameId,
    String? gameName,
    String? gameType,
    int? score,
    int? maxScore,
    DateTime? playedAt,
    Duration? duration,
    String? difficulty,
    int? level,
    Map<String, dynamic>? gameData,
    List<String>? achievements,
    double? accuracy,
    int? attempts,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return GameScoreModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      gameId: gameId ?? this.gameId,
      gameName: gameName ?? this.gameName,
      gameType: gameType ?? this.gameType,
      score: score ?? this.score,
      maxScore: maxScore ?? this.maxScore,
      playedAt: playedAt ?? this.playedAt,
      duration: duration ?? this.duration,
      difficulty: difficulty ?? this.difficulty,
      level: level ?? this.level,
      gameData: gameData ?? this.gameData,
      achievements: achievements ?? this.achievements,
      accuracy: accuracy ?? this.accuracy,
      attempts: attempts ?? this.attempts,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  // Utility Getters

  double get scorePercentage => maxScore > 0 ? (score / maxScore) * 100 : 0.0;

  bool get isPerfectScore => score == maxScore;
  bool get isHighScore => scorePercentage >= 80.0;
  bool get isMediumScore => scorePercentage >= 60.0 && scorePercentage < 80.0;
  bool get isLowScore => scorePercentage < 60.0;

  bool get isToday => _isSameDay(playedAt, DateTime.now());
  bool get isYesterday =>
      _isSameDay(playedAt, DateTime.now().subtract(const Duration(days: 1)));
  bool get hasAchievements => achievements != null && achievements!.isNotEmpty;

  String get difficultyDisplayName {
    switch (difficulty) {
      case 'easy':
        return 'Easy';
      case 'medium':
        return 'Medium';
      case 'hard':
        return 'Hard';
      case 'expert':
        return 'Expert';
      default:
        return difficulty.substring(0, 1).toUpperCase() +
            difficulty.substring(1);
    }
  }

  String get gameTypeDisplayName {
    switch (gameType) {
      case 'memory':
        return 'Memory';
      case 'logic':
        return 'Logic';
      case 'speed':
        return 'Speed';
      case 'creativity':
        return 'Creativity';
      case 'language':
        return 'Language';
      case 'pattern':
        return 'Pattern';
      default:
        return gameType.substring(0, 1).toUpperCase() + gameType.substring(1);
    }
  }

  String get performanceGrade {
    if (scorePercentage >= 90) return 'A+';
    if (scorePercentage >= 80) return 'A';
    if (scorePercentage >= 70) return 'B';
    if (scorePercentage >= 60) return 'C';
    if (scorePercentage >= 50) return 'D';
    return 'F';
  }

  String get durationText {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }

  int get gameTypeColorValue {
    switch (gameType) {
      case 'memory':
        return 0xFF6A5AE0;
      case 'logic':
        return 0xFFFFB74D;
      case 'speed':
        return 0xFF66BB6A;
      case 'creativity':
        return 0xFFE91E63;
      case 'language':
        return 0xFF00BCD4;
      case 'pattern':
        return 0xFF9C27B0;
      default:
        return 0xFF9E9E9E;
    }
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  @override
  String toString() {
    return 'GameScoreModel(id: $id, gameName: $gameName, score: $score, playedAt: $playedAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GameScoreModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
