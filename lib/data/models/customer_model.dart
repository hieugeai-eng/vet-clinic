/// Customer model - Khách hàng/Chủ thú cưng
class CustomerModel {
  final String id;
  final String? clinicId;
  final String phone;
  final String name;
  final String? address;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool synced;

  CustomerModel({
    required this.id,
    this.clinicId,
    required this.phone,
    required this.name,
    this.address,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.synced = false,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  /// Create from JSON (database/API)
  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      id: json['id'] as String,
      clinicId: json['clinic_id'] as String?,
      phone: json['phone'] as String,
      name: json['name'] as String,
      address: json['address'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      synced: json['synced'] == 1 || json['synced'] == true,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'clinic_id': clinicId,
      'phone': phone,
      'name': name,
      'address': address,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'synced': synced ? 1 : 0,
    };
  }

  /// Copy with new values
  CustomerModel copyWith({
    String? id,
    String? clinicId,
    String? phone,
    String? name,
    String? address,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? synced,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      clinicId: clinicId ?? this.clinicId,
      phone: phone ?? this.phone,
      name: name ?? this.name,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      synced: synced ?? this.synced,
    );
  }

  @override
  String toString() =>
      'CustomerModel(id: $id, clinicId: $clinicId, phone: $phone, name: $name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomerModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
