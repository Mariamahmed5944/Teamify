import 'dart:typed_data';

Future<void> saveDownloadedBytes({
  required String filename,
  required Uint8List bytes,
  String? mimeType,
}) async {
  throw UnsupportedError('File download is not supported on this platform.');
}

Future<bool> shareDownloadedBytes({
  required String filename,
  required Uint8List bytes,
  String? mimeType,
}) async {
  return false;
}
