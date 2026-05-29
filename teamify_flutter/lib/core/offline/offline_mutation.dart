import 'dart:convert';

/// Permanent failure sentinel — mutation exceeded max retries or
/// received a non-retriable HTTP error (4xx).
enum MutationStatus {
  pending,
  failedPermanently,
}

/// Represents a queued write operation captured while the device was offline.
///
/// Additions over the original model:
///  - [nextRetryAt]   : absolute time before which replay must NOT proceed
///  - [lastError]     : last error string for display / telemetry
///  - [status]        : pending vs permanently failed
///  - [headers]       : extra headers (e.g. Idempotency-Key auto-added by manager)
///  - [tag]           : caller-supplied label (e.g. 'createTask') for telemetry
class OfflineMutation {
  final String id;
  final String method;
  final String path;
  final Map<String, dynamic>? data;
  final Map<String, String>? headers;
  final int retryCount;
  final DateTime createdAt;
  final DateTime? nextRetryAt;
  final String? lastError;
  final String? tag;
  final MutationStatus status;

  OfflineMutation({
    required this.id,
    required this.method,
    required this.path,
    this.data,
    this.headers,
    this.retryCount = 0,
    DateTime? createdAt,
    this.nextRetryAt,
    this.lastError,
    this.tag,
    this.status = MutationStatus.pending,
  }) : createdAt = createdAt ?? DateTime.now();

  // ── Derived ─────────────────────────────────────────────────────────────

  bool get isPending => status == MutationStatus.pending;
  bool get isFailedPermanently => status == MutationStatus.failedPermanently;

  /// True when it is safe to attempt a replay (backoff window has elapsed).
  bool get isReadyForReplay =>
      nextRetryAt == null || DateTime.now().isAfter(nextRetryAt!);

  // ── Serialisation ────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'id': id,
        'method': method,
        'path': path,
        'data': data,
        'headers': headers,
        'retryCount': retryCount,
        'createdAt': createdAt.toIso8601String(),
        'nextRetryAt': nextRetryAt?.toIso8601String(),
        'lastError': lastError,
        'tag': tag,
        'status': status.name,
      };

  factory OfflineMutation.fromJson(Map<String, dynamic> json) {
    return OfflineMutation(
      id: json['id'] as String,
      method: json['method'] as String,
      path: json['path'] as String,
      data: json['data'] as Map<String, dynamic>?,
      headers: (json['headers'] as Map?)?.cast<String, String>(),
      retryCount: json['retryCount'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      nextRetryAt: json['nextRetryAt'] != null
          ? DateTime.tryParse(json['nextRetryAt'] as String)
          : null,
      lastError: json['lastError'] as String?,
      tag: json['tag'] as String?,
      status: MutationStatus.values.firstWhere(
        (s) => s.name == (json['status'] as String? ?? 'pending'),
        orElse: () => MutationStatus.pending,
      ),
    );
  }

  OfflineMutation copyWith({
    int? retryCount,
    DateTime? nextRetryAt,
    String? lastError,
    MutationStatus? status,
  }) {
    return OfflineMutation(
      id: id,
      method: method,
      path: path,
      data: data,
      headers: headers,
      retryCount: retryCount ?? this.retryCount,
      createdAt: createdAt,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
      lastError: lastError ?? this.lastError,
      tag: tag,
      status: status ?? this.status,
    );
  }

  @override
  String toString() =>
      'OfflineMutation($tag/$method $path retries=$retryCount status=$status)';
}

// ignore: unused_element
String _encodeHeaders(Map<String, String>? h) =>
    h == null ? '{}' : jsonEncode(h);
