import 'dart:convert';
import 'vital_signs_model.dart';
import 'vital_signs_model.dart';

/// Lịch sử ứng tiền nhiều đợt
class AdvancePaymentRecord {
  final double amount;
  final String method;
  final DateTime date;

  AdvancePaymentRecord({
    required this.amount,
    required this.method,
    required this.date,
  });

  factory AdvancePaymentRecord.fromJson(Map<String, dynamic> json) {
    return AdvancePaymentRecord(
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      method: json['method'] as String? ?? 'cash',
      date: json['date'] != null
          ? DateTime.parse(json['date'].toString())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'method': method,
      'date': date.toUtc().toIso8601String(),
    };
  }
}

/// Medical Case model - Ca bệnh/khám
class MedicalCaseModel {
  final String id;
  final String? clinicId;
  final String caseCode; // Mã ca (1323, 1324...)
  final String customerId;
  final String petId;
  final DateTime admissionDate;
  final DateTime? dischargeDate;

  // Step 2: Clinical exam
  final List<String> visitReasons; // Nôn, Mệt, Tai nạn, Sốt...
  final String? reasonNotes;
  final VitalSignsModel? vitalSigns;

  // Step 3: Diagnosis & Treatment
  final String? diagnosis;
  final String prognosis; // good, bad, uncertain
  final String? treatmentPlan;

  // Step 4: Payment
  final double totalEstimate;
  final double advancePayment;
  final String? advancePaymentMethod; // cash, transfer (New v9)
  final List<AdvancePaymentRecord>
  advancePaymentHistory; // Danh sách đợt ứng (New V27)
  final String paymentMethod; // cash, transfer
  final String? customerSignature; // Base64 encoded
  final String? clinicSignature;
  final bool agreeTreatment;
  final bool agreeNoComplaint;

  // Result
  final String status; // active, completed, cancelled
  final String? result; // recovered, not_recovered, died, unknown
  final String? notes;

  final String? staffId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool synced;

  // Display fields (not in DB table)
  final String? staffName;
  final String? petName;
  final String? customerName;
  final String? species;
  final String? phone;
  final String? address;

  MedicalCaseModel({
    required this.id,
    this.clinicId,
    required this.caseCode,
    required this.customerId,
    required this.petId,
    required this.admissionDate,
    this.dischargeDate,
    this.visitReasons = const [],
    this.reasonNotes,
    this.vitalSigns,
    this.diagnosis,
    this.prognosis = 'uncertain',
    this.treatmentPlan,
    this.totalEstimate = 0,
    this.advancePayment = 0,
    this.advancePaymentMethod,
    this.advancePaymentHistory = const [],
    this.paymentMethod = 'cash',
    this.customerSignature,
    this.clinicSignature,
    this.agreeTreatment = false,
    this.agreeNoComplaint = false,
    this.status = 'active',
    this.result,
    this.notes,
    this.staffName,
    this.staffId,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.synced = false,
    this.petName,
    this.customerName,
    this.species,
    this.phone,
    this.address,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory MedicalCaseModel.fromJson(Map<String, dynamic> json) {
    // Parse JSON data safely

    // Parse visit_reasons - could be a List or JSON string
    List<String> visitReasonsList = [];
    if (json['visit_reasons'] != null) {
      final vr = json['visit_reasons'];
      if (vr is List) {
        visitReasonsList = List<String>.from(vr);
      } else if (vr is String && vr.isNotEmpty) {
        try {
          final decoded = jsonDecode(vr);
          if (decoded is List) {
            visitReasonsList = List<String>.from(decoded);
          }
        } catch (_) {
          // If not valid JSON, treat as comma-separated
          visitReasonsList = vr
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
        }
      }
    }

    // Parse vital_signs - could be a Map or JSON string
    VitalSignsModel? vitalSignsModel;
    if (json['vital_signs'] != null) {
      final vs = json['vital_signs'];
      if (vs is Map<String, dynamic>) {
        vitalSignsModel = VitalSignsModel.fromJson(vs);
      } else if (vs is String && vs.isNotEmpty) {
        try {
          final decoded = jsonDecode(vs);
          if (decoded is Map<String, dynamic>) {
            vitalSignsModel = VitalSignsModel.fromJson(decoded);
          }
        } catch (_) {
          // Ignore invalid JSON
        }
      }
    }

    // Parse advance_payment_history
    List<AdvancePaymentRecord> paymentHistory = [];
    if (json['advance_payment_history'] != null) {
      final ph = json['advance_payment_history'];
      if (ph is List) {
        paymentHistory = ph
            .map(
              (e) => AdvancePaymentRecord.fromJson(e as Map<String, dynamic>),
            )
            .toList();
      } else if (ph is String && ph.isNotEmpty) {
        try {
          final decoded = jsonDecode(ph);
          if (decoded is List) {
            paymentHistory = decoded
                .map(
                  (e) =>
                      AdvancePaymentRecord.fromJson(e as Map<String, dynamic>),
                )
                .toList();
          }
        } catch (_) {
          // Ignore parse errors
        }
      }
    }

    return MedicalCaseModel(
      id: json['id'] as String? ?? '',
      clinicId: json['clinic_id'] as String?,
      caseCode: json['case_code'] as String? ?? '',
      customerId: json['customer_id'] as String? ?? '',
      petId: json['pet_id'] as String? ?? '',
      admissionDate: json['admission_date'] != null
          ? DateTime.parse(json['admission_date'].toString())
          : DateTime.now(),
      dischargeDate: json['discharge_date'] != null
          ? DateTime.parse(json['discharge_date'].toString())
          : null,
      visitReasons: visitReasonsList,
      reasonNotes: json['reason_notes'] as String?,
      vitalSigns: vitalSignsModel,
      diagnosis: json['diagnosis'] as String?,
      prognosis: json['prognosis'] as String? ?? 'uncertain',
      treatmentPlan: json['treatment_plan'] as String?,
      totalEstimate: (json['total_estimate'] as num?)?.toDouble() ?? 0,
      advancePayment: (json['advance_payment'] as num?)?.toDouble() ?? 0,
      advancePaymentMethod: json['advance_payment_method'] as String?,
      advancePaymentHistory: paymentHistory,
      paymentMethod: json['payment_method'] as String? ?? 'cash',
      customerSignature: json['customer_signature'] as String?,
      clinicSignature: json['clinic_signature'] as String?,
      agreeTreatment:
          json['agree_treatment'] == 1 || json['agree_treatment'] == true,
      agreeNoComplaint:
          json['agree_no_complaint'] == 1 || json['agree_no_complaint'] == true,
      status: json['status'] as String? ?? 'active',
      result: json['result'] as String?,
      notes: json['notes'] as String?,
      staffId: json['staff_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      synced: json['synced'] == 1 || json['synced'] == true,
      staffName: json['staff_name'] as String?,
      petName: json['pet_name'] as String?,
      customerName: json['customer_name'] as String?,
      species: (json['pet_species'] ?? json['species']) as String?,
      phone: (json['customer_phone'] ?? json['phone']) as String?,
      address: json['address'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'clinic_id': clinicId,
      'case_code': caseCode,
      'customer_id': customerId,
      'customer_name': customerName,
      'customer_phone': phone,
      'pet_id': petId,
      'pet_name': petName,
      'pet_species': species,
      'admission_date': admissionDate.toUtc().toIso8601String(),
      'discharge_date': dischargeDate?.toUtc().toIso8601String(),
      'visit_reasons': jsonEncode(visitReasons),
      'reason_notes': reasonNotes,
      'vital_signs': vitalSigns != null
          ? jsonEncode(vitalSigns!.toJson())
          : null,
      'diagnosis': diagnosis,
      'prognosis': prognosis,
      'treatment_plan': treatmentPlan,
      'total_estimate': totalEstimate,
      'advance_payment': advancePayment,
      'advance_payment_method': advancePaymentMethod,
      if (advancePaymentHistory.isNotEmpty)
        'advance_payment_history': jsonEncode(
          advancePaymentHistory.map((e) => e.toJson()).toList(),
        ),
      'payment_method': paymentMethod,
      'customer_signature': customerSignature,
      'clinic_signature': clinicSignature,
      'agree_treatment': agreeTreatment ? 1 : 0,
      'agree_no_complaint': agreeNoComplaint ? 1 : 0,
      'status': status,
      'result': result,
      'notes': notes,
      'staff_id': staffId,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'synced': synced ? 1 : 0,
    };
  }

  MedicalCaseModel copyWith({
    String? id,
    String? clinicId,
    String? caseCode,
    String? customerId,
    String? staffName,
    String? petId,
    String? staffId,
    DateTime? admissionDate,
    DateTime? dischargeDate,
    List<String>? visitReasons,
    String? reasonNotes,
    VitalSignsModel? vitalSigns,
    String? diagnosis,
    String? prognosis,
    String? treatmentPlan,
    double? totalEstimate,
    double? advancePayment,
    String? advancePaymentMethod,
    List<AdvancePaymentRecord>? advancePaymentHistory,
    String? paymentMethod,
    String? customerSignature,
    String? clinicSignature,
    bool? agreeTreatment,
    bool? agreeNoComplaint,
    String? status,
    String? result,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? synced,
  }) {
    return MedicalCaseModel(
      id: id ?? this.id,
      clinicId: clinicId ?? this.clinicId,
      caseCode: caseCode ?? this.caseCode,

      customerId: customerId ?? this.customerId,
      staffName: staffName ?? this.staffName,
      petId: petId ?? this.petId,
      admissionDate: admissionDate ?? this.admissionDate,
      dischargeDate: dischargeDate ?? this.dischargeDate,
      visitReasons: visitReasons ?? this.visitReasons,
      reasonNotes: reasonNotes ?? this.reasonNotes,
      vitalSigns: vitalSigns ?? this.vitalSigns,
      diagnosis: diagnosis ?? this.diagnosis,
      prognosis: prognosis ?? this.prognosis,
      treatmentPlan: treatmentPlan ?? this.treatmentPlan,
      totalEstimate: totalEstimate ?? this.totalEstimate,
      advancePayment: advancePayment ?? this.advancePayment,
      advancePaymentMethod: advancePaymentMethod ?? this.advancePaymentMethod,
      advancePaymentHistory:
          advancePaymentHistory ?? this.advancePaymentHistory,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      customerSignature: customerSignature ?? this.customerSignature,
      clinicSignature: clinicSignature ?? this.clinicSignature,
      agreeTreatment: agreeTreatment ?? this.agreeTreatment,
      agreeNoComplaint: agreeNoComplaint ?? this.agreeNoComplaint,
      status: status ?? this.status,
      result: result ?? this.result,
      notes: notes ?? this.notes,
      staffId: staffId ?? this.staffId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      synced: synced ?? this.synced,
      petName: petName ?? this.petName,
      customerName: customerName ?? this.customerName,
      species: species ?? this.species,
      phone: phone ?? this.phone,
      address: address ?? this.address,
    );
  }

  /// Get remaining balance
  double get remainingBalance => totalEstimate - advancePayment;

  /// Check if fully paid
  bool get isFullyPaid => advancePayment >= totalEstimate;

  /// Get prognosis color key
  String get prognosisColorKey {
    switch (prognosis) {
      case 'good':
        return 'success';
      case 'bad':
        return 'error';
      default:
        return 'warning';
    }
  }

  @override
  String toString() => 'MedicalCaseModel(id: $id, caseCode: $caseCode)';
}
