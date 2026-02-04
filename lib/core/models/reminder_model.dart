import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';

class ReminderModel {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final DateTime time;
  final String
  type; // 'medication', 'appointment', 'meal', 'exercise', 'call', 'custom'
  bool isCompleted;
  final bool isMissed;
  final bool repeatDaily;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>?
  metadata; // Additional data like medication dosage, doctor name, etc.
  final bool? missedNotified;


  ReminderModel({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    required this.time,
    required this.type,
    this.isCompleted = false,
    this.isMissed = false,
    this.repeatDaily = false,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.metadata,
    this.missedNotified, // ✅ NEW
  });

  factory ReminderModel.fromMap(String id,Map<String, dynamic> map) {
    log(map.toString());
    return ReminderModel(
      id: id ?? '',
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'],
      time: map['time'] != null
          ? (map['time'] as Timestamp).toDate()
          : DateTime.now(),
      type: map['type'] ?? 'custom',
      isCompleted: map['isCompleted'] ?? false,
      isMissed: map['isMissed'] ?? false,
      repeatDaily: map['repeatDaily'] ?? false,
      notes: map['notes'],
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
      metadata: map['metadata'],
      missedNotified: map['missedNotified'],

    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'userId': userId,
    'title': title,
    'description': description,
    'time': Timestamp.fromDate(time),
    'type': type,
    'isCompleted': isCompleted,
    'isMissed': isMissed,
    'repeatDaily': repeatDaily,
    'notes': notes,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
    'metadata': metadata,
    if (missedNotified != null) 'missedNotified': missedNotified,

  };

  ReminderModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    DateTime? time,
    String? type,
    bool? isCompleted,
    bool? isMissed,
    bool? repeatDaily,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
    bool? missedNotified,

  }) {
    return ReminderModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      time: time ?? this.time,
      type: type ?? this.type,
      isCompleted: isCompleted ?? this.isCompleted,
      isMissed: isMissed ?? this.isMissed,
      repeatDaily: repeatDaily ?? this.repeatDaily,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
      missedNotified: missedNotified ?? this.missedNotified,

    );
  }

  bool get isPending =>
      !isCompleted && !isMissed && time.isAfter(DateTime.now());
  bool get isOverdue =>
      !isCompleted && !isMissed && time.isBefore(DateTime.now());
  bool get isToday => _isSameDay(time, DateTime.now());
  bool get isTomorrow =>
      _isSameDay(time, DateTime.now().add(const Duration(days: 1)));

  String get statusText {
    if (isCompleted) return 'Completed';
    if (isMissed) return 'Missed';
    if (isOverdue) return 'Overdue';
    return 'Pending';
  }

  String get typeDisplayName {
    switch (type) {
      case 'medication':
        return 'Medication';
      case 'appointment':
        return 'Appointment';
      case 'meal':
        return 'Meal';
      case 'exercise':
        return 'Exercise';
      case 'call':
        return 'Call';
      default:
        return 'Reminder';
    }
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  @override
  String toString() {
    return 'ReminderModel(id: $id, title: $title, time: $time, type: $type)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReminderModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
