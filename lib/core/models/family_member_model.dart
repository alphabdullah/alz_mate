class FamilyMemberModel {
  final String id;
  final String userId;
  final String name;
  final String relationship;
  final String? notes;
  final String imageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? phone;
  final bool isPrimaryContact;

  FamilyMemberModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.relationship,
    required this.imageUrl,
    required this.createdAt,
    required this.updatedAt,
    this.notes,
    this.phone,
    this.isPrimaryContact = false,
  });

  factory FamilyMemberModel.fromMap(Map<String, dynamic> map, String id) {
    return FamilyMemberModel(
      id: id,
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      relationship: map['relationship'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      notes: map['notes'],
      phone: map['phone'],
      isPrimaryContact: map['isPrimaryContact'] ?? false,
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'relationship': relationship,
      'notes': notes,
      'phone': phone,
      'isPrimaryContact': isPrimaryContact,
      'imageUrl': imageUrl,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
