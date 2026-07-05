import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

class NotificationService {
  static Future<void> scheduleShiftAlarms(List<Map<String, DateTime>> allDaysAlarms, String userName, String customNote) async {
    await flutterLocalNotificationsPlugin.cancelAll();

    Map<String, String> messages = {
      'get_ready': "Hey $userName, your shift starts in 1 hour 30 minutes.",
      'shift_start': "Hey $userName, your shift is started.",
      'meal_start': "Hey $userName, it is time for your meal break.",
      'meal_end': "Hey $userName, your meal break has ended.",
      'shift_end': "Hey $userName, your shift has ended.",
    };

    int id = 0;

    for (var dayAlarms in allDaysAlarms) {
      dayAlarms.forEach((key, scheduledTime) async {
        if (scheduledTime.isAfter(DateTime.now())) {
          
          const AndroidNotificationDetails androidPlatformChannelSpecifics =
              AndroidNotificationDetails(
            'shift_alarms',
            'Shift Alarms',
            channelDescription: 'Alarms for work shifts',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
          );
          
          const NotificationDetails platformChannelSpecifics =
              NotificationDetails(android: androidPlatformChannelSpecifics);

          tz.TZDateTime tzScheduledTime = tz.TZDateTime.from(scheduledTime, tz.local);

          // Add the custom note to the message if it's not empty
          String finalMessage = messages[key]!;
          if (customNote.trim().isNotEmpty) {
            finalMessage += "\nNote: $customNote";
          }

          await flutterLocalNotificationsPlugin.zonedSchedule(
            id++,
            'Work Alarm',
            finalMessage,
            tzScheduledTime,
            platformChannelSpecifics,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          );
        }
      });
    }
  }

  static Future<void> cancelAllAlarms() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }
}
