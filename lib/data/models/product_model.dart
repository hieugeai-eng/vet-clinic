/// Product model - Sản phẩm Petshop
class ProductModel {
  final String id;
  final String? clinicId;
  final String name;
  final String? brand;
  final double salePrice; // Giá bán
  final double costPrice; // Giá vốn
  final int stock; // Số lượng tồn
  final String? category;
  final String? imageUrl;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool synced;

  ProductModel({
    required this.id,
    this.clinicId,
    required this.name,
    this.brand,
    required this.salePrice,
    required this.costPrice,
    this.stock = 0,
    this.category,
    this.imageUrl,
    this.isActive = true,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.synced = false,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] as String,
      clinicId: json['clinic_id'] as String?,
      name: json['name'] as String,
      brand: json['brand'] as String?,
      salePrice: (json['sale_price'] as num).toDouble(),
      costPrice: (json['cost_price'] as num).toDouble(),
      stock: json['stock'] as int? ?? 0,
      category: json['category'] as String?,
      imageUrl: json['image_url'] as String?,
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
      'name': name,
      'brand': brand,
      'sale_price': salePrice,
      'cost_price': costPrice,
      'stock': stock,
      'category': category,
      'image_url': imageUrl,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'synced': synced ? 1 : 0,
    };
  }

  ProductModel copyWith({
    String? id,
    String? clinicId,
    String? name,
    String? brand,
    double? salePrice,
    double? costPrice,
    int? stock,
    String? category,
    String? imageUrl,
    bool? isActive,
    bool? synced,
  }) {
    return ProductModel(
      id: id ?? this.id,
      clinicId: clinicId ?? this.clinicId,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      salePrice: salePrice ?? this.salePrice,
      costPrice: costPrice ?? this.costPrice,
      stock: stock ?? this.stock,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      synced: synced ?? this.synced,
    );
  }

  /// Get profit per item
  double get profit => salePrice - costPrice;

  /// Get profit margin percentage
  double get profitMargin => costPrice > 0 ? (profit / costPrice) * 100 : 0;

  /// Check if out of stock
  bool get isOutOfStock => stock <= 0;

  @override
  String toString() => 'ProductModel(name: $name, stock: $stock)';
}

/// Product Sale - Bán hàng Petshop
class ProductSaleModel {
  final String id;
  final String? clinicId;
  final String productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double total;
  final String? customerId;
  final String? staffId;
  final String paymentMethod;
  final DateTime saleDate;
  final DateTime createdAt;
  final bool synced;
  final String? caseId;
  final String? caseCode;
  final String? caseCustomerName;
  final String? casePetName;
  final String? caseVisitReasons;
  final String? mappedStaffName;
  final int returnedQuantity;
  final bool isReturned;

  ProductSaleModel({
    required this.id,
    this.clinicId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    double? total,
    this.customerId,
    this.staffId,
    this.paymentMethod = 'cash',
    DateTime? saleDate,
    DateTime? createdAt,
    this.synced = false,
    this.caseId,
    this.caseCode,
    this.caseCustomerName,
    this.casePetName,
    this.caseVisitReasons,
    this.mappedStaffName,
    this.returnedQuantity = 0,
    this.isReturned = false,
  }) : total = total ?? (unitPrice * quantity),
       saleDate = saleDate ?? DateTime.now(),
       createdAt = createdAt ?? DateTime.now();

  factory ProductSaleModel.fromJson(Map<String, dynamic> json) {
    return ProductSaleModel(
      id: json['id'] as String,
      clinicId: json['clinic_id'] as String?,
      productId: json['product_id'] as String,
      productName: json['product_name'] as String,
      quantity: json['quantity'] as int,
      unitPrice: (json['unit_price'] as num).toDouble(),
      total: (json['total'] as num?)?.toDouble(),
      customerId: json['customer_id'] as String?,
      staffId: json['staff_id'] as String?,
      paymentMethod: json['payment_method'] as String? ?? 'cash',
      saleDate: json['sale_date'] != null
          ? DateTime.parse(json['sale_date'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      synced: json['synced'] == 1 || json['synced'] == true,
      caseId: json['case_id'] as String?,
      caseCode: json['case_code'] as String?,
      caseCustomerName: json['case_customer_name'] as String?,
      casePetName: json['case_pet_name'] as String?,
      caseVisitReasons: json['case_visit_reasons'] as String?,
      mappedStaffName: json['mapped_staff_name'] as String?,
      returnedQuantity: json['returned_quantity'] as int? ?? 0,
      isReturned: json['is_returned'] == 1 || json['is_returned'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'clinic_id': clinicId,
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total': total,
      'customer_id': customerId,
      'staff_id': staffId,
      'payment_method': paymentMethod,
      'sale_date': saleDate.toUtc().toIso8601String(),
      'created_at': createdAt.toUtc().toIso8601String(),
      'synced': synced ? 1 : 0,
      'case_id': caseId,
      'case_code': caseCode,
      'returned_quantity': returnedQuantity,
      'is_returned': isReturned ? 1 : 0,
    };
  }
}
