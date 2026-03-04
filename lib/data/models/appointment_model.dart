/// Appointment model - Lịch hẹn
class AppointmentModel {
  final String id;
  final String? clinicId;
  final String customerId;
  final String? petId;
  final DateTime appointmentDate;
  final String? time;
  final String? reason;
  final String status; // pending, confirmed, completed, cancelled
  final String? notes;
  final String? staffId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool synced;

  // Related data (for display)
  final String? customerName;
  final String? customerPhone;
  final String? petName;

  AppointmentModel({
    required this.id,
    this.clinicId,
    required this.customerId,
    this.petId,
    required this.appointmentDate,
    this.time,
    this.reason,
    this.status = 'confirmed',
    this.notes,
    this.staffId,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.synced = false,
    this.customerName,
    this.customerPhone,
    this.petName,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory AppointmentModel.fromJson(Map<String, dynamic> json) {
    return AppointmentModel(
      id: json['id'] as String,
      clinicId: json['clinic_id'] as String?,
      customerId: json['customer_id'] as String,
      petId: json['pet_id'] as String?,
      appointmentDate: DateTime.parse(
        json['appointment_date'] as String,
      ).toLocal(),
      time: json['time'] as String?,
      reason: json['reason'] as String?,
      status: json['status'] as String? ?? 'confirmed',
      notes: json['notes'] as String?,
      staffId: json['staff_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      synced: json['synced'] == 1 || json['synced'] == true,
      customerName: json['customer_name'] as String?,
      customerPhone: json['customer_phone'] as String?,
      petName: json['pet_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'clinic_id': clinicId,
      'customer_id': customerId,
      'pet_id': petId,
      'appointment_date': appointmentDate.toUtc().toIso8601String(),
      'time': time,
      'reason': reason,
      'status': status,
      'notes': notes,
      'staff_id': staffId,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'synced': synced ? 1 : 0,
    };
  }

  AppointmentModel copyWith({
    String? id,
    String? clinicId,
    String? customerId,
    String? petId,
    DateTime? appointmentDate,
    String? time,
    String? reason,
    String? status,
    String? notes,
    String? staffId,
    bool? synced,
    String? customerName,
    String? customerPhone,
    String? petName,
  }) {
    return AppointmentModel(
      id: id ?? this.id,
      clinicId: clinicId ?? this.clinicId,
      customerId: customerId ?? this.customerId,
      petId: petId ?? this.petId,
      appointmentDate: appointmentDate ?? this.appointmentDate,
      time: time ?? this.time,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      staffId: staffId ?? this.staffId,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      synced: synced ?? this.synced,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      petName: petName ?? this.petName,
    );
  }

  /// Check if appointment is today
  bool get isToday {
    final now = DateTime.now();
    return appointmentDate.year == now.year &&
        appointmentDate.month == now.month &&
        appointmentDate.day == now.day;
  }

  /// Check if appointment is past
  bool get isPast => appointmentDate.isBefore(DateTime.now());

  /// Check if appointment is upcoming
  bool get isUpcoming => appointmentDate.isAfter(DateTime.now());

  @override
  String toString() => 'AppointmentModel(id: $id, date: $appointmentDate)';
}

/// Appointment status options
class AppointmentStatus {
  static const String pending = 'pending';
  static const String confirmed = 'confirmed';
  static const String completed = 'completed';
  static const String cancelled = 'cancelled';

  static List<String> get all => [pending, confirmed, completed, cancelled];

  static String getLabel(String status) {
    switch (status) {
      case pending:
        return 'Chờ xác nhận';
      case confirmed:
        return 'Đã xác nhận';
      case completed:
        return 'Hoàn thành';
      case cancelled:
        return 'Đã hủy';
      default:
        return status;
    }
  }
}
