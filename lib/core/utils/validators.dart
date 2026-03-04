import 'package:get/get.dart';

/// Validation utilities
class Validators {
  Validators._();

  /// Validate required field
  static String? required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'required'.tr;
    }
    return null;
  }

  /// Validate phone number (Vietnamese format)
  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Not required
    }
    final cleaned = value.replaceAll(RegExp(r'[^\d]'), '');
    if (cleaned.length < 9 || cleaned.length > 11) {
      return 'invalid_phone'.tr;
    }
    if (!RegExp(r'^(0|\+84|84)').hasMatch(cleaned) && cleaned.length == 10) {
      // Allow without prefix if 10 digits
      return null;
    }
    return null;
  }

  /// Validate required phone
  static String? requiredPhone(String? value) {
    final reqError = required(value);
    if (reqError != null) return reqError;
    return phone(value);
  }

  /// Validate email
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Not required
    }
    if (!GetUtils.isEmail(value)) {
      return 'invalid_email'.tr;
    }
    return null;
  }

  /// Validate number
  static String? number(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    if (double.tryParse(value) == null) {
      return 'Vui lòng nhập số hợp lệ';
    }
    return null;
  }

  /// Validate positive number
  static String? positiveNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final num = double.tryParse(value);
    if (num == null || num < 0) {
      return 'Vui lòng nhập số dương';
    }
    return null;
  }

  /// Validate temperature (35-42°C for animals)
  static String? temperature(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final temp = double.tryParse(value);
    if (temp == null) {
      return 'Vui lòng nhập nhiệt độ hợp lệ';
    }
    if (temp < 30 || temp > 45) {
      return 'Nhiệt độ nên trong khoảng 30-45°C';
    }
    return null;
  }

  /// Validate weight (0.1 - 200 kg for pets)
  static String? weight(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final weight = double.tryParse(value);
    if (weight == null) {
      return 'Vui lòng nhập cân nặng hợp lệ';
    }
    if (weight <= 0 || weight > 200) {
      return 'Cân nặng nên trong khoảng 0.1-200 kg';
    }
    return null;
  }

  /// Validate age (0-30 years for pets)
  static String? age(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final age = int.tryParse(value);
    if (age == null) {
      return 'Vui lòng nhập tuổi hợp lệ';
    }
    if (age < 0 || age > 30) {
      return 'Tuổi nên trong khoảng 0-30';
    }
    return null;
  }

  /// Validate min length
  static String? Function(String?) minLength(int min) {
    return (String? value) {
      if (value == null || value.trim().isEmpty) {
        return null;
      }
      if (value.length < min) {
        return 'Tối thiểu $min ký tự';
      }
      return null;
    };
  }

  /// Validate max length
  static String? Function(String?) maxLength(int max) {
    return (String? value) {
      if (value == null || value.trim().isEmpty) {
        return null;
      }
      if (value.length > max) {
        return 'Tối đa $max ký tự';
      }
      return null;
    };
  }

  /// Combine multiple validators
  static String? Function(String?) compose(
    List<String? Function(String?)> validators,
  ) {
    return (String? value) {
      for (final validator in validators) {
        final error = validator(value);
        if (error != null) return error;
      }
      return null;
    };
  }
}
