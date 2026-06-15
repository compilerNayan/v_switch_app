class BulkDummyEnrollItemResult {
  const BulkDummyEnrollItemResult({
    required this.serialNumber,
    required this.status,
    this.expiresAt,
    this.error,
  });

  factory BulkDummyEnrollItemResult.fromJson(Map<String, dynamic> json) {
    return BulkDummyEnrollItemResult(
      serialNumber: json['serialNumber'] as String? ?? '',
      status: json['status'] as String? ?? 'failed',
      expiresAt: json['expiresAt'] as String?,
      error: json['error'] as String?,
    );
  }

  final String serialNumber;
  final String status;
  final String? expiresAt;
  final String? error;

  bool get enrolled => status == 'enrolled';
}

class BulkDummyEnrollResponse {
  const BulkDummyEnrollResponse({
    required this.tenantId,
    required this.requested,
    required this.enrolled,
    required this.failed,
    required this.results,
  });

  factory BulkDummyEnrollResponse.fromJson(Map<String, dynamic> json) {
    final resultsJson = json['results'] as List<dynamic>? ?? const [];
    return BulkDummyEnrollResponse(
      tenantId: json['tenantId'] as String? ?? '',
      requested: json['requested'] as int? ?? 0,
      enrolled: json['enrolled'] as int? ?? 0,
      failed: json['failed'] as int? ?? 0,
      results: resultsJson
          .map(
            (entry) =>
                BulkDummyEnrollItemResult.fromJson(entry as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  final String tenantId;
  final int requested;
  final int enrolled;
  final int failed;
  final List<BulkDummyEnrollItemResult> results;
}
