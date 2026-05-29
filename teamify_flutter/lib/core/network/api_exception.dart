import 'dart:convert';
import 'dart:typed_data';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? code;
  final List<String> validationMessages;

  const ApiException(
    this.message, {
    this.statusCode,
    this.code,
    this.validationMessages = const [],
  });

  bool get isPendingApproval => code == 'Account Pending Approval';
  bool get isUnauthorized => statusCode == 401;
  bool get isCancelled => message == 'Request cancelled';

  @override
  String toString() => message;

  factory ApiException.fromResponse(int? statusCode, dynamic data) {
    if (data is List<int> || data is Uint8List) {
      try {
        final text = String.fromCharCodes(
          data is Uint8List ? data : Uint8List.fromList(data),
        );
        if (text.trimLeft().startsWith('{')) {
          final decoded = jsonDecode(text);
          if (decoded is Map<String, dynamic>) {
            return ApiException.fromResponse(statusCode, decoded);
          }
        }
      } catch (_) {}
    }
    if (data is Map<String, dynamic>) {
      final code = data['error']?.toString();
      final details = data['details'];
      final validationMessages = details is List
          ? details.map((e) => e.toString()).toList()
          : _flattenMessages(data['messages']);
      final message = data['message']?.toString() ??
          data['detail']?.toString() ??
          (validationMessages.isNotEmpty
              ? validationMessages.join('\n')
              : null) ??
          code ??
          'Request failed';

      return ApiException(
        message,
        statusCode: statusCode,
        code: code,
        validationMessages: validationMessages,
      );
    }

    return ApiException(
      data?.toString() ?? 'Request failed',
      statusCode: statusCode,
    );
  }

  static List<String> _flattenMessages(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
    }
    if (raw is! Map) return const [];

    final out = <String>[];
    void walk(dynamic node, String prefix) {
      if (node is Map) {
        node.forEach((key, value) {
          final path = prefix.isEmpty ? key.toString() : '$prefix.$key';
          walk(value, path);
        });
      } else if (node is List) {
        for (final item in node) {
          if (item is String && item.isNotEmpty) {
            out.add(prefix.isEmpty ? item : '$prefix: $item');
          } else {
            walk(item, prefix);
          }
        }
      } else if (node is String && node.isNotEmpty) {
        out.add(prefix.isEmpty ? node : '$prefix: $node');
      }
    }

    walk(raw, '');
    return out;
  }
}
