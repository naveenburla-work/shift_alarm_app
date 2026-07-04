import 'package:intl/intl.dart';

class ScheduleParser {
  /// Extracts the schedule start time based on the user's name.
  static Map<String, DateTime>? extractSchedule(String rawText, String userName) {
    // Split text into lines to find the name and adjacent time
    List<String> lines = rawText.split('\n');
    
    String? foundDateStr;
    String? foundTimeStr;

    // Regex to match Date (e.g., 10/25/2023, 2023-10-25, Oct 25)
    RegExp dateRegex = RegExp(r'(\d{1,2}[/-]\d{1,2}[/-]\d{2,4}|\d{4}[/-]\d{1,2}[/-]\d{1,2})');
    // Regex to match Time (e.g., 9:00 AM, 14:00)
    RegExp timeRegex = RegExp(r'\b((1[0-2]|0?[1-9]):([0-5][0-9])\s?([APap][Mm])|([01]?[0-9]|2[0-3]):([0-5][0-9]))\b');

    // 1. Find the line containing the user's name (Case Insensitive)
    for (String line in lines) {
      if (line.toLowerCase().contains(userName.toLowerCase())) {
        // 2. Find Date and Time on this line, or nearby lines
        var dateMatch = dateRegex.firstMatch(rawText);
        var timeMatch = timeRegex.firstMatch(line);
        
        if (timeMatch == null) {
           // If not on same line, check the next line
           int currentIndex = lines.indexOf(line);
           if (currentIndex + 1 < lines.length) {
               timeMatch = timeRegex.firstMatch(lines[currentIndex + 1]);
           }
        }

        if (timeMatch != null) {
          foundTimeStr = timeMatch.group(0);
          if (dateMatch != null) {
            foundDateStr = dateMatch.group(0);
          }
          break;
        }
      }
    }

    if (foundTimeStr == null) return null;

    // 3. Parse into DateTime object
    // If no date found, assume today. (User can upgrade this logic later)
    DateTime today = DateTime.now();
    String dateString = foundDateStr ?? '${today.year}-${today.month}-${today.day}';
    
    // Normalize time string for parsing (e.g., 9:00 AM -> 09:00 AM)
    String timeString = foundTimeStr.toUpperCase();
    
    // Try parsing different formats
    List<String> formats = [
      'yyyy-MM-dd h:mm a',
      'yyyy-MM-dd HH:mm',
      'MM/dd/yyyy h:mm a',
      'MM/dd/yyyy HH:mm',
      'M/d/yyyy h:mm a',
    ];

    DateTime? shiftStart;
    for (String fmt in formats) {
      try {
        shiftStart = DateFormat(fmt).parse('$dateString $timeString');
        break;
      } catch (_) {}
    }

    if (shiftStart == null) return null;

    // 4. Calculate the 5 required timestamps
    return {
      'shift_start': shiftStart,
      'get_ready': shiftStart.subtract(const Duration(minutes: 90)),
      'meal_start': shiftStart.add(const Duration(hours: 4)),
      'meal_end': shiftStart.add(const Duration(hours: 4, minutes: 30)),
      'shift_end': shiftStart.add(const Duration(hours: 8)),
    };
  }
}
