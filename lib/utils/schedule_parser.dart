import 'package:intl/intl.dart';

class ScheduleParser {
  static List<Map<String, DateTime>> extractSchedule(String rawText, String userName) {
    RegExp dateRegex = RegExp(r'\b\d{1,2}-[A-Za-z]{3}-\d{2,4}\b');
    var dateMatches = dateRegex.allMatches(rawText);
    if (dateMatches.length < 7) return [];
    List<String> dates = dateMatches.take(7).map((m) => m.group(0)!).toList();

    int nameIndex = rawText.toLowerCase().indexOf(userName.toLowerCase());
    if (nameIndex == -1) return [];

    String remainingText = rawText.substring(nameIndex + userName.length);
    
    // This regex ONLY looks for exact shift patterns and ignores names like "Burla"
    RegExp shiftRegex = RegExp(
      r'(OFF(?:-R)?|IN(?:-Open)?|(?:1[0-2]|0?[1-9])(?:[:.][0-5][0-9])?\s*[APap][Mm](?:\s*-\s*(?:1[0-2]|0?[1-9])(?:[:.][0-5][0-9])?\s*[APap][Mm])?|(?:1[0-2]|0?[1-9])(?:[:.][0-5][0-9])?\s*[APap][Mm]\s*Open)',
      caseSensitive: false
    );
    
    var shiftMatches = shiftRegex.allMatches(remainingText);
    List<String> shifts = shiftMatches.take(7).map((m) => m.group(0)!).toList();

    if (shifts.isEmpty) return [];

    List<Map<String, DateTime>> allDaysAlarms = [];

    for (int i = 0; i < dates.length && i < shifts.length; i++) {
      String dateStr = dates[i];
      String shiftStr = shifts[i].toUpperCase();

      if (shiftStr == 'OFF' || shiftStr.contains('OFF-R')) continue;

      RegExp timeOnlyRegex = RegExp(r'((?:1[0-2]|0?[1-9])(?:[:.][0-5][0-9])?\s*[AP]M)', caseSensitive: false);
      var timeMatch = timeOnlyRegex.firstMatch(shiftStr);
      if (timeMatch == null) continue;

      String timeStr = timeMatch.group(0)!.toUpperCase();
      timeStr = timeStr.replaceAll('.', ':');
      if (!timeStr.contains(':')) {
        timeStr = timeStr.replaceAllMapped(RegExp(r'(\d+)([AP]M)'), (m) => '${m[1]}:00 ${m[2]}');
      } else {
        timeStr = timeStr.replaceAllMapped(RegExp(r'(\d+:\d+)([AP]M)'), (m) => '${m[1]} ${m[2]}');
      }

      String normalizedDateStr = dateStr;
      List<String> parts = normalizedDateStr.split('-');
      if (parts.length == 3 && parts[2].length == 2) {
        normalizedDateStr = '${parts[0]}-${parts[1]}-20${parts[2]}';
      }

      DateTime? parsedDateTime;
      try {
        parsedDateTime = DateFormat('d-MMM-yyyy h:mm a').parse('$normalizedDateStr $timeStr');
      } catch (e) {
        continue; 
      }

      allDaysAlarms.add({
        'shift_start': parsedDateTime,
        'get_ready': parsedDateTime.subtract(const Duration(minutes: 90)),
        'meal_start': parsedDateTime.add(const Duration(hours: 4)),
        'meal_end': parsedDateTime.add(const Duration(hours: 4, minutes: 30)),
        'shift_end': parsedDateTime.add(const Duration(hours: 8)),
      });
    }

    return allDaysAlarms;
  }
}
