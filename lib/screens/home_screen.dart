import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/schedule_parser.dart';
import '../services/notification_service.dart';
import 'onboarding_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _userName = '';
  bool _isLoading = false;
  Map<String, DateTime>? _parsedSchedule;

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  void _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('userName') ?? 'User';
    });
  }

  void _changeName() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userName');
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const OnboardingScreen()),
      (route) => false,
    );
  }

  Future<void> _pickPdfAndProcess() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result == null) return;

    setState(() => _isLoading = true);

    try {
      final path = result.files.single.path;
      final File file = File(path!);
      final List<int> bytes = await file.readAsBytes();

      final PdfDocument document = PdfDocument(inputBytes: bytes);
      final String text = PdfTextExtractor(document).extractText();
      document.dispose();

      final scheduleData = ScheduleParser.extractSchedule(text, _userName);

      if (scheduleData != null) {
        setState(() {
          _parsedSchedule = scheduleData;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not find your name or shift in the PDF.'),
            backgroundColor: Colors.red[400],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error processing PDF: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _scheduleAlarms() {
    if (_parsedSchedule != null) {
      NotificationService.scheduleShiftAlarms(_parsedSchedule!, _userName);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('All alarms scheduled successfully!'),
          backgroundColor: Colors.green[600],
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _cancelAlarms() async {
    await NotificationService.cancelAllAlarms();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('All alarms have been cancelled.'),
        backgroundColor: Colors.grey[700],
        behavior: SnackBarBehavior.floating,
      ),
    );
    setState(() {
      _parsedSchedule = null;
    });
  }

  // Helper to format the DateTime nicely
  String _formatDate(DateTime dt) {
    String day = dt.day.toString().padLeft(2, '0');
    String month = dt.month.toString().padLeft(2, '0');
    String hour = dt.hour.toString().padLeft(2, '0');
    String minute = dt.minute.toString().padLeft(2, '0');
    return '$day/$month - $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shift Alarm'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, size: 20),
            tooltip: 'Change Name',
            onPressed: _changeName,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  
                  if (_parsedSchedule == null) ...[
                    // Empty State UI
                    const SizedBox(height: 40),
                    Icon(Icons.picture_as_pdf_outlined, size: 80, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'Upload your schedule PDF',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[800]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap the button below to select your weekly schedule. We will automatically find your upcoming shifts.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: _pickPdfAndProcess,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Select PDF File'),
                    ),
                  ] else ...[
                    // Loaded State UI
                    const Text(
                      'Upcoming Shift Details',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
                    ),
                    const SizedBox(height: 16),
                    
                    ..._parsedSchedule!.entries.map((entry) {
                      IconData icon;
                      Color color;
                      String title = entry.key.replaceAll('_', ' ').toUpperCase();
                      
                      if (entry.key == 'get_ready') {
                        icon = Icons.notifications_active;
                        color = Colors.orange;
                      } else if (entry.key == 'shift_start') {
                        icon = Icons.play_circle_fill;
                        color = Colors.green;
                      } else if (entry.key == 'meal_start') {
                        icon = Icons.restaurant;
                        color = Colors.blue;
                      } else if (entry.key == 'meal_end') {
                        icon = Icons.restaurant_menu;
                        color = Colors.purple;
                      } else {
                        icon = Icons.flag;
                        color = Colors.red;
                      }

                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: color.withOpacity(0.1),
                            child: Icon(icon, color: color),
                          ),
                          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text(_formatDate(entry.value), style: const TextStyle(fontSize: 16, color: Color(0xFF4B5563))),
                        ),
                      );
                    }).toList(),

                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _scheduleAlarms,
                      icon: const Icon(Icons.alarm_on),
                      label: const Text('Schedule All Alarms'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _cancelAlarms,
                      style: TextButton.styleFrom(foregroundColor: Colors.red[400]),
                      child: const Text('Cancel All Alarms'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _pickPdfAndProcess,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Upload Different PDF'),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
