import 'package:intl/intl.dart';

class ScheduleParser {
  static Map<String, DateTime>? extractSchedule(String rawText, String userName) {
    // 1. Find the first 7 dates in the format 4-Jul-26
    RegExp dateRegex = RegExp(r'\b\d{1,2}-[A-Za-z]{3}-\d{2,4}\b');
    var dateMatches = dateRegex.allMatches(rawText);
    if (dateMatches.length < 7) return null;
    List<String> dates = dateMatches.take(7).map((m) => m.group(0)!).toList();

    // 2. Find the user's name
    int nameIndex = rawText.toLowerCase().indexOf(userName.toLowerCase());
    if (nameIndex == -1) return null;

    // 3. Extract everything AFTER the user's name
    String remainingText = rawText.substring(nameIndex + userName.length);

    // 4. Find the next 7 shift blocks. 
    // We use [^\s]+ to grab any continuous block of text that isn't a space (catches 11PM-7:30AM, OFF, IN-Open, etc.)
    RegExp shiftRegex = RegExp(r'[^\s]+');
    var shiftMatches = shiftRegex.allMatches(remainingText);
    List<String> shifts = shiftMatches.take(7).map((m) => m.group(0)!).toList();

    if (shifts.isEmpty) return null;

    DateTime now = DateTime.now();
    DateTime? shiftStart;

    // 5. Match dates with shifts to find the next upcoming shift
    for (int i = 0; i < dates.length && i < shifts.length; i++) {
      String dateStr = dates[i];
      String shiftStr = shifts[i].toUpperCase();

      // Skip if the shift is OFF
      if (shiftStr == 'OFF' || shiftStr.contains('OFF-R')) continue;

      // Extract start time (e.g., "11PM" from "11PM-7:30AM")
      // This regex is much smarter and handles weird dashes (–) or dots (.)
      RegExp timeOnlyRegex = RegExp(r'((?:1[0-2]|0?[1-9])(?:[:.][0-5][0-9])?\s*[AP]M)', caseSensitive: false);
      var timeMatch = timeOnlyRegex.firstMatch(shiftStr);
      if (timeMatch == null) continue; // If there's no time (like "IN"), skip to the next day

      String timeStr = timeMatch.group(0)!.toUpperCase();
      
      // Normalize time string (e.g., "7.30AM" -> "7:30 AM", "11PM" -> "11:00 PM")
      timeStr = timeStr.replaceAll('.', ':');
      if (!timeStr.contains(':')) {
        timeStr = timeStr.replaceAllMapped(RegExp(r'(\d+)([AP]M)'), (m) => '${m[1]}:00 ${m[2]}');
      } else {
        timeStr = timeStr.replaceAllMapped(RegExp(r'(\d+:\d+)([AP]M)'), (m) => '${m[1]} ${m[2]}');
      }

      // Normalize Date string (e.g., "4-Jul-26" -> "4-Jul-2026")
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

      // If the shift is today or in the future, use it!
      if (!parsedDateTime.isBefore(now)) {
        shiftStart = parsedDateTime;
        break; 
      }
    }

    if (shiftStart == null) return null;

    return {
      'shift_start': shiftStart,
      'get_ready': shiftStart.subtract(const Duration(minutes: 90)),
      'meal_start': shiftStart.add(const Duration(hours: 4)),
      'meal_end': shiftStart.add(const Duration(hours: 4, minutes: 30)),
      'shift_end': shiftStart.add(const Duration(hours: 8)),
    };
  }
}
