class ApiError {
  const ApiError({
    required this.code,
    required this.message,
  });

  factory ApiError.fromJson(Map<String, dynamic> json) {
    final nested = json['error'];
    if (nested is Map<String, dynamic>) {
      return ApiError(
        code: nested['code'] as String? ?? 'UNKNOWN',
        message: nested['message'] as String? ?? 'An unknown error occurred',
      );
    }
    if (nested is String && nested.isNotEmpty) {
      return ApiError(
        code: (json['status'] ?? json['code'] ?? 'UNKNOWN').toString(),
        message: nested,
      );
    }
    return ApiError(
      code: json['code'] as String? ?? json['status']?.toString() ?? 'UNKNOWN',
      message: json['message'] as String? ?? 'An unknown error occurred',
    );
  }

  final String code;
  final String message;
}

class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.error,
  });

  final int statusCode;
  final ApiError error;

  @override
  String toString() => 'ApiException($statusCode): ${error.message}';
}

class NetworkException implements Exception {
  const NetworkException(this.message);

  final String message;

  @override
  String toString() => 'NetworkException: $message';
}
