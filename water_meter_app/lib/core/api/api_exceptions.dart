class ApiError {
  const ApiError({
    required this.code,
    required this.message,
  });

  factory ApiError.fromJson(Map<String, dynamic> json) {
    final error = json['error'] as Map<String, dynamic>? ?? json;
    return ApiError(
      code: error['code'] as String? ?? 'UNKNOWN',
      message: error['message'] as String? ?? 'An unknown error occurred',
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
