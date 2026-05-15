

/// Represents a queued mutation when offline.
class OfflineMutation {
  final String id;
  final String method;
  final String path;
  final Map<String, dynamic>? data;
  final int retryCount;
  final DateTime createdAt;

  OfflineMutation({
    required this.id,
    required this.method,
    required this.path,
    this.data,
    this.retryCount = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'method': method,
        'path': path,
        'data': data,
        'retryCount': retryCount,
        'createdAt': createdAt.toIso8601String(),
      };

  factory OfflineMutation.fromJson(Map<String, dynamic> json) {
    return OfflineMutation(
      id: json['id'] as String,
      method: json['method'] as String,
      path: json['path'] as String,
      data: json['data'] as Map<String, dynamic>?,
      retryCount: json['retryCount'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  OfflineMutation copyWith({int? retryCount}) {
    return OfflineMutation(
      id: id,
      method: method,
      path: path,
      data: data,
      retryCount: retryCount ?? this.retryCount,
      createdAt: createdAt,
    );
  }
}
