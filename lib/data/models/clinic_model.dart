class ClinicModel {
  final String id;
  final String name;
  final String? address;
  final String? phone;
  final String? licenseKey;
  final bool isActive;
  final Map<String, dynamic> settings;
  final String subscriptionTier;
  final DateTime? subscriptionEndAt;
  final String? logoUrl;

  ClinicModel({
    required this.id,
    required this.name,
    this.address,
    this.phone,
    this.licenseKey,
    this.isActive = true,
    this.ownerId,
    this.settings = const {},
    this.subscriptionTier = 'free',
    this.subscriptionEndAt,
    this.logoUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  final String? ownerId;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'phone': phone,
      'license_key': licenseKey,
      'is_active': isActive ? 1 : 0,
      'owner_id': ownerId,
      'settings': settings, // Handled by serializer usually
      'subscription_tier': subscriptionTier,
      'subscription_end_at': subscriptionEndAt?.toUtc().toIso8601String(),
      'logo_url': logoUrl,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  factory ClinicModel.fromJson(Map<String, dynamic> json) {
    return ClinicModel(
      id: json['id'],
      name: json['name'],
      address: json['address'],
      phone: json['phone'],
      licenseKey: json['license_key'],
      isActive: json['is_active'] == 1 || json['is_active'] == true,
      ownerId: json['owner_id'],
      settings: json['settings'] is Map ? json['settings'] : {},
      subscriptionTier: json['subscription_tier'] ?? 'free',
      subscriptionEndAt: DateTime.tryParse(
        json['subscription_end_at'].toString(),
      ),
      logoUrl: json['logo_url'],
      createdAt:
          DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now(),
    );
  }
}
