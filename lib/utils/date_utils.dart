import 'package:intl/intl.dart';

class DateTimeUtils {
  static const Duration istOffset = Duration(hours: 5, minutes: 30);

  /// Parses a UTC timestamp string from backend, ensuring proper UTC timezone interpretation.
  static DateTime parseUtc(String? dateTimeStr) {
    if (dateTimeStr == null || dateTimeStr.isEmpty) {
      return DateTime.now().toUtc();
    }
    String formatted = dateTimeStr.trim();
    
    // Check if the string already has a timezone indicator (ends with Z, or contains +/- offset after date prefix)
    bool hasTimezone = formatted.endsWith('Z');
    if (!hasTimezone && formatted.length > 10) {
      String timePart = formatted.substring(10);
      if (timePart.contains('+') || timePart.contains('-')) {
        hasTimezone = true;
      }
    }
    
    // If it doesn't specify any timezone details, append 'Z' to force Dart to parse it as UTC time.
    if (!hasTimezone) {
      formatted = '${formatted}Z';
    }
    
    try {
      return DateTime.parse(formatted).toUtc();
    } catch (e) {
      return DateTime.now().toUtc();
    }
  }

  /// Converts any UTC date string or DateTime object directly into IST DateTime (UTC+05:30).
  static DateTime toIST(dynamic dateInput) {
    if (dateInput == null) return DateTime.now().toUtc().add(istOffset);
    DateTime utcDate;
    if (dateInput is DateTime) {
      utcDate = dateInput.toUtc();
    } else if (dateInput is String) {
      utcDate = parseUtc(dateInput);
    } else {
      utcDate = DateTime.now().toUtc();
    }
    return utcDate.add(istOffset);
  }

  /// Formats date to IST string, e.g. '19 Aug 2026, 02:48 PM'
  static String formatIST(dynamic dateInput, {String pattern = 'dd MMM yyyy, hh:mm a', bool withSuffix = false}) {
    if (dateInput == null) return '—';
    try {
      final ist = toIST(dateInput);
      final formatted = DateFormat(pattern).format(ist);
      return withSuffix ? '$formatted IST' : formatted;
    } catch (e) {
      return dateInput.toString();
    }
  }

  /// Formats date-only to IST string, e.g. '19 Aug 2026'
  static String formatISTDateOnly(dynamic dateInput) {
    return formatIST(dateInput, pattern: 'dd MMM yyyy');
  }

  /// Formats time-only to IST string, e.g. '02:48 PM'
  static String formatISTTimeOnly(dynamic dateInput) {
    return formatIST(dateInput, pattern: 'hh:mm a');
  }
}
