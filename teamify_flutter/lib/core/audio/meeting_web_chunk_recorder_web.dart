// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'meeting_mic_keepalive.dart';

/// Continuous [MediaRecorder] — mic never stops between slice uploads.
class MeetingWebChunkRecorder {
  html.MediaRecorder? _recorder;
  void Function(html.Event)? _onData;
  bool _running = false;

  bool get isRunning => _running;

  Future<bool> start({
    required Future<void> Function(Uint8List bytes, String filename) onChunk,
    int timesliceMs = 6000,
    bool useKeepAlive = true,
  }) async {
    if (_running) return true;

    html.MediaStream? raw;
    if (useKeepAlive) {
      if (!MeetingMicKeepAlive.isActive) {
        final ok = await MeetingMicKeepAlive.acquire();
        if (!ok) return false;
      }
      final stream = MeetingMicKeepAlive.stream;
      if (stream is! html.MediaStream) return false;
      raw = stream;
    } else {
      try {
        raw = await html.window.navigator.mediaDevices?.getUserMedia({
          'audio': true,
        });
      } catch (_) {
        return false;
      }
      if (raw == null) return false;
    }

    try {
      final mime = html.MediaRecorder.isTypeSupported('audio/webm;codecs=opus')
          ? 'audio/webm;codecs=opus'
          : 'audio/webm';
      _recorder = html.MediaRecorder(raw, {'mimeType': mime});
    } catch (_) {
      try {
        _recorder = html.MediaRecorder(raw);
      } catch (_) {
        return false;
      }
    }

    _onData = (html.Event event) {
      if (event is! html.BlobEvent) return;
      final blob = event.data;
      if (blob == null || blob.size == 0) return;
      unawaited(_readBlob(blob, onChunk));
    };

    _recorder!.addEventListener('dataavailable', _onData!);
    _recorder!.start(timesliceMs);
    _running = true;
    return true;
  }

  static Future<void> _readBlob(
    html.Blob blob,
    Future<void> Function(Uint8List bytes, String filename) onChunk,
  ) async {
    try {
      final reader = html.FileReader();
      final done = reader.onLoadEnd.first;
      reader.readAsArrayBuffer(blob);
      await done;
      final buffer = reader.result;
      if (buffer is! ByteBuffer) return;
      final bytes = buffer.asUint8List();
      if (bytes.isEmpty) return;
      await onChunk(bytes, 'meeting_chunk.webm');
    } catch (_) {}
  }

  Future<void> flushFinal(
    Future<void> Function(Uint8List bytes, String filename) onChunk,
  ) async {
    final rec = _recorder;
    if (rec == null || rec.state == 'inactive') return;
    try {
      rec.requestData();
      await Future.delayed(const Duration(milliseconds: 350));
    } catch (_) {}
  }

  void stop() {
    _running = false;
    final rec = _recorder;
    final handler = _onData;
    _onData = null;
    if (rec != null && handler != null) {
      rec.removeEventListener('dataavailable', handler);
    }
    try {
      if (rec != null && rec.state != 'inactive') {
        rec.stop();
      }
    } catch (_) {}
    _recorder = null;
  }
}
