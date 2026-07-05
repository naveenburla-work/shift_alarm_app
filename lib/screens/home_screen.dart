import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/schedule_parser.dart';
import '../utils/custom_note_storage.dart';
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
  List<CustomNote> _completeNotes = [];
  List<CustomNote> _nonCompleteNotes = [];

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

    List<CustomNote> complete = await NoteStorage.readNotes(true);
    List<CustomNote> nonComplete = await NoteStorage.readNotes(false);
    
    // Auto-move expired non-complete notes to complete file if date passed
    DateTime todayMidnight = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    List<CustomNote> stillNonComplete = [];
    for (var note in nonComplete) {
      if (note.alertTime.isBefore(todayMidnight)) {
        complete.add(note);
      } else {
        stillNonComplete.add(note);
      }
    }

    setState(() {
      _completeNotes = complete;
      _nonCompleteNotes = stillNonComplete;
    });

    await NoteStorage.writeNotes(_completeNotes, true);
    await NoteStorage.writeNotes(_nonCompleteNotes, false);
  }

  void _changeName() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userName');
    await prefs.remove('savedAlarms');
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('All shift alarms scheduled successfully!'),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('All alarms have been cancelled.'),
        backgroundColor: Colors.grey[700],
        behavior: SnackBarBehavior.floating,
      ),
    );
    setState(() {
      _allDaysAlarms.clear();
    });
  }

  void _editAlarm(int dayIndex, String alarmKey, DateTime originalTime) async {
    TimeOfDay? selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(originalTime),
    );

    if (selectedTime == null) return;

    DateTime newTime = DateTime(
      originalTime.year,
      originalTime.month,
      originalTime.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    setState(() {
      _allDaysAlarms[dayIndex][alarmKey] = newTime;
    });

    final prefs = await SharedPreferences.getInstance();
    String encoded = jsonEncode(_allDaysAlarms.map((m) => m.map((k, v) => MapEntry(k, v.toIso8601String()))).toList());
    await prefs.setString('savedAlarms', encoded);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Alarm time updated! Tap Schedule to apply.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _createCustomNoteAlert() async {
    DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (selectedDate == null) return;

    TimeOfDay? selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (selectedTime == null) return;

    TextEditingController noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enter Your Note'),
          content: TextField(
            controller: noteController,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'e.g. Meeting with manager'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (noteController.text.trim().isEmpty) return;
                
                DateTime alertTime = DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                  selectedTime.hour,
                  selectedTime.minute,
                );

                String noteId = DateTime.now().millisecondsSinceEpoch.toString();

                CustomNote newNote = CustomNote(
                  id: noteId,
                  text: noteController.text.trim(),
                  alertTime: alertTime,
                );

                setState(() {
                  _nonCompleteNotes.add(newNote);
                });

                await NoteStorage.writeNotes(_nonCompleteNotes, false);
                await NotificationService.scheduleCustomNote(alertTime, newNote.text, noteId);

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Custom note alert scheduled! It will ring at the set time.'),
                    backgroundColor: Colors.green[600],
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text('Schedule Alert'),
            )
          ],
        );
      },
    );
  }

  void _markNoteComplete(int index) async {
    CustomNote note = _nonCompleteNotes[index];
    note.isCompleted = true;
    
    setState(() {
      _nonCompleteNotes.removeAt(index);
      _completeNotes.add(note);
    });

    await NoteStorage.writeNotes(_nonCompleteNotes, false);
    await NoteStorage.writeNotes(_completeNotes, true);
  }

  void _deleteNote(bool isComplete, int index) async {
    setState(() {
      if (isComplete) {
        _completeNotes.removeAt(index);
      } else {
        _nonCompleteNotes.removeAt(index);
      }
    });

    await NoteStorage.writeNotes(_completeNotes, true);
    await NoteStorage.writeNotes(_nonCompleteNotes, false);
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
                  
                  OutlinedButton.icon(
                    onPressed: _createCustomNoteAlert,
                    icon: const Icon(Icons.note_add, color: Colors.amber),
                    label: const Text('Create Custom Note Alert', style: TextStyle(color: Colors.amber)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.amber),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // DISPLAY NON-COMPLETE NOTES (RED)
                  if (_nonCompleteNotes.isNotEmpty) ...[
                    const Text("Non-Complete Notes", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
                    const SizedBox(height: 8),
                    ..._nonCompleteNotes.asMap().entries.map((entry) {
                      int idx = entry.key;
                      CustomNote note = entry.value;
                      
                      return Card(
                        color: Colors.red[50],
                        child: ListTile(
                          title: Text("(not complete)", style: TextStyle(color: Colors.red[800], fontWeight: FontWeight.bold)),
                          subtitle: Text("Scheduled: ${_formatDate(note.alertTime)}", style: TextStyle(color: Colors.red[800]?.withOpacity(0.8))),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.check_circle, color: Colors.green),
                                onPressed: () => _markNoteComplete(idx),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red[800]),
                                onPressed: () => _deleteNote(false, idx),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                    const SizedBox(height: 16),
                  ],

                  // DISPLAY COMPLETE NOTES (GREEN)
                  if (_completeNotes.isNotEmpty) ...[
                    const Text("Complete Notes", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                    const SizedBox(height: 8),
                    ..._completeNotes.asMap().entries.map((entry) {
                      int idx = entry.key;
                      CustomNote note = entry.value;
                      
                      return Card(
                        color: Colors.green[50],
                        child: ListTile(
                          title: Text("(complete)", style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.bold)),
                          subtitle: Text("Was scheduled: ${_formatDate(note.alertTime)}", style: TextStyle(color: Colors.green[800]?.withOpacity(0.8))),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.green[800]),
                            onPressed: () => _deleteNote(true, idx),
                          ),
                        ),
                      );
                    }).toList(),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                  ],

                  if (_allDaysAlarms.isEmpty) ...[
                    const SizedBox(height: 20),
                    Icon(Icons.picture_as_pdf_outlined, size: 80, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text('Upload your schedule PDF', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[800])),
                    const SizedBox(height: 8),
                    Text('Tap the button below to select your weekly schedule. This app is 100% offline.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
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

                    ..._allDaysAlarms.asMap().entries.map((dayEntry) {
                      int dayIndex = dayEntry.key;
                      Map<String, DateTime> dayAlarms = dayEntry.value;
                      DateTime shiftStart = dayAlarms['shift_start']!;

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
                                onTap: () => _editAlarm(dayIndex, entry.key, entry.value),
                                leading: CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)),
                                title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                subtitle: Text("${_formatDate(entry.value)}\nNote: $note", style: const TextStyle(fontSize: 14, color: Color(0xFF4B5563))),
                                isThreeLine: true,
                                trailing: const Icon(Icons.edit, size: 18, color: Colors.grey),
                              ),
                            );
                          }).toList(),
                        ],
                      );
                    }).toList(),

                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _scheduleAlarms,
                      icon: const Icon(Icons.alarm_on),
                      label: const Text('Schedule All Shift Alarms'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _cancelAlarms,
                      style: TextButton.styleFrom(foregroundColor: Colors.red[400]),
                      child: const Text('Cancel & Clear All Alarms'),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
