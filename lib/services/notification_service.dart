import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

class NotificationService {
  static Future<void> scheduleShiftAlarms(List<Map<String, DateTime>> allDaysAlarms, String userName) async {
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

          await flutterLocalNotificationsPlugin.zonedSchedule(
            id++,
            'Work Alarm',
            messages[key],
            tzScheduledTime,
            platformChannelSpecifics,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          );
        }
      });
    }
  }

  // NEW: Function to schedule custom notes
  static Future<void> scheduleCustomNote(DateTime scheduledTime, String note) async {
    if (scheduledTime.isAfter(DateTime.now())) {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'custom_notes',
        'Custom Notes',
        channelDescription: 'Your custom notes and alerts',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
      );
      
      const NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);

      tz.TZDateTime tzScheduledTime = tz.TZDateTime.from(scheduledTime, tz.local);
      // Generate a unique ID based on the time
      int uniqueId = scheduledTime.millisecondsSinceEpoch ~/ 1000;

      await flutterLocalNotificationsPlugin.zonedSchedule(
        uniqueId,
        'Custom Alert',
        note,
        tzScheduledTime,
        platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  static Future<void> cancelAllAlarms() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }
}
