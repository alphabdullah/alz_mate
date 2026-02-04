import 'package:cloud_firestore/cloud_firestore.dart';

class CaregiverApplicationModel {
  final String id;
  final String userId;
  final String fullName;
  final DateTime dateOfBirth;
  final String email;
  final String fullAddress;
  final String province;
  final String city;
  final String phoneNumber;
  
  // Document URLs
  final String? matriculationCertificateUrl;
  final String? intermediateCertificateUrl;
  final String? graduationDegreeUrl;
  final String? workExperienceDocumentsUrl;
  final String? caregivingCertificatesUrl;
  
  // Exam results
  final int? examScore;
  final int? examTotalQuestions;
  final double? examPercentage;
  final DateTime? examCompletedAt;
  final List<Map<String, dynamic>>? examAnswers;
  
  // Status
  final String status; // 'pending', 'approved', 'rejected'
  final String? rejectionReason;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  
  final DateTime createdAt;
  final DateTime? updatedAt;

  CaregiverApplicationModel({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.dateOfBirth,
    required this.email,
    required this.fullAddress,
    required this.province,
    required this.city,
    required this.phoneNumber,
    this.matriculationCertificateUrl,
    this.intermediateCertificateUrl,
    this.graduationDegreeUrl,
    this.workExperienceDocumentsUrl,
    this.caregivingCertificatesUrl,
    this.examScore,
    this.examTotalQuestions,
    this.examPercentage,
    this.examCompletedAt,
    this.examAnswers,
    this.status = 'pending',
    this.rejectionReason,
    this.reviewedAt,
    this.reviewedBy,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get hasCompletedExam => examCompletedAt != null;

  CaregiverApplicationModel copyWith({
    String? id,
    String? userId,
    String? fullName,
    DateTime? dateOfBirth,
    String? email,
    String? fullAddress,
    String? province,
    String? city,
    String? phoneNumber,
    String? matriculationCertificateUrl,
    String? intermediateCertificateUrl,
    String? graduationDegreeUrl,
    String? workExperienceDocumentsUrl,
    String? caregivingCertificatesUrl,
    int? examScore,
    int? examTotalQuestions,
    double? examPercentage,
    DateTime? examCompletedAt,
    List<Map<String, dynamic>>? examAnswers,
    String? status,
    String? rejectionReason,
    DateTime? reviewedAt,
    String? reviewedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CaregiverApplicationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      email: email ?? this.email,
      fullAddress: fullAddress ?? this.fullAddress,
      province: province ?? this.province,
      city: city ?? this.city,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      matriculationCertificateUrl: matriculationCertificateUrl ?? this.matriculationCertificateUrl,
      intermediateCertificateUrl: intermediateCertificateUrl ?? this.intermediateCertificateUrl,
      graduationDegreeUrl: graduationDegreeUrl ?? this.graduationDegreeUrl,
      workExperienceDocumentsUrl: workExperienceDocumentsUrl ?? this.workExperienceDocumentsUrl,
      caregivingCertificatesUrl: caregivingCertificatesUrl ?? this.caregivingCertificatesUrl,
      examScore: examScore ?? this.examScore,
      examTotalQuestions: examTotalQuestions ?? this.examTotalQuestions,
      examPercentage: examPercentage ?? this.examPercentage,
      examCompletedAt: examCompletedAt ?? this.examCompletedAt,
      examAnswers: examAnswers ?? this.examAnswers,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static DateTime? _toDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  factory CaregiverApplicationModel.fromJson(Map<String, dynamic> json) {
    return CaregiverApplicationModel(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      fullName: json['fullName'] ?? '',
      dateOfBirth: _toDate(json['dateOfBirth']) ?? DateTime.now(),
      email: json['email'] ?? '',
      fullAddress: json['fullAddress'] ?? '',
      province: json['province'] ?? '',
      city: json['city'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      matriculationCertificateUrl: json['matriculationCertificateUrl'],
      intermediateCertificateUrl: json['intermediateCertificateUrl'],
      graduationDegreeUrl: json['graduationDegreeUrl'],
      workExperienceDocumentsUrl: json['workExperienceDocumentsUrl'],
      caregivingCertificatesUrl: json['caregivingCertificatesUrl'],
      examScore: json['examScore'],
      examTotalQuestions: json['examTotalQuestions'],
      examPercentage: json['examPercentage']?.toDouble(),
      examCompletedAt: _toDate(json['examCompletedAt']),
      examAnswers: json['examAnswers'] != null
          ? List<Map<String, dynamic>>.from(json['examAnswers'])
          : null,
      status: json['status'] ?? 'pending',
      rejectionReason: json['rejectionReason'],
      reviewedAt: _toDate(json['reviewedAt']),
      reviewedBy: json['reviewedBy'],
      createdAt: _toDate(json['createdAt']) ?? DateTime.now(),
      updatedAt: _toDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'fullName': fullName,
      'dateOfBirth': dateOfBirth.toIso8601String(),
      'email': email,
      'fullAddress': fullAddress,
      'province': province,
      'city': city,
      'phoneNumber': phoneNumber,
      'matriculationCertificateUrl': matriculationCertificateUrl,
      'intermediateCertificateUrl': intermediateCertificateUrl,
      'graduationDegreeUrl': graduationDegreeUrl,
      'workExperienceDocumentsUrl': workExperienceDocumentsUrl,
      'caregivingCertificatesUrl': caregivingCertificatesUrl,
      'examScore': examScore,
      'examTotalQuestions': examTotalQuestions,
      'examPercentage': examPercentage,
      'examCompletedAt': examCompletedAt?.toIso8601String(),
      'examAnswers': examAnswers,
      'status': status,
      'rejectionReason': rejectionReason,
      'reviewedAt': reviewedAt?.toIso8601String(),
      'reviewedBy': reviewedBy,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}

