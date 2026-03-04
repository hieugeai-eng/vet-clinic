import 'dart:convert';
import '../../core/constants/permissions.dart';

class ProfileModel {
  final String id;
  final String? clinicId;
  final String role;
  final String? fullName;
  final String? avatarUrl;
  final bool isActive;
  final Map<String, dynamic> preferences;
  final String? specialization;
  final String? pinHash;
  final String? staffCode;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProfileModel({
    required this.id,
    this.clinicId,
    this.role = 'staff',
    this.fullName,
    this.avatarUrl,
    this.isActive = true,
    this.preferences = const {},
    this.specialization,
    this.pinHash,
    this.staffCode,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'clinic_id': clinicId,
      'role': role,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'is_active': isActive ? 1 : 0,
      'preferences': preferences,
      'specialization': specialization,
      'pin_hash': pinHash,
      'staff_code': staffCode,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'],
      clinicId: json['clinic_id'],
      role: json['role'] ?? 'staff',
      fullName: json['full_name'],
      avatarUrl: json['avatar_url'],
      isActive: json['is_active'] == 1 || json['is_active'] == true,
      preferences: json['preferences'] is Map ? json['preferences'] : {},
      specialization: json['specialization'],
      pinHash: json['pin_hash'],
      staffCode: json['staff_code'],
      createdAt:
          DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now(),
    );
  }

  bool get isAdmin => role == 'admin' || role == 'owner';
  bool get isDoctor => role == 'doctor' || role == 'vet';
  bool get isOwner => role == 'owner';

  /// Get typed AppRole enum
  AppRole get appRole => AppRole.fromString(role);
}
