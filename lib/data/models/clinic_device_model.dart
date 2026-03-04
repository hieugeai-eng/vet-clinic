class ClinicDeviceModel {
  final String id;
  final String clinicId;
  final String deviceId;
  final String? deviceName;
  final String? licenseKeyUsed;
  final bool isApproved;
  final String? lastIp;
  final DateTime? lastActiveAt;
  final DateTime createdAt;

  ClinicDeviceModel({
    required this.id,
    required this.clinicId,
    required this.deviceId,
    this.deviceName,
    this.licenseKeyUsed,
    this.isApproved = false,
    this.lastIp,
    this.lastActiveAt,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'clinic_id': clinicId,
      'device_id': deviceId,
      'device_name': deviceName,
      'license_key_used': licenseKeyUsed,
      'is_approved': isApproved ? 1 : 0,
      'last_ip': lastIp,
      'last_active_at': lastActiveAt?.toUtc().toIso8601String(),
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  factory ClinicDeviceModel.fromJson(Map<String, dynamic> json) {
    return ClinicDeviceModel(
      id: json['id'],
      clinicId: json['clinic_id'],
      deviceId: json['device_id'],
      deviceName: json['device_name'],
      licenseKeyUsed: json['license_key_used'],
      isApproved: json['is_approved'] == 1 || json['is_approved'] == true,
      lastIp: json['last_ip'],
      lastActiveAt: DateTime.tryParse(json['last_active_at'].toString()),
      createdAt:
          DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now(),
    );
  }
}
