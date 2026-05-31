import 'dart:convert';
import 'dart:typed_data';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? code;
  final List<String> validationMessages;
  final bool requires2fa;
  final bool requires2faSetup;

  const ApiException(
    this.message, {
    this.statusCode,
    this.code,
    this.validationMessages = const [],
    this.requires2fa = false,
    this.requires2faSetup = false,
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
          if (decoded is Map) {
            return ApiException.fromResponse(
              statusCode,
              Map<String, dynamic>.from(decoded),
            );
          }
        }
      } catch (_) {}
    }
    if (data is String && data.trimLeft().startsWith('{')) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) {
          return ApiException.fromResponse(
            statusCode,
            Map<String, dynamic>.from(decoded),
          );
        }
      } catch (_) {}
    }
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final code = map['error']?.toString();
      final details = map['details'];
      final validationMessages = details is List
          ? details.map((e) => e.toString()).toList()
          : _flattenMessages(map['messages']);
      final message = map['message']?.toString() ??
          map['detail']?.toString() ??
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
        requires2fa: map['requires_2fa'] == true,
        requires2faSetup: map['requires_2fa_setup'] == true,
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
