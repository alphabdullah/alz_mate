import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';

class SOSAlertModel {
  final String id;
  final String userId;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final String? address;
  final String? notes;
  final bool isResolved;
  final DateTime? resolvedAt;
  final String? resolvedBy;
  final List<String>? notifiedContacts;
  final String? responseTime; // Time taken for response
  final String priority; // 'low', 'medium', 'high', 'critical'
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  SOSAlertModel({
    required this.id,
    required this.userId,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    this.address,
    this.notes,
    this.isResolved = false,
    this.resolvedAt,
    this.resolvedBy,
    this.notifiedContacts,
    this.responseTime,
    this.priority = 'high',
    required this.createdAt,
    this.metadata,
  });

  factory SOSAlertModel.fromMap(String id, Map<String, dynamic> map) {
    log(id);
    return SOSAlertModel(
      id: id,
      userId: map['userId'] ?? '',
      timestamp: map['timestamp'] != null
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      latitude: map['latitude']?.toDouble() ?? 0.0,
      longitude: map['longitude']?.toDouble() ?? 0.0,
      address: map['address'],
      notes: map['notes'],
      isResolved: map['isResolved'] ?? false,
      resolvedAt: map['resolvedAt'] != null
          ? (map['resolvedAt'] as Timestamp).toDate()
          : null,
      resolvedBy: map['resolvedBy'],
      notifiedContacts: map['notifiedContacts'] != null
          ? List<String>.from(map['notifiedContacts'])
          : null,
      responseTime: map['responseTime'],
      priority: map['priority'] ?? 'high',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      metadata: map['metadata'],
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'userId': userId,
    'timestamp': Timestamp.fromDate(timestamp),
    'latitude': latitude,
    'longitude': longitude,
    'address': address,
    'notes': notes,
    'isResolved': isResolved,
    'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
    'resolvedBy': resolvedBy,
    'notifiedContacts': notifiedContacts,
    'responseTime': responseTime,
    'priority': priority,
    'createdAt': Timestamp.fromDate(createdAt),
    'metadata': metadata,
  };

  SOSAlertModel copyWith({
    String? id,
    String? userId,
    DateTime? timestamp,
    double? latitude,
    double? longitude,
    String? address,
    String? notes,
    bool? isResolved,
    DateTime? resolvedAt,
    String? resolvedBy,
    List<String>? notifiedContacts,
    String? responseTime,
    String? priority,
    DateTime? createdAt,
    Map<String, dynamic>? metadata,
  }) {
    return SOSAlertModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      timestamp: timestamp ?? this.timestamp,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      isResolved: isResolved ?? this.isResolved,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      resolvedBy: resolvedBy ?? this.resolvedBy,
      notifiedContacts: notifiedContacts ?? this.notifiedContacts,
      responseTime: responseTime ?? this.responseTime,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      metadata: metadata ?? this.metadata,
    );
  }

  bool get isPending => !isResolved;
  bool get isActive => !isResolved && _isRecent();
  bool get isCritical => priority == 'critical';
  bool get isHigh => priority == 'high';
  bool get isMedium => priority == 'medium';
  bool get isLow => priority == 'low';

  String get statusText {
    if (isResolved) return 'Resolved';
    if (isActive) return 'Active';
    return 'Pending';
  }

  String get priorityDisplayName {
    switch (priority) {
      case 'critical':
        return 'Critical';
      case 'high':
        return 'High';
      case 'medium':
        return 'Medium';
      case 'low':
        return 'Low';
      default:
        return 'Unknown';
    }
  }

  String get locationString {
    if (address != null && address!.isNotEmpty) {
      return address!;
    }
    return '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
  }

  Duration get timeSinceAlert {
    return DateTime.now().difference(timestamp);
  }

  String get timeAgoText {
    final duration = timeSinceAlert;
    if (duration.inMinutes < 1) {
      return 'Just now';
    } else if (duration.inHours < 1) {
      return '${duration.inMinutes}m ago';
    } else if (duration.inDays < 1) {
      return '${duration.inHours}h ago';
    } else {
      return '${duration.inDays}d ago';
    }
  }

  bool _isRecent() {
    return DateTime.now().difference(timestamp).inHours < 24;
  }

  @override
  String toString() {
    return 'SOSAlertModel(id: $id, timestamp: $timestamp, location: $locationString)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SOSAlertModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
