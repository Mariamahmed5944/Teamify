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
    if (data is Map<String, dynamic>) {
      final code = data['error']?.toString();
      final rawMessages = data['messages'];
      final validationMessages = rawMessages is List
          ? rawMessages.map((e) => e.toString()).toList()
          : const <String>[];
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
}
