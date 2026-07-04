import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

class NotificationService {
  static Future<void> scheduleShiftAlarms(Map<String, DateTime> alarms, String userName) async {
    // Clear previous alarms to avoid duplicates
    await flutterLocalNotificationsPlugin.cancelAll();

    Map<String, String> messages = {
      'get_ready': "Hey $userName, your shift starts in 1 hour 30 minutes.",
      'shift_start': "Hey $userName, your shift is started.",
      'meal_start': "Hey $userName, it is time for your meal break.",
      'meal_end': "Hey $userName, your meal break has ended.",
      'shift_end': "Hey $userName, your shift has ended.",
    };

    alarms.forEach((key, scheduledTime) async {
      // Only schedule alarms that are in the future
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

        // Convert DateTime to TZDateTime
        tz.TZDateTime tzScheduledTime = tz.TZDateTime.from(scheduledTime, tz.local);

        await flutterLocalNotificationsPlugin.zonedSchedule(
          key.hashCode, // Unique ID
          'Work Alarm',
          messages[key], // The message text
          tzScheduledTime,
          platformChannelSpecifics,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    });
  }
}
