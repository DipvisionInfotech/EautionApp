class DateTimeUtils {
  static DateTime parseUtc(String? dateTimeStr) {
    if (dateTimeStr == null || dateTimeStr.isEmpty) {
      return DateTime.now();
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
      return DateTime.parse(formatted).toLocal();
    } catch (e) {
      return DateTime.now();
    }
  }
}
