import 'dart:math';

/// Minimal ID generation utilities — avoids adding a `uuid` package dependency.
///
/// Generates a random 128-bit hex string that is statistically collision-free
/// for the mutation queue's practical scale (< 10 k items lifetime).
class MutationId {
  MutationId._();

  static final _rng = Random.secure();

  /// Returns a random hex ID in the form:
  ///   `xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx`
  static String generate() {
    final bytes = List<int>.generate(16, (_) => _rng.nextInt(256));

    // Set version (4) and variant bits (RFC 4122)
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}
