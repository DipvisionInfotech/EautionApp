class DateTimeUtils {
  static DateTime parseUtc(String? dateTimeStr) {
    if (dateTimeStr == null || dateTimeStr.isEmpty) {
      return DateTime.now();
    }
    String formatted = dateTimeStr.trim();
    // If it doesn't specify any timezone details (Z or +00:00 or -00:00),
    // append 'Z' to force Dart to parse it as UTC time.
    if (!formatted.endsWith('Z') && 
        !formatted.contains('+') && 
        !formatted.contains('-')) {
      formatted = '${formatted}Z';
    }
    try {
      return DateTime.parse(formatted).toLocal();
    } catch (e) {
      return DateTime.now();
    }
  }
}
