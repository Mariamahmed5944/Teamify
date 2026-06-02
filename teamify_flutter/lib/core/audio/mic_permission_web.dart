// Web-only: requests mic access by calling navigator.mediaDevices.getUserMedia
// directly, which guarantees the native browser permission dialog appears on
// both desktop and mobile browsers (iOS Safari, Chrome for Android, etc.).
// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:html' as html;

Future<bool> requestMicPermission() async {
  try {
    final stream = await html.window.navigator.mediaDevices!
        .getUserMedia({'audio': true, 'video': false});
    // Stop all tracks immediately — we only needed the permission prompt.
    for (final track in stream.getTracks()) {
      track.stop();
    }
    return true;
  } catch (_) {
    return false;
  }
}
