class CageOccupant {
  final String hospitalizationId;
  final String caseId;
  final String petId;
  final String petName;
  final DateTime admissionDate;
  final String? staffName; // Người chăm sóc / nhập viện
  final String? diagnosis;
  final List<String> activeTreatments;

  CageOccupant({
    required this.hospitalizationId,
    required this.caseId,
    required this.petId,
    required this.petName,
    required this.admissionDate,
    this.staffName,
    this.diagnosis,
    this.activeTreatments = const [],
  });

  factory CageOccupant.fromJson(Map<String, dynamic> json) {
    List<String> treatments = [];
    if (json['active_treatments'] != null &&
        json['active_treatments'] is String) {
      if (json['active_treatments'].toString().isNotEmpty) {
        treatments = json['active_treatments']
            .toString()
            .split(',')
            .map((e) => e.trim())
            .toList();
      }
    } else if (json['active_treatments'] is List) {
      treatments = List<String>.from(json['active_treatments']);
    }

    return CageOccupant(
      hospitalizationId: json['id']?.toString() ?? '',
      caseId: json['case_id']?.toString() ?? '',
      petId: json['pet_id']?.toString() ?? '',
      petName: json['pet_name']?.toString() ?? 'Unknown',
      admissionDate: json['admission_date'] != null
          ? DateTime.parse(json['admission_date'].toString())
          : DateTime.now(),
      staffName: json['staff_name']?.toString(),
      diagnosis: json['diagnosis']?.toString(),
      activeTreatments: treatments,
    );
  }
}

class CageModel {
  final String id;
  final String? clinicId; // Added for multi-tenancy
  final String name;
  final String type; // dog, cat, isolation
  final String status; // available, occupied, maintenance
  final double price;
  final int orderIndex;

  // List of occupants
  final List<CageOccupant> occupants;

  CageModel({
    required this.id,
    this.clinicId,
    required this.name,
    this.type = 'dog',
    this.status = 'available',
    this.price = 0.0,
    this.orderIndex = 0,
    this.occupants = const [],
  });

  factory CageModel.fromJson(
    Map<String, dynamic> json, {
    List<CageOccupant> occupants = const [],
  }) {
    // If not passed explicitly, we assume json might contain single occupant info (deprecated/legacy support if needed)
    // But for this refactor, we rely on repository injecting the list.
    return CageModel(
      id: json['id'],
      clinicId: json['clinic_id'],
      name: json['name'],
      type: json['type'] ?? 'dog',
      status: json['status'] ?? 'available',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      orderIndex: json['order_index'] as int? ?? 0,
      occupants: occupants,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'clinic_id': clinicId,
      'name': name,
      'type': type,
      'status': status,
      'price': price,
      'order_index': orderIndex,
    };
  }

  CageModel copyWith({
    String? id,
    String? clinicId,
    String? name,
    String? type,
    String? status,
    double? price,
    int? orderIndex,
    List<CageOccupant>? occupants,
  }) {
    return CageModel(
      id: id ?? this.id,
      clinicId: clinicId ?? this.clinicId,
      name: name ?? this.name,
      type: type ?? this.type,
      status: status ?? this.status,
      price: price ?? this.price,
      orderIndex: orderIndex ?? this.orderIndex,
      occupants: occupants ?? this.occupants,
    );
  }
}
