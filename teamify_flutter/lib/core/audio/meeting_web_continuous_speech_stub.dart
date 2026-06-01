typedef WebSpeechResultHandler = void Function(String text, bool isFinal);

/// Non-web stub.
class MeetingWebContinuousSpeech {
  static bool get isApiAvailable => false;

  bool get isListening => false;

  Future<bool> start({
    required WebSpeechResultHandler onResult,
    void Function(String message)? onError,
    void Function(String status)? onStatus,
    String localeId = 'en-US',
  }) async =>
      false;

  Future<void> stop() async {}
}
