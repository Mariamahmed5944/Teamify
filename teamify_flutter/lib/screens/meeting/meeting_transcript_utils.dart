/// Helpers to clean meeting transcripts before summary UI / API calls.
library;

/// Normalizes, sorts, and deduplicates meeting transcript entries.
List<Map<String, dynamic>> normalizeMeetingTranscript(
  List<Map<String, dynamic>> raw,
) {
  final items = raw
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .where((e) => (e['content']?.toString().trim() ?? '').isNotEmpty)
      .toList();

  items.sort((a, b) {
    final da = DateTime.tryParse(a['created_at']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final db = DateTime.tryParse(b['created_at']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return da.compareTo(db);
  });

  return _dedupeTranscript(items);
}

List<Map<String, dynamic>> _dedupeTranscript(
  List<Map<String, dynamic>> items,
) {
  final out = <Map<String, dynamic>>[];
  for (final item in items) {
    final content = item['content']?.toString().trim() ?? '';
    if (content.isEmpty) continue;

    final isSpeech = item['source']?.toString() == 'speech';
    if (isSpeech && out.isNotEmpty) {
      final prev = out.last;
      if (prev['source']?.toString() == 'speech') {
        final prevText = prev['content']?.toString().trim() ?? '';
        if (content == prevText) continue;
        if (content.startsWith(prevText) && content.length > prevText.length) {
          out.removeLast();
        } else if (prevText.startsWith(content)) {
          continue;
        }
      }
    }

    final dup = out.any((e) {
      final sameSource = e['source']?.toString() == item['source']?.toString();
      final sameContent = e['content']?.toString().trim() == content;
      final sameSender =
          e['sender_id']?.toString() == item['sender_id']?.toString();
      return sameSource && sameContent && sameSender;
    });
    if (!dup) out.add(item);
  }
  return out;
}

/// Human-readable duration; caps absurd values from bad timestamps.
String? formatMeetingDuration({
  int? durationSeconds,
  DateTime? startedAt,
  DateTime? endedAt,
}) {
  int? secs = durationSeconds;
  if ((secs == null || secs <= 0) && startedAt != null && endedAt != null) {
    secs = endedAt.difference(startedAt).inSeconds;
  }
  if (secs == null || secs <= 0) return null;
  // Ignore corrupt durations (e.g. whole chat history used as span).
  if (secs > 8 * 3600) return null;

  final d = Duration(seconds: secs);
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (h > 0) return '${h}h $m:$s';
  return '$m:$s';
}

int countUniqueParticipants(List<Map<String, dynamic>> msgs) {
  final ids = <String>{};
  for (final m in msgs) {
    final id = m['sender_id']?.toString() ?? '';
    final name = m['sender_name']?.toString().trim() ?? '';
    if (id.isNotEmpty) {
      ids.add(id);
    } else if (name.isNotEmpty) {
      ids.add(name.toLowerCase());
    }
  }
  return ids.length;
}

List<String> speechLinesFromTranscript(List<Map<String, dynamic>> msgs) {
  return msgs
      .where((m) => m['source']?.toString() == 'speech')
      .map((m) {
        final name = m['sender_name']?.toString().trim() ?? 'Speaker';
        final text = m['content']?.toString().trim() ?? '';
        return '$name: $text';
      })
      .where((line) => line.length > 4)
      .toList();
}

List<String> chatLinesFromTranscript(List<Map<String, dynamic>> msgs) {
  return msgs
      .where((m) => m['source']?.toString() != 'speech')
      .map((m) {
        final name = m['sender_name']?.toString().trim() ?? 'User';
        final text = m['content']?.toString().trim() ?? '';
        return '$name: $text';
      })
      .where((line) => line.length > 4)
      .toList();
}

String clampSummaryText(String text, {int maxLen = 480}) {
  final cleaned = text.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (cleaned.length <= maxLen) return cleaned;
  final cut = cleaned.substring(0, maxLen);
  final lastPeriod = cut.lastIndexOf('.');
  if (lastPeriod > maxLen ~/ 2) {
    return cut.substring(0, lastPeriod + 1);
  }
  return '$cut…';
}

List<String> cleanKeyPoints(
  List<dynamic>? raw, {
  int maxItems = 5,
  int minLength = 8,
}) {
  if (raw == null) return [];
  final seen = <String>{};
  final out = <String>[];
  for (final item in raw) {
    var s = item.toString().trim().replaceAll(RegExp(r'\s+'), ' ');
    if (s.length < minLength || s.length > 220) continue;
    final key = s.toLowerCase();
    if (seen.contains(key)) continue;
    seen.add(key);
    out.add(s);
    if (out.length >= maxItems) break;
  }
  return out;
}

List<Map<String, String>> cleanActionItems(List<dynamic>? raw) {
  if (raw == null) return [];
  final out = <Map<String, String>>[];
  final keywords = RegExp(
    r'\b(will|should|must|need to|have to|todo|task|assign|follow up|deadline)\b',
    caseSensitive: false,
  );
  for (final item in raw) {
    String text;
    String owner;
    var structured = false;
    if (item is Map) {
      text = (item['action'] ?? item['text'] ?? item['task'] ?? '')
          .toString()
          .trim();
      owner = (item['person'] ?? item['owner'] ?? item['assignee'] ?? 'Team')
          .toString()
          .trim();
      structured =
          (item['action'] ?? item['task'] ?? '').toString().trim().isNotEmpty;
    } else {
      text = item.toString().trim();
      owner = 'Team';
    }
    if (text.length < 6 || text.length > 200) continue;
    if (!structured && !keywords.hasMatch(text)) continue;
    out.add({
      'text': text,
      'owner': owner.isEmpty ? 'Team' : owner,
      'due': _actionDueLabel(item),
    });
    if (out.length >= 6) break;
  }
  return out;
}

String _actionDueLabel(dynamic item) {
  if (item is Map) {
    for (final key in ['due', 'due_date', 'deadline', 'when']) {
      final v = item[key]?.toString().trim();
      if (v != null && v.isNotEmpty && v.toLowerCase() != 'tbd') return v;
    }
  }
  return 'TBD';
}

/// Fallback when keyword filter yields no rows — still show AI action items.
List<Map<String, String>> relaxedActionItems(List<dynamic>? raw) {
  if (raw == null) return [];
  final out = <Map<String, String>>[];
  for (final item in raw) {
    String text;
    String owner;
    if (item is Map) {
      text = (item['action'] ?? item['text'] ?? item['task'] ?? '')
          .toString()
          .trim();
      owner = (item['person'] ?? item['owner'] ?? item['assignee'] ?? 'Team')
          .toString()
          .trim();
    } else {
      text = item.toString().trim();
      owner = 'Team';
    }
    if (text.length < 6 || text.length > 220) continue;
    out.add({
      'text': text,
      'owner': owner.isEmpty ? 'Team' : owner,
      'due': _actionDueLabel(item),
    });
    if (out.length >= 8) break;
  }
  return out;
}

/// Derive decision bullets from summary text and transcript when AI fields are empty.
List<String> localMeetingDecisions({
  required List<Map<String, dynamic>> msgs,
  required String summaryText,
  int maxItems = 6,
}) {
  final seen = <String>{};
  final out = <String>[];

  void add(String raw) {
    var s = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    s = s.replaceAll(RegExp(r'^[-•*]\s*'), '');
    if (s.length < 8 || s.length > 220) return;
    final key = s.toLowerCase();
    if (seen.contains(key)) return;
    seen.add(key);
    out.add(s);
  }

  for (final part in summaryText.split(RegExp(r'(?<=[.!?])\s+'))) {
    add(part);
    if (out.length >= maxItems) return out;
  }

  for (final m in msgs) {
    add((m['content'] ?? '').toString());
    if (out.length >= maxItems) return out;
  }

  return out;
}

/// Infer follow-up tasks from transcript lines when action_items are missing.
List<Map<String, String>> localMeetingActions(
  List<Map<String, dynamic>> msgs, {
  int maxItems = 6,
}) {
  final keywords = RegExp(
    r'\b(will|should|must|need to|have to|todo|task|assign|follow up|deadline|create|update|review|schedule|implement)\b',
    caseSensitive: false,
  );
  final out = <Map<String, String>>[];
  final seen = <String>{};

  for (final m in msgs) {
    final text = (m['content'] ?? '').toString().trim();
    final owner = (m['sender_name'] ?? m['sender'] ?? 'Team').toString().trim();
    if (text.length < 8) continue;
    if (!keywords.hasMatch(text) && text.length < 24) continue;

    final key = text.toLowerCase();
    if (seen.contains(key)) continue;
    seen.add(key);

    out.add({
      'text': text,
      'owner': owner.isEmpty ? 'Team' : owner,
      'due': 'TBD',
    });
    if (out.length >= maxItems) break;
  }

  return out;
}
