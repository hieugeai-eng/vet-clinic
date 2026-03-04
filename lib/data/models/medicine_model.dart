/// Medicine model - Thuốc/Vật tư y tế
class MedicineModel {
  final String id;
  final String? clinicId;
  final String code; // Mã hàng
  final String name;
  final String? unit; // Viên, ml, Ống, etc.
  final double avgPrice; // Giá nhập TB
  final double stock; // Số lượng tồn
  final double? minStock; // Cảnh báo tồn kho tối thiểu
  final String? lotNumber; // Lô sản xuất
  final DateTime? expiryDate;
  final String? supplier;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool synced;

  MedicineModel({
    required this.id,
    this.clinicId,
    required this.code,
    required this.name,
    this.unit,
    this.avgPrice = 0,
    this.stock = 0,
    this.minStock,
    this.lotNumber,
    this.expiryDate,
    this.supplier,
    this.isActive = true,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.synced = false,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory MedicineModel.fromJson(Map<String, dynamic> json) {
    return MedicineModel(
      id: json['id'] as String,
      clinicId: json['clinic_id'] as String?,
      code: json['code'] as String,
      name: json['name'] as String,
      unit: json['unit'] as String?,
      avgPrice: (json['avg_price'] as num?)?.toDouble() ?? 0,
      stock: (json['stock'] as num?)?.toDouble() ?? 0,
      minStock: (json['min_stock'] as num?)?.toDouble(),
      lotNumber: json['lot_number'] as String?,
      expiryDate: json['expiry_date'] != null
          ? DateTime.parse(json['expiry_date'] as String)
          : null,
      supplier: json['supplier'] as String?,
      isActive: json['is_active'] == 1 || json['is_active'] == true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      synced: json['synced'] == 1 || json['synced'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'clinic_id': clinicId,
      'code': code,
      'name': name,
      'unit': unit,
      'avg_price': avgPrice,
      'stock': stock,
      'min_stock': minStock,
      'lot_number': lotNumber,
      'expiry_date': expiryDate?.toUtc().toIso8601String(),
      'supplier': supplier,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'synced': synced ? 1 : 0,
    };
  }

  MedicineModel copyWith({
    String? id,
    String? clinicId,
    String? code,
    String? name,
    String? unit,
    double? avgPrice,
    double? stock,
    double? minStock,
    String? lotNumber,
    DateTime? expiryDate,
    String? supplier,
    bool? isActive,
    bool? synced,
  }) {
    return MedicineModel(
      id: id ?? this.id,
      clinicId: clinicId ?? this.clinicId,
      code: code ?? this.code,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      avgPrice: avgPrice ?? this.avgPrice,
      stock: stock ?? this.stock,
      minStock: minStock ?? this.minStock,
      lotNumber: lotNumber ?? this.lotNumber,
      expiryDate: expiryDate ?? this.expiryDate,
      supplier: supplier ?? this.supplier,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      synced: synced ?? this.synced,
    );
  }

  /// Check if stock is low
  bool get isLowStock => minStock != null && stock <= minStock!;

  /// Check if expired
  bool get isExpired =>
      expiryDate != null && expiryDate!.isBefore(DateTime.now());

  /// Check if expiring soon (within 30 days)
  bool get isExpiringSoon =>
      expiryDate != null &&
      expiryDate!.isBefore(DateTime.now().add(const Duration(days: 30)));

  /// Get stock value
  double get stockValue => stock * avgPrice;

  @override
  String toString() => 'MedicineModel(code: $code, name: $name, stock: $stock)';
}

/// Medicine Transaction - Nhập/Xuất/Sử dụng thuốc
class MedicineTransactionModel {
  final String id;
  final String? clinicId;
  final String medicineId;
  final String type; // import, export, use
  final double quantity;
  final double? unitPrice;
  final String? caseId; // Nếu xuất cho ca bệnh
  final String? lotNumber;
  final String? purpose; // Mục đích sử dụng
  final String? staffId;
  final String? notes;
  final DateTime transactionDate;
  final DateTime createdAt;
  final bool synced;

  MedicineTransactionModel({
    required this.id,
    this.clinicId,
    required this.medicineId,
    required this.type,
    required this.quantity,
    this.unitPrice,
    this.caseId,
    this.lotNumber,
    this.purpose,
    this.staffId,
    this.notes,
    DateTime? transactionDate,
    DateTime? createdAt,
    this.synced = false,
  }) : transactionDate = transactionDate ?? DateTime.now(),
       createdAt = createdAt ?? DateTime.now();

  factory MedicineTransactionModel.fromJson(Map<String, dynamic> json) {
    return MedicineTransactionModel(
      id: json['id'] as String,
      clinicId: json['clinic_id'] as String?,
      medicineId: json['medicine_id'] as String,
      type: json['type'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unitPrice: (json['unit_price'] as num?)?.toDouble(),
      caseId: json['case_id'] as String?,
      lotNumber: json['lot_number'] as String?,
      purpose: json['purpose'] as String?,
      staffId: json['staff_id'] as String?,
      notes: json['notes'] as String?,
      transactionDate: json['transaction_date'] != null
          ? DateTime.parse(json['transaction_date'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      synced: json['synced'] == 1 || json['synced'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'clinic_id': clinicId,
      'medicine_id': medicineId,
      'type': type,
      'quantity': quantity,
      'unit_price': unitPrice,
      'case_id': caseId,
      'lot_number': lotNumber,
      'purpose': purpose,
      'staff_id': staffId,
      'notes': notes,
      'transaction_date': transactionDate.toUtc().toIso8601String(),
      'created_at': createdAt.toUtc().toIso8601String(),
      'synced': synced ? 1 : 0,
    };
  }

  /// Get total value
  double get totalValue => quantity * (unitPrice ?? 0);

  /// Check if import
  bool get isImport => type == 'import';

  /// Check if export/use
  bool get isExport => type == 'export' || type == 'use';
}
