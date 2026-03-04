import 'dart:convert';

/// Service model - Dịch vụ khám/điều trị
class ServiceModel {
  final String id;
  final String name;
  final String? category; // emergency, exam, treatment, surgery, etc.
  final double basePrice;
  final String? unit; // lần, ngày, ml, etc.
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  ServiceModel({
    required this.id,
    required this.name,
    this.category,
    required this.basePrice,
    this.unit,
    this.isActive = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    return ServiceModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      category: json['category'] as String?,
      basePrice: (json['base_price'] as num?)?.toDouble() ?? 0,
      unit: json['unit'] as String?,
      isActive: json['is_active'] == 1 || json['is_active'] == true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'base_price': basePrice,
      'unit': unit,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  ServiceModel copyWith({
    String? id,
    String? name,
    String? category,
    double? basePrice,
    String? unit,
    bool? isActive,
  }) {
    return ServiceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      basePrice: basePrice ?? this.basePrice,
      unit: unit ?? this.unit,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  @override
  String toString() => 'ServiceModel(id: $id, name: $name, price: $basePrice)';
}

/// Attached Medicine - Thuốc kèm theo dịch vụ
class AttachedMedicineModel {
  final String medicineId;
  final String name;
  final String dosage;
  final String note;
  final int quantity; // Số lượng trừ kho
  final String? refId;

  AttachedMedicineModel({
    required this.medicineId,
    required this.name,
    this.dosage = '',
    this.note = '',
    this.quantity = 1,
    this.refId,
  });

  factory AttachedMedicineModel.fromJson(Map<String, dynamic> json) {
    return AttachedMedicineModel(
      medicineId: json['medicine_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      dosage: json['dosage'] as String? ?? '',
      note: json['note'] as String? ?? '',
      quantity: json['quantity'] as int? ?? 1,
      refId: json['ref_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'medicine_id': medicineId,
      'name': name,
      'dosage': dosage,
      'note': note,
      'quantity': quantity,
      if (refId != null) 'ref_id': refId,
    };
  }

  AttachedMedicineModel copyWith({
    String? medicineId,
    String? name,
    String? dosage,
    String? note,
    int? quantity,
    String? refId,
  }) {
    return AttachedMedicineModel(
      medicineId: medicineId ?? this.medicineId,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      note: note ?? this.note,
      quantity: quantity ?? this.quantity,
      refId: refId ?? this.refId,
    );
  }
}

/// Case Service - Dịch vụ trong ca bệnh
class CaseServiceModel {
  final String id;
  final String caseId;
  final String serviceId;
  final String serviceName;
  final int quantity;
  final double unitPrice;
  final double discount; // New: Giảm giá
  final double total;
  final String? notes;
  final List<AttachedMedicineModel> attachedMedicines; // List thuốc kèm theo

  CaseServiceModel({
    required this.id,
    required this.caseId,
    required this.serviceId,
    required this.serviceName,
    this.quantity = 1,
    required this.unitPrice,
    this.discount = 0,
    double? total,
    this.notes,
    this.attachedMedicines = const [],
  }) : total = total ?? ((unitPrice * quantity) - discount);

  factory CaseServiceModel.fromJson(Map<String, dynamic> json) {
    return CaseServiceModel(
      id: json['id'] as String? ?? '',
      caseId: json['case_id'] as String? ?? '',
      serviceId: json['service_id'] as String? ?? '',
      serviceName: json['service_name'] as String? ?? '',
      quantity: json['quantity'] as int? ?? 1,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0,
      total: (json['total'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
      attachedMedicines: json['medicines_json'] != null
          ? (jsonDecode(json['medicines_json'].toString()) as List)
                .map(
                  (e) =>
                      AttachedMedicineModel.fromJson(e as Map<String, dynamic>),
                )
                .toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'case_id': caseId,
      'service_id': serviceId,
      'service_name': serviceName,
      'quantity': quantity,
      'unit_price': unitPrice,
      'discount': discount,
      'total': total,
      'notes': notes,
      'medicines_json': jsonEncode(
        attachedMedicines.map((e) => e.toJson()).toList(),
      ),
    };
  }

  CaseServiceModel copyWith({
    String? id,
    String? caseId,
    String? serviceId,
    String? serviceName,
    int? quantity,
    double? unitPrice,
    double? discount,
    String? notes,
    List<AttachedMedicineModel>? attachedMedicines,
  }) {
    final newQuantity = quantity ?? this.quantity;
    final newUnitPrice = unitPrice ?? this.unitPrice;
    final newDiscount = discount ?? this.discount;
    return CaseServiceModel(
      id: id ?? this.id,
      caseId: caseId ?? this.caseId,
      serviceId: serviceId ?? this.serviceId,
      serviceName: serviceName ?? this.serviceName,
      quantity: newQuantity,
      unitPrice: newUnitPrice,
      discount: newDiscount,
      total: (newQuantity * newUnitPrice) - newDiscount,
      notes: notes ?? this.notes,
      attachedMedicines: attachedMedicines ?? this.attachedMedicines,
    );
  }
}

/// Default services based on demo.jpg
class DefaultServices {
  static List<ServiceModel> get all => [
    ServiceModel(
      id: 'svc_emergency',
      name: 'Cấp cứu',
      category: 'emergency',
      basePrice: 200000,
      unit: 'lần',
    ),
    ServiceModel(
      id: 'svc_ultrasound',
      name: 'Siêu âm',
      category: 'exam',
      basePrice: 160000,
      unit: 'lần',
    ),
    ServiceModel(
      id: 'svc_xray',
      name: 'X-quang',
      category: 'exam',
      basePrice: 150000,
      unit: 'tấm',
    ),
    ServiceModel(
      id: 'svc_hospital',
      name: 'Lưu viện',
      category: 'treatment',
      basePrice: 160000,
      unit: 'ngày',
    ),
    ServiceModel(
      id: 'svc_surgery',
      name: 'Phẫu thuật',
      category: 'surgery',
      basePrice: 2000000,
      unit: 'lần',
    ),
    ServiceModel(
      id: 'svc_anesthesia',
      name: 'Gây mê (Zoletil)',
      category: 'surgery',
      basePrice: 50000,
      unit: 'ml',
    ),
    ServiceModel(
      id: 'svc_medication',
      name: 'Thuốc',
      category: 'treatment',
      basePrice: 200000,
      unit: 'đơn',
    ),
    ServiceModel(
      id: 'svc_vaccine',
      name: 'Tiêm vaccine',
      category: 'prevention',
      basePrice: 150000,
      unit: 'mũi',
    ),
    ServiceModel(
      id: 'svc_checkup',
      name: 'Khám tổng quát',
      category: 'exam',
      basePrice: 50000,
      unit: 'lần',
    ),
    ServiceModel(
      id: 'svc_microchip',
      name: 'Bắn microchip',
      category: 'other',
      basePrice: 100000,
      unit: 'lần',
    ),
  ];
}
