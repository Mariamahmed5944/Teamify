// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

/// Holds [getUserMedia] open for the whole meeting so the tab mic icon stays on.
class MeetingMicKeepAlive {
  static html.MediaStream? _stream;

  static bool get isActive => _stream != null;
  static html.MediaStream? get stream => _stream;

  static Future<bool> acquire() async {
    if (_stream != null) return true;
    try {
      final devices = html.window.navigator.mediaDevices;
      if (devices == null) return false;
      _stream = await devices.getUserMedia({'audio': true});
      return _stream != null;
    } catch (_) {
      return false;
    }
  }

  static void release() {
    final s = _stream;
    _stream = null;
    if (s == null) return;
    for (final track in s.getAudioTracks()) {
      track.stop();
    }
  }
}
