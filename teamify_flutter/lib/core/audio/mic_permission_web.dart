// Web-only: requests mic access by calling navigator.mediaDevices.getUserMedia
// directly, which guarantees the native browser permission dialog appears on
// both desktop and mobile browsers (iOS Safari, Chrome for Android, etc.).
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

Future<bool> requestMicPermission() async {
  try {
    final devices = html.window.navigator.mediaDevices;
    if (devices == null) return false;
    final stream = await devices.getUserMedia({'audio': true});
    for (final track in stream.getTracks()) {
      track.stop();
    }
    return true;
  } catch (_) {
    return false;
  }
}
