import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<void> saveDownloadedBytes({
  required String filename,
  required Uint8List bytes,
  String? mimeType,
}) async {
  final blob = web.Blob(
    <JSAny>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType ?? 'application/octet-stream'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename
    ..style.display = 'none';
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}

Future<bool> shareDownloadedBytes({
  required String filename,
  required Uint8List bytes,
  String? mimeType,
}) async {
  try {
    final type = mimeType ?? 'application/octet-stream';
    final blob = web.Blob(
      <JSAny>[bytes.toJS].toJS,
      web.BlobPropertyBag(type: type),
    );
    final file = web.File(
      <JSAny>[blob].toJS,
      filename,
      web.FilePropertyBag(type: type),
    );
    await web.window.navigator
        .share(
          web.ShareData(
            files: <web.File>[file].toJS,
            title: filename,
          ),
        )
        .toDart;
    return true;
  } catch (_) {
    return false;
  }
}
