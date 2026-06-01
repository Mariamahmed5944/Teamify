/// Non-web: no persistent mic session needed.
class MeetingMicKeepAlive {
  static bool get isActive => false;
  static Object? get stream => null;

  static Future<bool> acquire() async => true;

  static void release() {}
}
