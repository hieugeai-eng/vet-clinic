/// Expense model - Chi phí hoạt động
class ExpenseModel {
  final String id;
  final String? clinicId; // Added for multi-tenancy
  final DateTime date;
  final String content; // Nội dung chi
  final String category; // Hạng mục chi
  final double amount;
  final int? quantity;
  final String? unit;
  final double? unitPrice;
  final String? staffId;
  final String type; // 'income' or 'expense'
  final String paymentMethod; // 'cash' or 'transfer'
  final String? notes;
  final DateTime createdAt;
  final bool synced;

  ExpenseModel({
    required this.id,
    this.clinicId,
    required this.date,
    required this.content,
    required this.category,
    required this.amount,
    this.quantity,
    this.unit,
    this.unitPrice,
    this.staffId,
    this.type = 'expense',
    this.paymentMethod = 'cash',
    this.notes,
    DateTime? createdAt,
    this.synced = false,
  }) : createdAt = createdAt ?? DateTime.now();

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    return ExpenseModel(
      id: json['id'] as String,
      clinicId: json['clinic_id'] as String?,
      date: DateTime.parse(json['date'] as String),
      content: json['content'] as String,
      category: json['category'] as String,
      amount: (json['amount'] as num).toDouble(),
      quantity: json['quantity'] as int?,
      unit: json['unit'] as String?,
      unitPrice: (json['unit_price'] as num?)?.toDouble(),
      staffId: json['staff_id'] as String?,
      type: json['type'] as String? ?? 'expense',
      paymentMethod: json['payment_method'] as String? ?? 'cash',
      notes: json['notes'] as String?,
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
      'date': date.toUtc().toIso8601String(),
      'content': content,
      'category': category,
      'amount': amount,
      'quantity': quantity,
      'unit': unit,
      'unit_price': unitPrice,
      'staff_id': staffId,
      'type': type,
      'payment_method': paymentMethod,
      'notes': notes,
      'created_at': createdAt.toUtc().toIso8601String(),
      'synced': synced ? 1 : 0,
    };
  }

  ExpenseModel copyWith({
    String? id,
    String? clinicId,
    DateTime? date,
    String? content,
    String? category,
    double? amount,
    int? quantity,
    String? unit,
    double? unitPrice,
    String? staffId,
    String? type,
    String? paymentMethod,
    String? notes,
    bool? synced,
  }) {
    return ExpenseModel(
      id: id ?? this.id,
      clinicId: clinicId ?? this.clinicId,
      date: date ?? this.date,
      content: content ?? this.content,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      unitPrice: unitPrice ?? this.unitPrice,
      staffId: staffId ?? this.staffId,
      type: type ?? this.type,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      synced: synced ?? this.synced,
    );
  }

  @override
  String toString() =>
      'ExpenseModel(content: $content, type: $type, amount: $amount)';
}

/// Expense categories from data
class ExpenseCategory {
  static const String fuel = 'Xăng xe ca';
  static const String testing = 'Xét nghiệm';
  static const String medicine = 'Thuốc điều trị';
  static const String supplies = 'Vật tư';
  static const String food = 'Tiền ăn';
  static const String salary = 'Lương';
  static const String utilities = 'Điện nước';
  static const String other = 'Chi khác';

  static List<String> get all => [
    fuel,
    testing,
    medicine,
    supplies,
    food,
    salary,
    utilities,
    other,
  ];
}
