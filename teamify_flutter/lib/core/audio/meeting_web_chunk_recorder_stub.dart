import 'dart:typed_data';

class MeetingWebChunkRecorder {
  bool get isRunning => false;

  Future<bool> start({
    required Future<void> Function(Uint8List bytes, String filename) onChunk,
    int timesliceMs = 6000,
    bool useKeepAlive = true,
  }) async =>
      false;

  Future<void> flushFinal(
    Future<void> Function(Uint8List bytes, String filename) onChunk,
  ) async {}

  void stop() {}
}
