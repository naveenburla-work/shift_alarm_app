import 'dart:convert';
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
  List<Map<String, DateTime>> _allDaysAlarms = [];
  List<Map<String, dynamic>> _customNotes = []; // List for custom notes

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('userName') ?? 'User';
    });
    
    final String? savedAlarms = prefs.getString('savedAlarms');
    if (savedAlarms != null) {
      List<dynamic> decoded = jsonDecode(savedAlarms);
      setState(() {
        _allDaysAlarms = decoded.map((day) => 
          (day as Map<String, dynamic>).map((k, v) => MapEntry(k, DateTime.parse(v)))
        ).toList();
      });
    }

    // Load saved custom notes
    final String? savedNotes = prefs.getString('customNotes');
    if (savedNotes != null) {
      List<dynamic> decodedNotes = jsonDecode(savedNotes);
      setState(() {
        _customNotes = decodedNotes.map((n) => {
          'datetime': DateTime.parse(n['datetime']),
          'text': n['text']
        }).toList();
      });
    }
  }

  void _changeName() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userName');
    await prefs.remove('savedAlarms');
    await prefs.remove('customNotes');
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

      final scheduleDataList = ScheduleParser.extractSchedule(text, _userName);

      if (scheduleDataList.isNotEmpty) {
        setState(() {
          _allDaysAlarms = scheduleDataList;
        });
        
        final prefs = await SharedPreferences.getInstance();
        String encoded = jsonEncode(_allDaysAlarms.map((m) => m.map((k, v) => MapEntry(k, v.toIso8601String()))).toList());
        await prefs.setString('savedAlarms', encoded);
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

  void _scheduleAlarms() async {
    if (_allDaysAlarms.isNotEmpty) {
      await NotificationService.scheduleShiftAlarms(_allDaysAlarms, _userName);
      
      // Schedule all custom notes too
      for (var note in _customNotes) {
        await NotificationService.scheduleCustomNote(note['datetime'], note['text']);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('All shift alarms and notes scheduled!'),
          backgroundColor: Colors.green[600],
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _cancelAlarms() async {
    await NotificationService.cancelAllAlarms();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('savedAlarms');
    await prefs.remove('customNotes');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('All alarms and notes have been cancelled.'),
        backgroundColor: Colors.grey[700],
        behavior: SnackBarBehavior.floating,
      ),
    );
    setState(() {
      _allDaysAlarms.clear();
      _customNotes.clear();
    });
  }

  // Function to add a custom note
  void _addCustomNote(DateTime shiftDate) async {
    TimeOfDay? selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (selectedTime == null) return; // User cancelled time picker

    TextEditingController noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Custom Note'),
          content: TextField(
            controller: noteController,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'e.g. Bring extra uniforms'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (noteController.text.trim().isEmpty) return;
                
                DateTime alertTime = DateTime(
                  shiftDate.year,
                  shiftDate.month,
                  shiftDate.day,
                  selectedTime.hour,
                  selectedTime.minute,
                );

                setState(() {
                  _customNotes.add({
                    'datetime': alertTime,
                    'text': noteController.text.trim(),
                  });
                });

                _saveCustomNotes();
                Navigator.pop(context);
              },
              child: const Text('Save Note'),
            )
          ],
        );
      },
    );
  }

  void _saveCustomNotes() async {
    final prefs = await SharedPreferences.getInstance();
    String encoded = jsonEncode(_customNotes.map((n) => {
      'datetime': (n['datetime'] as DateTime).toIso8601String(),
      'text': n['text']
    }).toList());
    await prefs.setString('customNotes', encoded);
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} - ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
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
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  
                  if (_allDaysAlarms.isEmpty) ...[
                    const SizedBox(height: 40),
                    Icon(Icons.picture_as_pdf_outlined, size: 80, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text('Upload your schedule PDF', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[800])),
                    const SizedBox(height: 8),
                    Text('Tap the button below to select your weekly schedule.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: _pickPdfAndProcess,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Select PDF File'),
                    ),
                  ] else ...[
                    ElevatedButton.icon(
                      onPressed: _pickPdfAndProcess,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Upload New PDF'),
                    ),
                    const SizedBox(height: 16),

                    ..._allDaysAlarms.map((dayAlarms) {
                      DateTime shiftStart = dayAlarms['shift_start']!;
                      
                      // Find custom notes for this specific day
                      var dayNotes = _customNotes.where((n) {
                        DateTime dt = n['datetime'] as DateTime;
                        return dt.day == shiftStart.day && dt.month == shiftStart.month && dt.year == shiftStart.year;
                      }).toList();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 16, bottom: 8),
                            child: Text(
                              '${shiftStart.day}/${shiftStart.month}/${shiftStart.year}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                            ),
                          ),
                          ...dayAlarms.entries.map((entry) {
                            IconData icon;
                            Color color;
                            String note = '';
                            String title = entry.key.replaceAll('_', ' ').toUpperCase();
                            
                            if (entry.key == 'get_ready') {
                              icon = Icons.notifications_active;
                              color = Colors.orange;
                              note = "Shift starts in 1hr 30min";
                            } else if (entry.key == 'shift_start') {
                              icon = Icons.play_circle_fill;
                              color = Colors.green;
                              note = "Shift is started";
                            } else if (entry.key == 'meal_start') {
                              icon = Icons.restaurant;
                              color = Colors.blue;
                              note = "Meal break";
                            } else if (entry.key == 'meal_end') {
                              icon = Icons.restaurant_menu;
                              color = Colors.purple;
                              note = "Meal break ended";
                            } else {
                              icon = Icons.flag;
                              color = Colors.red;
                              note = "Shift ended";
                            }

                            return Card(
                              child: ListTile(
                                leading: CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)),
                                title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                subtitle: Text("${_formatDate(entry.value)}\nNote: $note", style: const TextStyle(fontSize: 14, color: Color(0xFF4B5563))),
                                isThreeLine: true,
                              ),
                            );
                          }).toList(),

                          // Display Custom Notes for this day
                          ...dayNotes.map((customNote) {
                            return Card(
                              color: const Color(0xFFFFF8E1), // Light amber background for notes
                              child: ListTile(
                                leading: const CircleAvatar(backgroundColor: Color(0xFFFFECB3), child: Icon(Icons.sticky_note_2, color: Colors.amber)),
                                title: Text(customNote['text'], style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text("Alert at: ${_formatDate(customNote['datetime'])}"),
                              ),
                            );
                          }).toList(),

                          // Button to add custom note
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () => _addCustomNote(shiftStart),
                              icon: const Icon(Icons.note_add, size: 18),
                              label: const Text('Add Note for this Day'),
                            ),
                          ),
                        ],
                      );
                    }).toList(),

                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _scheduleAlarms,
                      icon: const Icon(Icons.alarm_on),
                      label: const Text('Schedule All Alarms & Notes'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _cancelAlarms,
                      style: TextButton.styleFrom(foregroundColor: Colors.red[400]),
                      child: const Text('Cancel & Clear Everything'),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
