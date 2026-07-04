import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // Fixed capital N
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz; // Added for scheduling
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';
import 'services/notification_service.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Timezones for scheduling
  tz.initializeTimeZones();

  // Initialize Notifications
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings();
  const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid, iOS: initializationSettingsIOS);
  
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // Check if user name exists
  final prefs = await SharedPreferences.getInstance();
  final String? userName = prefs.getString('userName');

  runApp(MyApp(hasName: userName != null));
}

class MyApp extends StatelessWidget {
  final bool hasName;
  const MyApp({super.key, required this.hasName});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shift Alarm App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: hasName ? const HomeScreen() : const OnboardingScreen(),
    );
  }
}
