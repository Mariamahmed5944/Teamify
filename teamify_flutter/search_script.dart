import 'dart:io';

void main() {
  final file = File('lib/screens/admin/admin_screens.dart');
  final lines = file.readAsLinesSync();
  for (int i = 0; i < lines.length; i++) {
    if (lines[i].contains('askAI') || lines[i].contains('AI Monitor')) {
      print('${i + 1}: ${lines[i].trim()}');
    }
  }
}
