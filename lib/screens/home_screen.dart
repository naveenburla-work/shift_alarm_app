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
  String _rawText = '';

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

      setState(() {
        _rawText = text;
      });

      final scheduleData = ScheduleParser.extractSchedule(_rawText, _userName);

      if (scheduleData != null) {
        setState(() {
          _parsedSchedule = scheduleData;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not find name or shift. Check the RED text below.')),
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
        const SnackBar(content: Text('All alarms scheduled successfully!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, $_userName'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Change Name',
            onPressed: _changeName,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickPdfAndProcess,
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Upload Schedule PDF'),
                  ),
                  const SizedBox(height: 20),
                  
                  if (_rawText.isNotEmpty) ...[
                    const Text('RAW TEXT READ FROM PDF:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                    Container(
                      padding: const EdgeInsets.all(8),
                      color: Colors.grey[200],
                      child: Text(_rawText, style: const TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(height: 20),
                  ],

                  if (_parsedSchedule != null) ...[
                    const Text('Detected Schedule:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    ..._parsedSchedule!.entries.map((entry) => ListTile(
                      title: Text(entry.key.replaceAll('_', ' ').toUpperCase()),
                      subtitle: Text(entry.value.toString()),
                    )).toList(),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _scheduleAlarms,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      child: const Text('Schedule All Alarms'),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
