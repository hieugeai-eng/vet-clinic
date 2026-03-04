class ClinicInviteModel {
  final String id;
  final String clinicId;
  final String email;
  final String role;
  final String code;
  final String? invitedBy;
  final DateTime expiredAt;
  final String status; // pending, accepted, expired
  final DateTime createdAt;

  ClinicInviteModel({
    required this.id,
    required this.clinicId,
    required this.email,
    required this.role,
    required this.code,
    this.invitedBy,
    required this.expiredAt,
    this.status = 'pending',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'clinic_id': clinicId,
      'email': email,
      'role': role,
      'code': code,
      'invited_by': invitedBy,
      'expired_at': expiredAt.toUtc().toIso8601String(),
      'status': status,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  factory ClinicInviteModel.fromJson(Map<String, dynamic> json) {
    return ClinicInviteModel(
      id: json['id'],
      clinicId: json['clinic_id'],
      email: json['email'],
      role: json['role'],
      code: json['code'],
      invitedBy: json['invited_by'],
      expiredAt: DateTime.parse(json['expired_at']),
      status: json['status'] ?? 'pending',
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
