import 'dart:io';

void main() {
  final dir = Directory('lib/screens/meeting');
  if (!dir.existsSync()) return;
  final out = File('find_output.txt').openWrite();
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      final lines = entity.readAsLinesSync();
      for (int i = 0; i < lines.length; i++) {
        final lower = lines[i].toLowerCase();
        if (lower.contains('raise') || lower.contains('camera') || lower.contains('participants') || lower.contains('leave')) {
          out.writeln('${entity.path}:${i + 1}: ${lines[i]}');
        }
      }
    }
  }
  out.close();
}
