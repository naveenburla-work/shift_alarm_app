import 'package:intl/intl.dart';

class ScheduleParser {
  /// Extracts the next upcoming shift from the schedule grid.
  static Map<String, DateTime>? extractSchedule(String rawText, String userName) {
    List<String> lines = rawText.split('\n');
    
    List<String> dates = [];

    // 1. Find the dates line (e.g., "4-Jul-26 5-Jul-26 6-Jul-26...")
    // We look for a line that contains at least 3 dates in this format.
    RegExp dateRegex = RegExp(r'\b\d{1,2}-[A-Za-z]{3}-\d{2,4}\b');
    for (String line in lines) {
      var matches = dateRegex.allMatches(line);
      if (matches.length >= 3) {
        dates = matches.map((m) => m.group(0)!).toList();
        break; // Stop at the first row of dates
      }
    }

    if (dates.isEmpty) return null;

    // 2. Find the user's line
    String? targetLine;
    for (String line in lines) {
      if (line.toLowerCase().contains(userName.toLowerCase())) {
        targetLine = line;
        break;
      }
    }

    if (targetLine == null) return null;

    // 3. Extract all shift blocks from the user's line
    // This regex catches: 11PM-7:30AM, 7AM-3:30PM, 11AM-7.30PM, OFF, 7:30AM Open, etc.
    RegExp shiftRegex = RegExp(
      r'((?:1[0-2]|0?[1-9])(?:[:.][0-5][0-9])?\s*[APap][Mm](?:\s*-\s*(?:1[0-2]|0?[1-9])(?:[:.][0-5][0-9])?\s*[APap][Mm])?|OFF)',
      caseSensitive: false
    );
    
    var shiftMatches = shiftRegex.allMatches(targetLine);
    List<String> shifts = shiftMatches.map((m) => m.group(0)!).toList();

    // 4. Match dates with shifts and find the first UPCOMING shift
    DateTime now = DateTime.now();
    DateTime? shiftStart;

    for (int i = 0; i < dates.length && i < shifts.length; i++) {
      String dateStr = dates[i];
      String shiftStr = shifts[i].toUpperCase();

      // Skip if the person is OFF that day
      if (shiftStr == 'OFF') continue;

      // Extract start time (e.g., "11PM" from "11PM-7:30AM")
      String timeStr = shiftStr.split('-')[0].trim();
      
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
        // Parse "4-Jul-2026 11:00 PM"
        parsedDateTime = DateFormat('d-MMM-yyyy h:mm a').parse('$normalizedDateStr $timeStr');
      } catch (e) {
        continue; // If parsing fails, skip this shift
      }

      // If the shift is today or in the future, use it!
      if (!parsedDateTime.isBefore(now)) {
        shiftStart = parsedDateTime;
        break; // Found the next upcoming shift
      }
    }

    // If all shifts are in the past (e.g., old schedule), just grab the first one so the app doesn't crash
    if (shiftStart == null && shifts.isNotEmpty) {
       // Fallback to first shift if we must
       // (You can remove this fallback if you only want future shifts)
    }

    if (shiftStart == null) return null;

    // 5. Calculate the 5 required timestamps
    return {
      'shift_start': shiftStart,
      'get_ready': shiftStart.subtract(const Duration(minutes: 90)),
      'meal_start': shiftStart.add(const Duration(hours: 4)),
      'meal_end': shiftStart.add(const Duration(hours: 4, minutes: 30)),
      'shift_end': shiftStart.add(const Duration(hours: 8)),
    };
  }
}
