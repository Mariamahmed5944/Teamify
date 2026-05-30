import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Live speech recognition in the browser (Chrome/Edge) without the Whisper service.
class MeetingBrowserSpeech {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _available = false;
  String _lastPartial = '';
  void Function(String text, bool isFinal)? _onResult;
  void Function(String message)? _onError;
  void Function(String status)? _onStatus;
  bool _restartScheduled = false;

  bool get isAvailable => _available;
  bool get isListening => _speech.isListening;

  Future<bool> initialize({
    void Function(String message)? onError,
    void Function(String status)? onStatus,
  }) async {
    if (!kIsWeb) return false;
    _onError = onError;
    _onStatus = onStatus;
    _available = await _speech.initialize(
      onError: (SpeechRecognitionError error) {
        debugPrint('MeetingBrowserSpeech error: ${error.errorMsg}');
        _onError?.call(error.errorMsg);
      },
      onStatus: (status) {
        debugPrint('MeetingBrowserSpeech status: $status');
        _onStatus?.call(status);
        _maybeScheduleRestart(status);
      },
    );
    return _available;
  }

  void _maybeScheduleRestart(String status) {
    if (_onResult == null) return;
    if (status != 'done' && status != 'notListening') return;
    if (_restartScheduled || _speech.isListening) return;
    _restartScheduled = true;
    Future.delayed(const Duration(milliseconds: 400), () async {
      _restartScheduled = false;
      if (_onResult == null || _speech.isListening) return;
      await startListening(_onResult!);
    });
  }

  Future<bool> startListening(
    void Function(String text, bool isFinal) onResult, {
    String? localeId,
  }) async {
    if (!_available) return false;
    _onResult = onResult;
    _lastPartial = '';

    if (_speech.isListening) {
      await _speech.stop();
    }

    final started = await _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        final words = result.recognizedWords.trim();
        if (words.isEmpty) return;
        if (result.finalResult) {
          onResult(words, true);
          _lastPartial = '';
        } else {
          _lastPartial = words;
          onResult(words, false);
        }
      },
      listenOptions: stt.SpeechListenOptions(
        localeId: localeId ?? 'en-US',
        listenMode: stt.ListenMode.dictation,
        partialResults: true,
        cancelOnError: false,
        pauseFor: const Duration(seconds: 5),
        listenFor: const Duration(minutes: 30),
      ),
    );

    if (!started) return false;

    // Web Speech API may fail async; confirm the session actually started.
    await Future.delayed(const Duration(milliseconds: 600));
    return _speech.isListening;
  }

  /// Commits any pending partial phrase before stopping.
  Future<void> stop(void Function(String text, bool isFinal)? onResult) async {
    _onResult = null;
    if (_lastPartial.isNotEmpty && onResult != null) {
      onResult(_lastPartial, true);
      _lastPartial = '';
    }
    if (_speech.isListening) {
      await _speech.stop();
    }
  }
}
