class TreatmentDayModel {
  final String id;
  final String hospitalizationId;
  final DateTime date;
  final String? notes;

  TreatmentDayModel({
    required this.id,
    required this.hospitalizationId,
    required this.date,
    this.notes,
  });

  factory TreatmentDayModel.fromJson(Map<String, dynamic> json) {
    return TreatmentDayModel(
      id: json['id'],
      hospitalizationId: json['hospitalization_id'],
      date: DateTime.parse(json['date']),
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'hospitalization_id': hospitalizationId,
      'date': date.toUtc().toIso8601String(),
      'notes': notes,
    };
  }
}

class TreatmentActivityModel {
  final String id;
  final String dayId;
  final String type; // vital, medication, physiology, service
  final String name;
  final String value;
  final String time; // HH:mm
  final String? performerId;

  TreatmentActivityModel({
    required this.id,
    required this.dayId,
    required this.type,
    required this.name,
    required this.value,
    required this.time,
    this.performerId,
  });

  factory TreatmentActivityModel.fromJson(Map<String, dynamic> json) {
    return TreatmentActivityModel(
      id: json['id'],
      dayId: json['day_id'],
      type: json['type'],
      name: json['name'],
      value: json['value'],
      time: json['time'],
      performerId: json['performer_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'day_id': dayId,
      'type': type,
      'name': name,
      'value': value,
      'time': time,
      'performer_id': performerId,
    };
  }
}
