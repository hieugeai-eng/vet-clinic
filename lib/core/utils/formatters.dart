import 'package:intl/intl.dart';

/// Formatting utilities
class Formatters {
  Formatters._();

  // Date formatters
  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  static final DateFormat _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');
  static final DateFormat _timeFormat = DateFormat('HH:mm');
  static final DateFormat _monthYearFormat = DateFormat('MM/yyyy');
  static final DateFormat _fullDateFormat = DateFormat(
    'EEEE, dd MMMM yyyy',
    'vi',
  );

  /// Format date to dd/MM/yyyy
  static String formatDate(DateTime? date) {
    if (date == null) return '';
    return _dateFormat.format(date);
  }

  /// Format datetime to dd/MM/yyyy HH:mm
  static String formatDateTime(DateTime? date) {
    if (date == null) return '';
    return _dateTimeFormat.format(date);
  }

  /// Format time to HH:mm
  static String formatTime(DateTime? date) {
    if (date == null) return '';
    return _timeFormat.format(date);
  }

  /// Format to month/year
  static String formatMonthYear(DateTime? date) {
    if (date == null) return '';
    return _monthYearFormat.format(date);
  }

  /// Format to full date (Vietnamese)
  static String formatFullDate(DateTime? date) {
    if (date == null) return '';
    return _fullDateFormat.format(date);
  }

  /// Parse date from dd/MM/yyyy string
  static DateTime? parseDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;
    try {
      return _dateFormat.parse(dateStr);
    } catch (e) {
      return null;
    }
  }

  /// Format currency (VND)
  static String formatCurrency(num? amount) {
    if (amount == null) return '0 đ';
    final formatter = NumberFormat('#,###', 'vi');
    return '${formatter.format(amount)} đ';
  }

  /// Format currency without symbol (Short)
  static String formatCurrencyShort(num? amount) {
    if (amount == null) return '0';
    if (amount >= 1000000000) {
      return '${(amount / 1000000000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}T';
    } else if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}K';
    }
    final formatter = NumberFormat('#,###', 'vi');
    return formatter.format(amount);
  }

  /// Format currency without symbol
  static String formatNumber(num? amount) {
    if (amount == null) return '0';
    final formatter = NumberFormat('#,###', 'vi');
    return formatter.format(amount);
  }

  /// Parse currency string to number
  static num? parseCurrency(String? currencyStr) {
    if (currencyStr == null || currencyStr.isEmpty) return null;
    try {
      final cleaned = currencyStr.replaceAll(RegExp(r'[^\d]'), '');
      return num.parse(cleaned);
    } catch (e) {
      return null;
    }
  }

  /// Format phone number (0123 456 789)
  static String formatPhone(String? phone) {
    if (phone == null || phone.isEmpty) return '';
    final cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (cleaned.length == 10) {
      return '${cleaned.substring(0, 4)} ${cleaned.substring(4, 7)} ${cleaned.substring(7)}';
    }
    if (cleaned.length == 11) {
      return '${cleaned.substring(0, 4)} ${cleaned.substring(4, 7)} ${cleaned.substring(7)}';
    }
    return phone;
  }

  /// Format weight (kg)
  static String formatWeight(num? weight) {
    if (weight == null) return '';
    return '${weight.toStringAsFixed(1)} kg';
  }

  /// Format temperature (°C)
  static String formatTemperature(num? temp) {
    if (temp == null) return '';
    return '${temp.toStringAsFixed(1)} °C';
  }

  /// Format percentage
  static String formatPercent(num? value) {
    if (value == null) return '0%';
    return '${value.toStringAsFixed(1)}%';
  }

  /// Truncate text with ellipsis
  static String truncate(String? text, int maxLength) {
    if (text == null || text.isEmpty) return '';
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
}
