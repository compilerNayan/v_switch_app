enum Granularity {
  m1('1m', Duration(minutes: 1)),
  m5('5m', Duration(minutes: 5)),
  m15('15m', Duration(minutes: 15)),
  m30('30m', Duration(minutes: 30)),
  h1('1h', Duration(hours: 1)),
  d1('1d', Duration(days: 1));

  const Granularity(this.apiValue, this.bucketDuration);

  final String apiValue;
  final Duration bucketDuration;

  static Granularity fromApiValue(String value) {
    return Granularity.values.firstWhere(
      (g) => g.apiValue == value,
      orElse: () => Granularity.h1,
    );
  }

  String get label {
    switch (this) {
      case Granularity.m1:
        return '1 min';
      case Granularity.m5:
        return '5 min';
      case Granularity.m15:
        return '15 min';
      case Granularity.m30:
        return '30 min';
      case Granularity.h1:
        return '1 hour';
      case Granularity.d1:
        return '1 day';
    }
  }
}

class UsageDataPoint {
  const UsageDataPoint({
    required this.timestamp,
    required this.volumeLiters,
    required this.avgFlowRateLpm,
  });

  factory UsageDataPoint.fromJson(Map<String, dynamic> json) {
    return UsageDataPoint(
      timestamp: DateTime.parse(json['timestamp'] as String),
      volumeLiters: (json['volumeLiters'] as num).toDouble(),
      avgFlowRateLpm: (json['avgFlowRateLpm'] as num).toDouble(),
    );
  }

  final DateTime timestamp;
  final double volumeLiters;
  final double avgFlowRateLpm;

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toUtc().toIso8601String(),
        'volumeLiters': volumeLiters,
        'avgFlowRateLpm': avgFlowRateLpm,
      };
}

class PeakBucket {
  const PeakBucket({
    required this.timestamp,
    required this.volumeLiters,
  });

  factory PeakBucket.fromJson(Map<String, dynamic> json) {
    return PeakBucket(
      timestamp: DateTime.parse(json['timestamp'] as String),
      volumeLiters: (json['volumeLiters'] as num).toDouble(),
    );
  }

  final DateTime timestamp;
  final double volumeLiters;

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toUtc().toIso8601String(),
        'volumeLiters': volumeLiters,
      };
}

class UsageSummary {
  const UsageSummary({
    required this.totalVolumeLiters,
    required this.averagePerBucketLiters,
    required this.peakBucket,
    required this.previousPeriodTotalLiters,
    required this.deltaPercent,
  });

  factory UsageSummary.fromJson(Map<String, dynamic> json) {
    return UsageSummary(
      totalVolumeLiters: (json['totalVolumeLiters'] as num).toDouble(),
      averagePerBucketLiters:
          (json['averagePerBucketLiters'] as num).toDouble(),
      peakBucket:
          PeakBucket.fromJson(json['peakBucket'] as Map<String, dynamic>),
      previousPeriodTotalLiters:
          (json['previousPeriodTotalLiters'] as num).toDouble(),
      deltaPercent: (json['deltaPercent'] as num).toDouble(),
    );
  }

  final double totalVolumeLiters;
  final double averagePerBucketLiters;
  final PeakBucket peakBucket;
  final double previousPeriodTotalLiters;
  final double deltaPercent;

  Map<String, dynamic> toJson() => {
        'totalVolumeLiters': totalVolumeLiters,
        'averagePerBucketLiters': averagePerBucketLiters,
        'peakBucket': peakBucket.toJson(),
        'previousPeriodTotalLiters': previousPeriodTotalLiters,
        'deltaPercent': deltaPercent,
      };
}

class UsageResponse {
  const UsageResponse({
    required this.deviceId,
    required this.from,
    required this.to,
    required this.granularity,
    required this.unit,
    required this.dataPoints,
    required this.summary,
  });

  factory UsageResponse.fromJson(Map<String, dynamic> json) {
    return UsageResponse(
      deviceId: json['deviceId'] as String,
      from: DateTime.parse(json['from'] as String),
      to: DateTime.parse(json['to'] as String),
      granularity: Granularity.fromApiValue(json['granularity'] as String),
      unit: json['unit'] as String,
      dataPoints: (json['dataPoints'] as List<dynamic>)
          .map((e) => UsageDataPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      summary: UsageSummary.fromJson(json['summary'] as Map<String, dynamic>),
    );
  }

  final String deviceId;
  final DateTime from;
  final DateTime to;
  final Granularity granularity;
  final String unit;
  final List<UsageDataPoint> dataPoints;
  final UsageSummary summary;

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'from': from.toUtc().toIso8601String(),
        'to': to.toUtc().toIso8601String(),
        'granularity': granularity.apiValue,
        'unit': unit,
        'dataPoints': dataPoints.map((p) => p.toJson()).toList(),
        'summary': summary.toJson(),
      };
}
