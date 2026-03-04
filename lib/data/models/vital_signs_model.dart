/// Vital Signs model - Dấu hiệu sinh tồn
class VitalSignsModel {
  final double? temperature; // Nhiệt độ (°C)
  final double? weight; // Cân nặng (kg)
  final String? digestion; // Tiêu hóa
  final int? vomitingCount; // Số lần nôn
  final String? stoolCondition; // Tình trạng phân
  final String? mentalStatus; // Tình trạng tinh thần
  final String? bodyCondition; // Thể trạng (gầy/trung bình/béo)
  final String? skinMucosa; // Da/Niêm mạc
  final String? otherInfo; // Thông tin khác

  VitalSignsModel({
    this.temperature,
    this.weight,
    this.digestion,
    this.vomitingCount,
    this.stoolCondition,
    this.mentalStatus,
    this.bodyCondition,
    this.skinMucosa,
    this.otherInfo,
  });

  factory VitalSignsModel.fromJson(Map<String, dynamic> json) {
    return VitalSignsModel(
      temperature: json['temperature'] != null
          ? (json['temperature'] as num).toDouble()
          : null,
      weight: json['weight'] != null
          ? (json['weight'] as num).toDouble()
          : null,
      digestion: json['digestion'] as String?,
      vomitingCount: json['vomiting_count'] as int?,
      stoolCondition: json['stool_condition'] as String?,
      mentalStatus: json['mental_status'] as String?,
      bodyCondition: json['body_condition'] as String?,
      skinMucosa: json['skin_mucosa'] as String?,
      otherInfo: json['other_info'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'temperature': temperature,
      'weight': weight,
      'digestion': digestion,
      'vomiting_count': vomitingCount,
      'stool_condition': stoolCondition,
      'mental_status': mentalStatus,
      'body_condition': bodyCondition,
      'skin_mucosa': skinMucosa,
      'other_info': otherInfo,
    };
  }

  VitalSignsModel copyWith({
    double? temperature,
    double? weight,
    String? digestion,
    int? vomitingCount,
    String? stoolCondition,
    String? mentalStatus,
    String? bodyCondition,
    String? skinMucosa,
    String? otherInfo,
  }) {
    return VitalSignsModel(
      temperature: temperature ?? this.temperature,
      weight: weight ?? this.weight,
      digestion: digestion ?? this.digestion,
      vomitingCount: vomitingCount ?? this.vomitingCount,
      stoolCondition: stoolCondition ?? this.stoolCondition,
      mentalStatus: mentalStatus ?? this.mentalStatus,
      bodyCondition: bodyCondition ?? this.bodyCondition,
      skinMucosa: skinMucosa ?? this.skinMucosa,
      otherInfo: otherInfo ?? this.otherInfo,
    );
  }

  /// Check if has fever (temperature > 39.5°C for dogs/cats)
  bool get hasFever => temperature != null && temperature! > 39.5;

  /// Check if has hypothermia (temperature < 37°C)
  bool get hasHypothermia => temperature != null && temperature! < 37.0;

  /// Get temperature status
  String get temperatureStatus {
    if (temperature == null) return 'unknown';
    if (temperature! < 37.0) return 'low';
    if (temperature! > 39.5) return 'high';
    return 'normal';
  }
}

/// Mental status options
class MentalStatusOptions {
  static const String alert = 'Tỉnh táo';
  static const String tired = 'Mệt mỏi';
  static const String depressed = 'Li bì';
  static const String restless = 'Bồn chồn';
  static const String coma = 'Hôn mê';

  static List<String> get all => [alert, tired, depressed, restless, coma];
}

/// Body condition options
class BodyConditionOptions {
  static const String thin = 'Gầy';
  static const String normal = 'Trung bình';
  static const String overweight = 'Béo';

  static List<String> get all => [thin, normal, overweight];
}

/// Stool condition options
class StoolConditionOptions {
  static const String normal = 'Bình thường';
  static const String soft = 'Mềm';
  static const String diarrhea = 'Tiêu chảy';
  static const String bloody = 'Có máu';
  static const String constipation = 'Táo bón';

  static List<String> get all => [normal, soft, diarrhea, bloody, constipation];
}
