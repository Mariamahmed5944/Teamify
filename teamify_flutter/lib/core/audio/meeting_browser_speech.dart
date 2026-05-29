import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Live speech recognition in the browser (Chrome/Edge) without the Whisper service.
class MeetingBrowserSpeech {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _available = false;
  String _lastPartial = '';

  bool get isAvailable => _available;

  Future<bool> initialize() async {
    if (!kIsWeb) return false;
    _available = await _speech.initialize(
      onError: (error) => debugPrint('MeetingBrowserSpeech error: $error'),
      onStatus: (status) => debugPrint('MeetingBrowserSpeech status: $status'),
    );
    return _available;
  }

  Future<void> startListening(
    void Function(String text, bool isFinal) onResult,
  ) async {
    if (!_available) return;
    _lastPartial = '';
    await _speech.listen(
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
        listenMode: stt.ListenMode.dictation,
        partialResults: true,
        cancelOnError: false,
        pauseFor: const Duration(seconds: 3),
        listenFor: const Duration(minutes: 30),
      ),
    );
  }

  /// Commits any pending partial phrase before stopping.
  Future<void> stop(void Function(String text, bool isFinal)? onResult) async {
    if (_lastPartial.isNotEmpty && onResult != null) {
      onResult(_lastPartial, true);
      _lastPartial = '';
    }
    if (_speech.isListening) {
      await _speech.stop();
    }
  }

  bool get isListening => _speech.isListening;
}
