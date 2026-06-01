// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:js_util' as js_util;

import 'meeting_web_continuous_speech_stub.dart';

/// Native Web Speech API with continuous=true and interimResults=true.
class MeetingWebContinuousSpeech {
  static bool get isApiAvailable {
    final ctor = js_util.getProperty(html.window, 'SpeechRecognition') ??
        js_util.getProperty(html.window, 'webkitSpeechRecognition');
    return ctor != null;
  }

  Object? _recognition;
  bool _intentionalStop = false;
  bool _restartScheduled = false;
  DateTime? _lastRestartAt;
  WebSpeechResultHandler? _onResult;
  void Function(String message)? _onError;
  void Function(String status)? _onStatus;
  String _localeId = 'en-US';

  static const Duration _restartDebounce = Duration(milliseconds: 450);
  static const Duration _minRestartGap = Duration(milliseconds: 800);

  bool get isListening => _recognition != null && !_intentionalStop;

  Future<bool> start({
    required WebSpeechResultHandler onResult,
    void Function(String message)? onError,
    void Function(String status)? onStatus,
    String localeId = 'en-US',
  }) async {
    await stop();
    _onResult = onResult;
    _onError = onError;
    _onStatus = onStatus;
    _localeId = localeId;
    _intentionalStop = false;
    return _startEngine();
  }

  bool _startEngine() {
    final ctor = js_util.getProperty(html.window, 'SpeechRecognition') ??
        js_util.getProperty(html.window, 'webkitSpeechRecognition');
    if (ctor == null) return false;

    _recognition = js_util.callConstructor(ctor as Object, []);
    js_util.setProperty(_recognition!, 'continuous', true);
    js_util.setProperty(_recognition!, 'interimResults', true);
    js_util.setProperty(_recognition!, 'maxAlternatives', 1);
    js_util.setProperty(_recognition!, 'lang', _localeId);

    js_util.setProperty(
      _recognition!,
      'onresult',
      js_util.allowInterop(_handleResult),
    );
    js_util.setProperty(
      _recognition!,
      'onerror',
      js_util.allowInterop(_handleError),
    );
    js_util.setProperty(
      _recognition!,
      'onend',
      js_util.allowInterop((_) => _handleEnd()),
    );
    js_util.setProperty(
      _recognition!,
      'onstart',
      js_util.allowInterop((_) => _onStatus?.call('listening')),
    );
    js_util.setProperty(
      _recognition!,
      'onspeechstart',
      js_util.allowInterop((_) => _onStatus?.call('speech_detected')),
    );

    try {
      js_util.callMethod(_recognition!, 'start', []);
      return true;
    } catch (_) {
      return false;
    }
  }

  void _handleResult(dynamic event) {
    final handler = _onResult;
    if (handler == null) return;

    final results = js_util.getProperty(event, 'results');
    if (results == null) return;

    final length = (js_util.getProperty(results, 'length') as num?)?.toInt() ?? 0;
    final resultIndex =
        (js_util.getProperty(event, 'resultIndex') as num?)?.toInt() ?? 0;

  // Per-utterance interim is cumulative in Chrome — use the latest non-final only.
    var lastInterim = '';
    for (var i = resultIndex; i < length; i++) {
      final result = js_util.callMethod(results, 'item', [i]);
      final isFinal = _isResultFinal(result);
      final transcript = _transcriptFromResult(result);
      if (transcript.isEmpty) continue;
      if (isFinal) {
        handler(transcript, true);
      } else {
        lastInterim = transcript;
      }
    }

    final interimTrim = lastInterim.trim();
    if (interimTrim.isNotEmpty) {
      handler(interimTrim, false);
      return;
    }

    // Some Chrome builds only expose the latest phrase on the last result slot.
    if (length > 0) {
      final last = js_util.callMethod(results, 'item', [length - 1]);
      if (!_isResultFinal(last)) {
        final tail = _transcriptFromResult(last);
        if (tail.isNotEmpty) handler(tail, false);
      }
    }
  }

  String _transcriptFromResult(Object? result) {
    if (result == null) return '';
    try {
      // SpeechRecognitionResult.item(0) → SpeechRecognitionAlternative.transcript
      final alt = js_util.callMethod(result, 'item', [0]);
      if (alt == null) return '';
      final text = js_util.getProperty(alt, 'transcript');
      return (text as String?)?.trim() ?? text?.toString().trim() ?? '';
    } catch (_) {
      return '';
    }
  }

  bool _isResultFinal(Object? result) {
    if (result == null) return false;
    final v = js_util.getProperty(result, 'isFinal');
    return v == true;
  }

  void _handleError(dynamic event) {
    final err = js_util.getProperty(event, 'error');
    _onError?.call(err?.toString() ?? 'speech_error');
    _onStatus?.call('error');
  }

  void _handleEnd() {
    if (_intentionalStop) return;
    _onStatus?.call('ended');
    _scheduleRestart();
  }

  void _scheduleRestart() {
    if (_intentionalStop || _onResult == null) return;
    if (_restartScheduled) return;

    final now = DateTime.now();
    var delay = _restartDebounce;
    if (_lastRestartAt != null) {
      final since = now.difference(_lastRestartAt!);
      if (since < _minRestartGap) {
        delay = _minRestartGap - since + _restartDebounce;
      }
    }

    _restartScheduled = true;
    _onStatus?.call('restarting');

    Future.delayed(delay, () {
      _restartScheduled = false;
      if (_intentionalStop || _onResult == null) return;
      _lastRestartAt = DateTime.now();
      try {
        if (_recognition != null) {
          js_util.callMethod(_recognition!, 'start', []);
        } else {
          _startEngine();
        }
      } catch (_) {
        _startEngine();
      }
    });
  }

  Future<void> stop() async {
    _intentionalStop = true;
    _restartScheduled = false;
    final rec = _recognition;
    _recognition = null;
    if (rec != null) {
      try {
        js_util.callMethod(rec, 'stop', []);
      } catch (_) {}
    }
    _onResult = null;
  }
}
