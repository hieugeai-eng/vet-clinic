import 'dart:convert';

// ============ Phase 3: Pricing & Reservations ============

class HospitalizationModel {
  final String id;
  final String caseId;
  final String petId;
  final DateTime admissionDate;
  final DateTime? dischargeDate;
  final String? cageId;
  final String status; // active, discharged
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double price; // Phase 3: Dynamic Price

  // Joined data (optional)
  final String? petName;
  final String? species;
  final String? customerName;
  final String? customerPhone;

  HospitalizationModel({
    required this.id,
    required this.caseId,
    required this.petId,
    required this.admissionDate,
    this.dischargeDate,
    this.cageId,
    this.status = 'active',
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.price = 0.0,
    this.petName,
    this.species,
    this.customerName,
    this.customerPhone,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'case_id': caseId,
      'pet_id': petId,
      'admission_date': admissionDate.toUtc().toIso8601String(),
      'discharge_date': dischargeDate?.toUtc().toIso8601String(),
      'cage_id': cageId,
      'status': status,
      'notes': notes,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'price': price,
    };
  }

  factory HospitalizationModel.fromJson(Map<String, dynamic> json) {
    return HospitalizationModel(
      id: json['id'],
      caseId: json['case_id'],
      petId: json['pet_id'],
      admissionDate: DateTime.parse(json['admission_date']),
      dischargeDate: json['discharge_date'] != null
          ? DateTime.parse(json['discharge_date'])
          : null,
      cageId: json['cage_id'],
      status: json['status'] ?? 'active',
      notes: json['notes'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      petName: json['pet_name'],
      species: json['species'],
      customerName: json['customer_name'],
      customerPhone: json['customer_phone'],
    );
  }

  HospitalizationModel copyWith({
    String? status,
    DateTime? dischargeDate,
    String? notes,
    double? price,
  }) {
    return HospitalizationModel(
      id: id,
      caseId: caseId,
      petId: petId,
      admissionDate: admissionDate,
      dischargeDate: dischargeDate ?? this.dischargeDate,
      cageId: cageId,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      price: price ?? this.price,
      petName: petName,
      species: species,
      customerName: customerName,
      customerPhone: customerPhone,
    );
  }
}

class ReservationModel {
  final String id;
  final String? clinicId;
  final String cageId;
  final String petId;
  final String? customerId;
  final DateTime startDate;
  final DateTime endDate;
  final String? note;
  final String status; // pending, confirmed, cancelled, completed
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined (optional)
  final String? petName;
  final String? customerName;

  ReservationModel({
    required this.id,
    this.clinicId,
    required this.cageId,
    required this.petId,
    this.customerId,
    required this.startDate,
    required this.endDate,
    this.note,
    this.status = 'pending',
    required this.createdAt,
    required this.updatedAt,
    this.petName,
    this.customerName,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'clinic_id': clinicId,
      'cage_id': cageId,
      'pet_id': petId,
      'customer_id': customerId,
      'start_date': startDate.toUtc().toIso8601String(),
      'end_date': endDate.toUtc().toIso8601String(),
      'note': note,
      'status': status,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  factory ReservationModel.fromJson(Map<String, dynamic> json) {
    return ReservationModel(
      id: json['id'],
      clinicId: json['clinic_id'],
      cageId: json['cage_id'],
      petId: json['pet_id'],
      customerId: json['customer_id'],
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
      note: json['note'],
      status: json['status'] ?? 'pending',
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      petName: json['pet_name'],
      customerName: json['customer_name'],
    );
  }
}

// ============ Hospitalization 2.0 (Daily Care) ============

class HospitalizationDailyModel {
  final String id;
  final String? clinicId;
  final String hospitalizationId;
  final DateTime date; // YYYY-MM-DD
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined data (not in DB table directly)
  final List<HospitalizationTreatmentModel>? treatments;
  final List<VitalSignLogModel>? vitalLogs;

  HospitalizationDailyModel({
    required this.id,
    this.clinicId,
    required this.hospitalizationId,
    required this.date,
    this.note,
    required this.createdAt,
    required this.updatedAt,
    this.treatments,
    this.vitalLogs,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'clinic_id': clinicId,
      'hospitalization_id': hospitalizationId,
      'date':
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      'note': note,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  factory HospitalizationDailyModel.fromJson(Map<String, dynamic> json) {
    return HospitalizationDailyModel(
      id: json['id'],
      clinicId: json['clinic_id'],
      hospitalizationId: json['hospitalization_id'],
      date: DateTime.parse(
        json['date'],
      ), // Ensure format handles both ISO and YYYY-MM-DD correctly
      note: json['note'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      treatments: json['treatments'] != null
          ? (json['treatments'] as List)
                .map((e) => HospitalizationTreatmentModel.fromJson(e))
                .toList()
          : null,
      vitalLogs: json['vital_logs'] != null
          ? (json['vital_logs'] as List)
                .map((e) => VitalSignLogModel.fromJson(e))
                .toList()
          : null,
    );
  }
}

class HospitalizationTreatmentModel {
  final String id;
  final String? clinicId;
  final String dailyId;
  final String type; // medicine, service, meal, hygiene, other
  final String name;
  final String? refId;
  final String? timeScheduled; // HH:mm
  final String? timePerformed; // HH:mm
  final double quantity;
  final String? unit;
  final String? dosage;
  final String status; // pending, done, cancelled
  final String? performerId;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  HospitalizationTreatmentModel({
    required this.id,
    this.clinicId,
    required this.dailyId,
    required this.type,
    required this.name,
    this.refId,
    this.timeScheduled,
    this.timePerformed,
    this.quantity = 1.0,
    this.unit,
    this.dosage,
    this.status = 'pending',
    this.performerId,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'clinic_id': clinicId,
      'daily_id': dailyId,
      'type': type,
      'name': name,
      'ref_id': refId,
      'time_scheduled': timeScheduled,
      'time_performed': timePerformed,
      'quantity': quantity,
      'unit': unit,
      'dosage': dosage,
      'status': status,
      'performer_id': performerId,
      'notes': notes,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  factory HospitalizationTreatmentModel.fromJson(Map<String, dynamic> json) {
    return HospitalizationTreatmentModel(
      id: json['id'],
      clinicId: json['clinic_id'],
      dailyId: json['daily_id'],
      type: json['type'],
      name: json['name'],
      refId: json['ref_id'],
      timeScheduled: json['time_scheduled'],
      timePerformed: json['time_performed'],
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
      unit: json['unit'],
      dosage: json['dosage'],
      status: json['status'] ?? 'pending',
      performerId: json['performer_id'],
      notes: json['notes'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  HospitalizationTreatmentModel copyWith({
    String? status,
    String? timePerformed,
    String? performerId,
    String? notes,
  }) {
    return HospitalizationTreatmentModel(
      id: id,
      clinicId: clinicId,
      dailyId: dailyId,
      type: type,
      name: name,
      refId: refId,
      timeScheduled: timeScheduled,
      timePerformed: timePerformed ?? this.timePerformed,
      quantity: quantity,
      unit: unit,
      dosage: dosage,
      status: status ?? this.status,
      performerId: performerId ?? this.performerId,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

class VitalSignLogModel {
  final String id;
  final String? clinicId;
  final String dailyId;
  final String time; // HH:mm
  final double? temperature;
  final double? weight;
  final double? heartRate;
  final double? respiratoryRate;
  final String? crt;
  final String? mucousMembrane;
  final String? faeces;
  final String? urine;
  final String? observerId;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  VitalSignLogModel({
    required this.id,
    this.clinicId,
    required this.dailyId,
    required this.time,
    this.temperature,
    this.weight,
    this.heartRate,
    this.respiratoryRate,
    this.crt,
    this.mucousMembrane,
    this.faeces,
    this.urine,
    this.observerId,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'clinic_id': clinicId,
      'daily_id': dailyId,
      'time': time,
      'temperature': temperature,
      'weight': weight,
      'heart_rate': heartRate,
      'respiratory_rate': respiratoryRate,
      'crt': crt,
      'mucous_membrane': mucousMembrane,
      'faeces': faeces,
      'urine': urine,
      'observer_id': observerId,
      'notes': notes,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  factory VitalSignLogModel.fromJson(Map<String, dynamic> json) {
    return VitalSignLogModel(
      id: json['id'],
      clinicId: json['clinic_id'],
      dailyId: json['daily_id'],
      time: json['time'],
      temperature: (json['temperature'] as num?)?.toDouble(),
      weight: (json['weight'] as num?)?.toDouble(),
      heartRate: (json['heart_rate'] as num?)?.toDouble(),
      respiratoryRate: (json['respiratory_rate'] as num?)?.toDouble(),
      crt: json['crt'],
      mucousMembrane: json['mucous_membrane'],
      faeces: json['faeces'],
      urine: json['urine'],
      observerId: json['observer_id'],
      notes: json['notes'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}

class RegimenModel {
  final String id;
  final String? clinicId;
  final String name;
  final String? description;
  final List<RegimenItem> items;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  RegimenModel({
    required this.id,
    this.clinicId,
    required this.name,
    this.description,
    required this.items,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'clinic_id': clinicId,
      'name': name,
      'description': description,
      'items_json': jsonEncode(items.map((e) => e.toJson()).toList()),
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  factory RegimenModel.fromJson(Map<String, dynamic> json) {
    return RegimenModel(
      id: json['id'],
      clinicId: json['clinic_id'],
      name: json['name'],
      description: json['description'],
      items: json['items_json'] != null
          ? (jsonDecode(json['items_json']) as List)
                .map((e) => RegimenItem.fromJson(e))
                .toList()
          : [],
      isActive: (json['is_active'] as int?) == 1,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}

class RegimenItem {
  final String type; // medicine, service
  final String refId;
  final String name;
  final double quantity;
  final String? unit;
  final String? dosage; // e.g. "10mg/kg BID"
  final String? frequency; // SID, BID, TID, QID, Q4H, Q6H, Q8H, Q12H
  final String? route; // PO, IM, IV, SC, Topical, Rectal, Ophthalmic
  final String? duration; // e.g. "5 ngày", "đến khi hết triệu chứng"
  final int sortOrder; // Priority/order in regimen
  final String?
  category; // antibiotic, antiemetic, fluid, vitamin, gastroprotectant, other
  final String? note;

  RegimenItem({
    required this.type,
    required this.refId,
    required this.name,
    this.quantity = 1.0,
    this.unit,
    this.dosage,
    this.frequency,
    this.route,
    this.duration,
    this.sortOrder = 0,
    this.category,
    this.note,
  });

  /// Parse frequency from dosage string if frequency is not explicitly set
  String? get parsedFrequency {
    if (frequency != null && frequency!.isNotEmpty) return frequency;
    if (dosage == null) return null;
    final upper = dosage!.toUpperCase();
    for (var f in ['QID', 'TID', 'BID', 'SID', 'Q4H', 'Q6H', 'Q8H', 'Q12H']) {
      if (upper.contains(f)) return f;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'ref_id': refId,
    'name': name,
    'quantity': quantity,
    'unit': unit,
    'dosage': dosage,
    'frequency': frequency,
    'route': route,
    'duration': duration,
    'sort_order': sortOrder,
    'category': category,
    'note': note,
  };

  factory RegimenItem.fromJson(Map<String, dynamic> json) => RegimenItem(
    type: json['type'],
    refId: json['ref_id'],
    name: json['name'],
    quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
    unit: json['unit'],
    dosage: json['dosage'],
    frequency: json['frequency'],
    route: json['route'],
    duration: json['duration'],
    sortOrder: (json['sort_order'] as int?) ?? 0,
    category: json['category'],
    note: json['note'],
  );
}
