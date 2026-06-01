/// Live meeting speech buffer — safe partial/final merge without truncation.
class LiveSpeechBuffer {
  String committed = '';
  String utterancePartial = '';

  String get displayText {
    if (utterancePartial.isEmpty) return committed;
    return composePartialDisplay(committed, utterancePartial);
  }

  void applyPartial(String partial) {
    utterancePartial = partial.trim();
  }

  void clearPartial() {
    utterancePartial = '';
  }

  /// Commits a finalized phrase; never shrinks [committed].
  void applyFinal(String finalSegment) {
    final f = finalSegment.trim();
    if (f.isEmpty) return;
    committed = commitFinalSegment(
      committed: committed,
      finalSegment: f,
      utterancePartial: utterancePartial,
    );
    utterancePartial = '';
  }

  /// Layer 2: Whisper may produce a longer, more accurate block — extend only.
  void applyWhisperRefinement(String whisperText) {
    final w = whisperText.trim();
    if (w.isEmpty) return;
    if (committed.isEmpty) {
      committed = w;
      return;
    }
    // Never replace with shorter text.
    if (w.length <= committed.length) {
      if (committed.contains(w)) return;
      // Append if disjoint extra content
      committed = commitFinalSegment(
        committed: committed,
        finalSegment: w,
        utterancePartial: '',
      );
      return;
    }
    // Whisper is longer — prefer if it contains most of committed prefix
    if (w.startsWith(committed) ||
        committed.length < 12 ||
        _overlapRatio(committed, w) > 0.45) {
      committed = w;
      return;
    }
    committed = commitFinalSegment(
      committed: committed,
      finalSegment: w,
      utterancePartial: '',
    );
  }

  static double _overlapRatio(String a, String b) {
    final shorter = a.length < b.length ? a : b;
    final longer = a.length < b.length ? b : a;
    if (shorter.isEmpty) return 0;
    final words = shorter.toLowerCase().split(RegExp(r'\s+'));
    var hits = 0;
    for (final w in words) {
      if (w.length > 2 && longer.toLowerCase().contains(w)) hits++;
    }
    return hits / words.length;
  }
}

/// UI display: committed + in-progress utterance (partial is per-utterance, not full doc).
String composePartialDisplay(String committed, String partial) {
  final p = partial.trim();
  if (p.isEmpty) return committed.trim();
  final c = committed.trim();
  if (c.isEmpty) return p;
  if (p.startsWith(c)) return p;
  if (c.endsWith(p)) return c;
  return '$c $p';
}

/// Append finalized speech; guards against truncation and duplication.
String commitFinalSegment({
  required String committed,
  required String finalSegment,
  required String utterancePartial,
}) {
  final f = finalSegment.trim();
  if (f.isEmpty) return committed.trim();

  final c = committed.trim();
  final partial = utterancePartial.trim();

  // Truncation guard: ignore finals that would shrink committed text.
  if (c.isNotEmpty) {
    if (f.length < c.length && c.contains(f) && !f.contains(c)) {
      return c;
    }
    if (c == f || c.endsWith(f)) return c;
  }

  // Final often equals or extends the last partial for this utterance.
  if (partial.isNotEmpty) {
    if (f == partial) {
      return _appendWords(c, f);
    }
    if (f.startsWith(partial)) {
      return _appendWords(c, f);
    }
    if (partial.startsWith(f)) {
      return c; // stale partial; keep committed
    }
  }

  if (c.isEmpty) return f;
  if (f.startsWith(c)) return f; // cumulative final from engine
  if (c.contains(f) && f.length < c.length) return c;

  return _appendWords(c, f);
}

String _appendWords(String base, String addition) {
  final b = base.trim();
  final a = addition.trim();
  if (a.isEmpty) return b;
  if (b.isEmpty) return a;
  if (b.endsWith(a)) return b;
  if (a.startsWith(b)) return a;
  return '$b $a';
}
