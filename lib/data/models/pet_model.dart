/// Pet model - Thú cưng
class PetModel {
  final String id;
  final String? clinicId;
  final String customerId;
  final String name;
  final String species; // Chó, Mèo, Thỏ, etc.
  final String? breed; // Giống
  @Deprecated('Use dateOfBirth instead')
  final int? age;
  final String? dateOfBirth; // ISO 8601 YYYY-MM-DD
  final String? gender; // Đực, Cái
  final double? weight;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool synced;

  PetModel({
    required this.id,
    this.clinicId,
    required this.customerId,
    required this.name,
    required this.species,
    this.breed,
    this.age,
    this.dateOfBirth,
    this.gender,
    this.weight,
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.synced = false,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory PetModel.fromJson(Map<String, dynamic> json) {
    return PetModel(
      id: json['id'] as String,
      clinicId: json['clinic_id'] as String?,
      customerId: json['customer_id'] as String,
      name: json['name'] as String,
      species: json['species'] as String,
      breed: json['breed'] as String?,
      age: json['age'] as int?,
      dateOfBirth: json['date_of_birth'] as String?,
      gender: json['gender'] as String?,
      weight: json['weight'] != null
          ? (json['weight'] as num).toDouble()
          : null,
      notes: json['notes'] as String?,
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
      'customer_id': customerId,
      'name': name,
      'species': species,
      'breed': breed,
      'age': age,
      'date_of_birth': dateOfBirth,
      'gender': gender,
      'weight': weight,
      'notes': notes,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'synced': synced ? 1 : 0,
    };
  }

  PetModel copyWith({
    String? id,
    String? clinicId,
    String? customerId,
    String? name,
    String? species,
    String? breed,
    int? age,
    String? dateOfBirth,
    String? gender,
    double? weight,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? synced,
  }) {
    return PetModel(
      id: id ?? this.id,
      clinicId: clinicId ?? this.clinicId,
      customerId: customerId ?? this.customerId,
      name: name ?? this.name,
      species: species ?? this.species,
      breed: breed ?? this.breed,
      age: age ?? this.age,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      weight: weight ?? this.weight,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      synced: synced ?? this.synced,
    );
  }

  /// Get species display with icon
  String get speciesDisplay {
    switch (species.toLowerCase()) {
      case 'chó':
      case 'dog':
        return '🐕 $species';
      case 'mèo':
      case 'cat':
        return '🐱 $species';
      case 'thỏ':
        return '🐰 $species';
      case 'hamster':
      case 'chuột':
        return '🐹 $species';
      default:
        return '🐾 $species';
    }
  }

  /// Tính toán và hiển thị tuổi tương đối
  String get displayAge {
    if (dateOfBirth != null && dateOfBirth!.isNotEmpty) {
      try {
        final dob = DateTime.parse(dateOfBirth!);
        final now = DateTime.now();
        var years = now.year - dob.year;
        var months = now.month - dob.month;
        if (months < 0) {
          years--;
          months += 12;
        }

        if (years > 0 && months > 0) {
          return '$years năm $months tháng';
        } else if (years > 0) {
          return '$years tuổi';
        } else if (months > 0) {
          return '$months tháng';
        } else {
          // Under 1 month
          final days = now.difference(dob).inDays;
          return days > 0 ? '$days ngày' : 'Sơ sinh';
        }
      } catch (_) {
        // Fallback if parsing fails
      }
    }
    // Fallback to old "age" integer if existing
    if (age != null) {
      // Assuming legacy integer 'age' was meant as years in the old system or just raw numbers.
      return '$age tuổi';
    }
    return 'Chưa rõ';
  }

  /// Trích xuất nhanh "giá trị số" của tuổi để fill vào Form Input
  String get ageInputValue {
    if (dateOfBirth != null && dateOfBirth!.isNotEmpty) {
      try {
        final dob = DateTime.parse(dateOfBirth!);
        final now = DateTime.now();
        var years = now.year - dob.year;
        var months = now.month - dob.month;
        if (months < 0) {
          years--;
          months += 12;
        }
        if (years > 0) return years.toString();
        if (months > 0) return months.toString();
      } catch (_) {}
    }
    return age?.toString() ?? '';
  }

  /// Trích xuất "đơn vị" của tuổi để fill vào Form Input (Năm/Tháng)
  String get ageInputUnit {
    if (dateOfBirth != null && dateOfBirth!.isNotEmpty) {
      try {
        final dob = DateTime.parse(dateOfBirth!);
        final now = DateTime.now();
        var years = now.year - dob.year;
        var months = now.month - dob.month;
        if (months < 0) {
          years--;
          months += 12;
        }
        if (years > 0) return 'năm';
        return 'tháng';
      } catch (_) {}
    }
    return 'năm'; // default fallback for raw old integer
  }

  @override
  String toString() => 'PetModel(id: $id, name: $name, species: $species)';
}
