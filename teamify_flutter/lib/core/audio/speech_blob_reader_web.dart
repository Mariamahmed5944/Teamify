// Web-only implementation; imported via conditional export on io platforms.
// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'dart:typed_data';

/// Reads recorded audio bytes from a blob URL (Flutter web).
Future<Uint8List> readRecordingBytes(String path) async {
  final request = await html.HttpRequest.request(
    path,
    method: 'GET',
    responseType: 'arraybuffer',
  );
  return Uint8List.view(request.response);
}
