import 'package:cloud_firestore/cloud_firestore.dart';

class CaregiverRequestModel {
  final String id;
  final String patientId;
  final String caregiverId;
  final String patientName;
  final String caregiverName;
  final String patientEmail;
  final String caregiverEmail;
  final String status; // 'pending', 'accepted', 'declined'
  final String? message;
  final DateTime createdAt;
  final DateTime? respondedAt;
  final String? responseMessage;

  CaregiverRequestModel({
    required this.id,
    required this.patientId,
    required this.caregiverId,
    required this.patientName,
    required this.caregiverName,
    required this.patientEmail,
    required this.caregiverEmail,
    required this.status,
    this.message,
    required this.createdAt,
    this.respondedAt,
    this.responseMessage,
  });

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isDeclined => status == 'declined';

  CaregiverRequestModel copyWith({
    String? id,
    String? patientId,
    String? caregiverId,
    String? patientName,
    String? caregiverName,
    String? patientEmail,
    String? caregiverEmail,
    String? status,
    String? message,
    DateTime? createdAt,
    DateTime? respondedAt,
    String? responseMessage,
  }) {
    return CaregiverRequestModel(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      caregiverId: caregiverId ?? this.caregiverId,
      patientName: patientName ?? this.patientName,
      caregiverName: caregiverName ?? this.caregiverName,
      patientEmail: patientEmail ?? this.patientEmail,
      caregiverEmail: caregiverEmail ?? this.caregiverEmail,
      status: status ?? this.status,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      respondedAt: respondedAt ?? this.respondedAt,
      responseMessage: responseMessage ?? this.responseMessage,
    );
  }

  factory CaregiverRequestModel.fromMap(Map<String, dynamic> map) {
    return CaregiverRequestModel(
      id: map['id'] ?? '',
      patientId: map['patientId'] ?? '',
      caregiverId: map['caregiverId'] ?? '',
      patientName: map['patientName'] ?? '',
      caregiverName: map['caregiverName'] ?? '',
      patientEmail: map['patientEmail'] ?? '',
      caregiverEmail: map['caregiverEmail'] ?? '',
      status: map['status'] ?? 'pending',
      message: map['message'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      respondedAt: map['respondedAt'] != null
          ? (map['respondedAt'] as Timestamp).toDate()
          : null,
      responseMessage: map['responseMessage'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'patientId': patientId,
      'caregiverId': caregiverId,
      'patientName': patientName,
      'caregiverName': caregiverName,
      'patientEmail': patientEmail,
      'caregiverEmail': caregiverEmail,
      'status': status,
      'message': message,
      'createdAt': Timestamp.fromDate(createdAt),
      'respondedAt': respondedAt != null
          ? Timestamp.fromDate(respondedAt!)
          : null,
      'responseMessage': responseMessage,
    };
  }

  @override
  String toString() {
    return 'CaregiverRequestModel(id: $id, patientName: $patientName, caregiverName: $caregiverName, status: $status)';
  }
}
