import 'package:cloud_firestore/cloud_firestore.dart';

class JournalEntryModel {
  final String id;
  final String userId;
  final String content;
  final DateTime timestamp;
  final String type; // 'text', 'voice', 'image', 'video'
  final String? mediaUrl;
  final double? sentimentScore; // -1.0 to 1.0 (negative to positive)
  final String? sentimentLabel; // 'positive', 'negative', 'neutral'
  final List<String>? tags;
  final String? location;
  final bool isPrivate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? metadata;

  JournalEntryModel({
    required this.id,
    required this.userId,
    required this.content,
    required this.timestamp,
    required this.type,
    this.mediaUrl,
    this.sentimentScore,
    this.sentimentLabel,
    this.tags,
    this.location,
    this.isPrivate = false,
    required this.createdAt,
    required this.updatedAt,
    this.metadata,
  });

  factory JournalEntryModel.fromMap(Map<String, dynamic> map) {
    return JournalEntryModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      content: map['content'] ?? '',
      timestamp: map['timestamp'] != null 
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      type: map['type'] ?? 'text',
      mediaUrl: map['mediaUrl'],
      sentimentScore: map['sentimentScore']?.toDouble(),
      sentimentLabel: map['sentimentLabel'],
      tags: map['tags'] != null ? List<String>.from(map['tags']) : null,
      location: map['location'],
      isPrivate: map['isPrivate'] ?? false,
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
        'content': content,
        'timestamp': Timestamp.fromDate(timestamp),
        'type': type,
        'mediaUrl': mediaUrl,
        'sentimentScore': sentimentScore,
        'sentimentLabel': sentimentLabel,
        'tags': tags,
        'location': location,
        'isPrivate': isPrivate,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
        'metadata': metadata,
      };

  JournalEntryModel copyWith({
    String? id,
    String? userId,
    String? content,
    DateTime? timestamp,
    String? type,
    String? mediaUrl,
    double? sentimentScore,
    String? sentimentLabel,
    List<String>? tags,
    String? location,
    bool? isPrivate,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return JournalEntryModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      sentimentScore: sentimentScore ?? this.sentimentScore,
      sentimentLabel: sentimentLabel ?? this.sentimentLabel,
      tags: tags ?? this.tags,
      location: location ?? this.location,
      isPrivate: isPrivate ?? this.isPrivate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  bool get hasMedia => mediaUrl != null && mediaUrl!.isNotEmpty;
  bool get isTextEntry => type == 'text';
  bool get isVoiceEntry => type == 'voice';
  bool get isImageEntry => type == 'image';
  bool get isVideoEntry => type == 'video';
  bool get hasPositiveSentiment => sentimentScore != null && sentimentScore! > 0.1;
  bool get hasNegativeSentiment => sentimentScore != null && sentimentScore! < -0.1;
  bool get isToday => _isSameDay(timestamp, DateTime.now());
  bool get isYesterday => _isSameDay(timestamp, DateTime.now().subtract(const Duration(days: 1)));

  String get typeDisplayName {
    switch (type) {
      case 'voice':
        return 'Voice Entry';
      case 'image':
        return 'Photo Entry';
      case 'video':
        return 'Video Entry';
      default:
        return 'Text Entry';
    }
  }

  String get sentimentDisplayName {
    if (sentimentLabel != null) {
      switch (sentimentLabel!) {
        case 'positive':
          return 'Positive';
        case 'negative':
          return 'Negative';
        default:
          return 'Neutral';
      }
    }
    return 'Unknown';
  }

  String get shortContent {
    if (content.length <= 100) return content;
    return '${content.substring(0, 100)}...';
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  @override
  String toString() {
    return 'JournalEntryModel(id: $id, type: $type, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is JournalEntryModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
