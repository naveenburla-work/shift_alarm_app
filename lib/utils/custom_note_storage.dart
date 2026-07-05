import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

class CustomNote {
  final String id;
  final String text;
  final DateTime alertTime;
  bool isCompleted;

  CustomNote({
    required this.id,
    required this.text,
    required this.alertTime,
    this.isCompleted = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'alertTime': alertTime.toIso8601String(),
        'isCompleted': isCompleted,
      };

  factory CustomNote.fromJson(Map<String, dynamic> json) => CustomNote(
        id: json['id'],
        text: json['text'],
        alertTime: DateTime.parse(json['alertTime']),
        isCompleted: json['isCompleted'],
      );
}

class NoteStorage {
  static Future<File> _getFile(bool isComplete) async {
    final directory = await getApplicationDocumentsDirectory();
    String filename = isComplete ? 'complete_notes.json' : 'non_complete_notes.json';
    return File('${directory.path}/$filename');
  }

  static Future<List<CustomNote>> readNotes(bool isComplete) async {
    try {
      final file = await _getFile(isComplete);
      if (!await file.exists()) return [];
      String contents = await file.readAsString();
      List<dynamic> json = jsonDecode(contents);
      return json.map((e) => CustomNote.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> writeNotes(List<CustomNote> notes, bool isComplete) async {
    final file = await _getFile(isComplete);
    await file.writeAsString(jsonEncode(notes.map((e) => e.toJson()).toList()));
  }
}
