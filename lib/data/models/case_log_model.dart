import 'package:uuid/uuid.dart';

class CaseLogModel {
  final String id;
  final String clinicId;
  final String caseId;
  final String? staffId;
  final String action;
  final String? notes;
  final String? metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  // App-specific metadata
  final String? staffName;

  CaseLogModel({
    String? id,
    required this.clinicId,
    required this.caseId,
    this.staffId,
    required this.action,
    this.notes,
    this.metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.staffName,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory CaseLogModel.fromJson(Map<String, dynamic> json) {
    return CaseLogModel(
      id: json['id'] as String,
      clinicId: json['clinic_id'] as String,
      caseId: json['case_id'] as String,
      staffId: json['staff_id'] as String?,
      action: json['action'] as String,
      notes: json['notes'] as String?,
      metadata: json['metadata'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      staffName: json['staff_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'clinic_id': clinicId,
      'case_id': caseId,
      'staff_id': staffId,
      'action': action,
      'notes': notes,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  CaseLogModel copyWith({
    String? id,
    String? clinicId,
    String? caseId,
    String? staffId,
    String? action,
    String? notes,
    String? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? staffName,
  }) {
    return CaseLogModel(
      id: id ?? this.id,
      clinicId: clinicId ?? this.clinicId,
      caseId: caseId ?? this.caseId,
      staffId: staffId ?? this.staffId,
      action: action ?? this.action,
      notes: notes ?? this.notes,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      staffName: staffName ?? this.staffName,
    );
  }
}
