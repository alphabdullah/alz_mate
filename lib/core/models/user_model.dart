import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String role;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? lastActive;

  final String? phone;
  final String? profileImageUrl;

  final String? emergencyContact;
  final String? medicalConditions;
  final String? medications;
  final String? address;
  final DateTime? dateOfBirth;
  final String? bloodType;
  final String? allergies;

  // Caregiver-specific
  final String? specialization;
  final String? licenseNumber;
  final List<String>? patientIds;

  // Family-specific
  final Map<String, dynamic>? metadata;

  // Additional profile fields
  final bool isVerified;
  final String? timezone;
  final String? preferredLanguage;
  final Map<String, bool>? notificationSettings;
  final DateTime? lastPasswordChange;
  
  // Caregiver verification status
  final String? caregiverVerificationStatus; // 'pending', 'approved', 'rejected'

  // Patient-specific additional fields
  final String? insuranceProvider;
  final String? insuranceNumber;
  final String? primaryPhysician;
  final List<String>? caregiverIds;

  // Caregiver-specific additional fields
  final int? yearsOfExperience;
  final String? hospitalClinic;
  final String? department;
  final List<String>? certifications;
  final double? rating;
  final int? totalPatientsServed;

  // Family-specific additional fields
  final String? relationshipToPatient;
  final String? patientId;
  final bool? isPrimaryContact;

  final String? fcmToken;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.createdAt,
    this.updatedAt,
    this.lastActive,
    this.phone,
    this.profileImageUrl,
    this.emergencyContact,
    this.medicalConditions,
    this.medications,
    this.address,
    this.dateOfBirth,
    this.bloodType,
    this.allergies,
    this.specialization,
    this.licenseNumber,
    this.patientIds,
    this.metadata,
    this.isVerified = false,
    this.timezone,
    this.preferredLanguage,
    this.notificationSettings,
    this.lastPasswordChange,
    this.caregiverVerificationStatus,
    this.insuranceProvider,
    this.insuranceNumber,
    this.primaryPhysician,
    this.caregiverIds,
    this.yearsOfExperience,
    this.hospitalClinic,
    this.department,
    this.certifications,
    this.rating,
    this.totalPatientsServed,
    this.relationshipToPatient,
    this.patientId,
    this.isPrimaryContact,
    this.fcmToken,
  });

  /// ✅ Computed getter: Age
  int? get age {
    if (dateOfBirth == null) return null;
    final now = DateTime.now();
    int age = now.year - dateOfBirth!.year;
    if (now.month < dateOfBirth!.month ||
        (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day)) {
      age--;
    }
    return age;
  }

  /// ✅ Computed getter: Active within 24 hours
  bool get isActive {
    if (lastActive == null) return false;
    return DateTime.now().difference(lastActive!).inHours < 24;
  }

  /// ✅ Role Helpers
  bool get isPatient => role.toLowerCase() == 'patient';
  bool get isCaregiver => role.toLowerCase() == 'caregiver';
  bool get isFamily => role.toLowerCase() == 'family';

  /// ✅ Profile completion percentage
  double get profileCompletionPercentage {
    int totalFields = 10; // Base fields
    int completedFields = 0;

    if (name.isNotEmpty) completedFields++;
    if (email.isNotEmpty) completedFields++;
    if (phone != null && phone!.isNotEmpty) completedFields++;
    if (address != null && address!.isNotEmpty) completedFields++;
    if (dateOfBirth != null) completedFields++;
    if (profileImageUrl != null) completedFields++;

    // Role-specific fields
    if (isPatient) {
      totalFields += 4;
      if (medicalConditions != null) completedFields++;
      if (medications != null) completedFields++;
      if (bloodType != null) completedFields++;
      if (allergies != null) completedFields++;
    } else if (isCaregiver) {
      totalFields += 4;
      if (specialization != null) completedFields++;
      if (licenseNumber != null) completedFields++;
      if (yearsOfExperience != null) completedFields++;
      if (hospitalClinic != null) completedFields++;
    } else if (isFamily) {
      totalFields += 2;
      if (relationshipToPatient != null) completedFields++;
      if (patientId != null) completedFields++;
    }

    return (completedFields / totalFields) * 100;
  }

  /// ✅ Display name with role
  String get displayNameWithRole {
    String roleDisplay = role.toLowerCase();
    if (isCaregiver && specialization != null) {
      roleDisplay = specialization!;
    }
    return '$name ($roleDisplay)';
  }

  /// ✅ Check if password needs update (older than 90 days)
  bool get needsPasswordUpdate {
    if (lastPasswordChange == null) return true;
    return DateTime.now().difference(lastPasswordChange!).inDays > 90;
  }

  /// ✅ Get notification setting
  bool getNotificationSetting(String key) {
    return notificationSettings?[key] ?? true;
  }

  /// ✅ CopyWith
  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? role,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastActive,
    String? phone,
    String? profileImageUrl,
    String? emergencyContact,
    String? medicalConditions,
    String? medications,
    String? address,
    DateTime? dateOfBirth,
    String? bloodType,
    String? allergies,
    String? specialization,
    String? licenseNumber,
    List<String>? patientIds,
    Map<String, dynamic>? metadata,
    bool? isVerified,
    String? timezone,
    String? preferredLanguage,
    Map<String, bool>? notificationSettings,
    DateTime? lastPasswordChange,
    String? insuranceProvider,
    String? insuranceNumber,
    String? primaryPhysician,
    List<String>? caregiverIds,
    int? yearsOfExperience,
    String? hospitalClinic,
    String? department,
    List<String>? certifications,
    double? rating,
    int? totalPatientsServed,
    String? relationshipToPatient,
    String? patientId,
    bool? isPrimaryContact,
    String? fcmToken,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastActive: lastActive ?? this.lastActive,
      phone: phone ?? this.phone,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      medicalConditions: medicalConditions ?? this.medicalConditions,
      medications: medications ?? this.medications,
      address: address ?? this.address,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      bloodType: bloodType ?? this.bloodType,
      allergies: allergies ?? this.allergies,
      specialization: specialization ?? this.specialization,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      patientIds: patientIds ?? this.patientIds,
      metadata: metadata ?? this.metadata,
      isVerified: isVerified ?? this.isVerified,
      timezone: timezone ?? this.timezone,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      notificationSettings: notificationSettings ?? this.notificationSettings,
      lastPasswordChange: lastPasswordChange ?? this.lastPasswordChange,
      caregiverVerificationStatus: caregiverVerificationStatus ?? caregiverVerificationStatus,
      insuranceProvider: insuranceProvider ?? this.insuranceProvider,
      insuranceNumber: insuranceNumber ?? this.insuranceNumber,
      primaryPhysician: primaryPhysician ?? this.primaryPhysician,
      caregiverIds: caregiverIds ?? this.caregiverIds,
      yearsOfExperience: yearsOfExperience ?? this.yearsOfExperience,
      hospitalClinic: hospitalClinic ?? this.hospitalClinic,
      department: department ?? this.department,
      certifications: certifications ?? this.certifications,
      rating: rating ?? this.rating,
      totalPatientsServed: totalPatientsServed ?? this.totalPatientsServed,
      relationshipToPatient:
          relationshipToPatient ?? this.relationshipToPatient,
      patientId: patientId ?? this.patientId,
      isPrimaryContact: isPrimaryContact ?? this.isPrimaryContact,
      fcmToken: fcmToken ?? this.fcmToken
    );
  }

  static DateTime? _toDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  /// ✅ From JSON
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      role: json['role'],
      createdAt: _toDate(json['createdAt'])!,
      updatedAt: _toDate(json['updatedAt']),
      lastActive: _toDate(json['lastActive']),
      phone: json['phone'],
      profileImageUrl: json['profileImageUrl'],
      emergencyContact: json['emergencyContact'],
      medicalConditions: json['medicalConditions'],
      medications: json['medications'],
      address: json['address'],
      dateOfBirth: _toDate(json['dateOfBirth']),
      bloodType: json['bloodType'],
      allergies: json['allergies'],
      specialization: json['specialization'],
      licenseNumber: json['licenseNumber'],
      patientIds: (json['patientIds'] as List?)
          ?.map((e) => e.toString())
          .toList(),
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'])
          : null,
      isVerified: json['isVerified'] ?? false,
      timezone: json['timezone'],
      preferredLanguage: json['preferredLanguage'],
      notificationSettings: json['notificationSettings'] != null
          ? Map<String, bool>.from(json['notificationSettings'])
          : null,
      lastPasswordChange: _toDate(json['lastPasswordChange']),
      caregiverVerificationStatus: json['caregiverVerificationStatus'],
      insuranceProvider: json['insuranceProvider'],
      insuranceNumber: json['insuranceNumber'],
      primaryPhysician: json['primaryPhysician'],
      caregiverIds: (json['caregiverIds'] as List?)
          ?.map((e) => e.toString())
          .toList(),
      yearsOfExperience: json['yearsOfExperience'],
      hospitalClinic: json['hospitalClinic'],
      department: json['department'],
      certifications: (json['certifications'] as List?)
          ?.map((e) => e.toString())
          .toList(),
      rating: json['rating']?.toDouble(),
      totalPatientsServed: json['totalPatientsServed'],
      relationshipToPatient: json['relationshipToPatient'],
      patientId: json['patientId'],
      isPrimaryContact: json['isPrimaryContact'],
      fcmToken: json['fcm_token']
    );
  }

  /// ✅ To JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'lastActive': lastActive?.toIso8601String(),
      'phone': phone,
      'profileImageUrl': profileImageUrl,
      'emergencyContact': emergencyContact,
      'medicalConditions': medicalConditions,
      'medications': medications,
      'address': address,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'bloodType': bloodType,
      'allergies': allergies,
      'specialization': specialization,
      'licenseNumber': licenseNumber,
      'patientIds': patientIds,
      'metadata': metadata,
      'isVerified': isVerified,
      'timezone': timezone,
      'preferredLanguage': preferredLanguage,
      'notificationSettings': notificationSettings,
      'lastPasswordChange': lastPasswordChange?.toIso8601String(),
      'caregiverVerificationStatus': caregiverVerificationStatus,
      'insuranceProvider': insuranceProvider,
      'insuranceNumber': insuranceNumber,
      'primaryPhysician': primaryPhysician,
      'caregiverIds': caregiverIds,
      'yearsOfExperience': yearsOfExperience,
      'hospitalClinic': hospitalClinic,
      'department': department,
      'certifications': certifications,
      'rating': rating,
      'totalPatientsServed': totalPatientsServed,
      'relationshipToPatient': relationshipToPatient,
      'patientId': patientId,
      'isPrimaryContact': isPrimaryContact,
      'fcm_token': fcmToken
    };
  }

  @override
  String toString() {
    return 'UserModel(id: $id, name: $name, role: $role)';
  }
}
