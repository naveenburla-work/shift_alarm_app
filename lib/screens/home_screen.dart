import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/schedule_parser.dart';
import '../services/notification_service.dart';

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

  Future<void> _pickImageAndProcess() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image == null) return;

    setState(() => _isLoading = true);

    final InputImage inputImage = InputImage.fromFilePath(image.path);
    final TextRecognizer textRecognizer = TextRecognizer();
    
    try {
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      _rawText = recognizedText.text;

      // Parse the extracted text
      final scheduleData = ScheduleParser.extractSchedule(_rawText, _userName);
      
      if (scheduleData != null) {
        setState(() {
          _parsedSchedule = scheduleData;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not find your name or shift time in the photo.')),
        );
      }
    } catch (e) {
      debugPrint("Error processing image: $e");
    } finally {
      textRecognizer.close();
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
      appBar: AppBar(title: Text('Welcome, $_userName')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickImageAndProcess,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Upload Schedule Photo'),
                  ),
                  const SizedBox(height: 20),
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
