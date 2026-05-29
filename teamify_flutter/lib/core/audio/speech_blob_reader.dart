import 'dart:io';
import 'dart:typed_data';

/// Reads recorded audio bytes from a file path (mobile/desktop).
Future<Uint8List> readRecordingBytes(String path) async {
  return File(path).readAsBytes();
}
