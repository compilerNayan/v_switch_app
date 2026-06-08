class BulkValveSnapshotEntry {
  const BulkValveSnapshotEntry({
    required this.deviceId,
    required this.unitId,
    required this.wasOn,
    required this.pressurePercent,
  });

  factory BulkValveSnapshotEntry.fromJson(Map<String, dynamic> json) {
    return BulkValveSnapshotEntry(
      deviceId: json['deviceId'] as String,
      unitId: json['unitId'] as String,
      wasOn: json['wasOn'] as bool? ?? false,
      pressurePercent: (json['pressurePercent'] as num?)?.toDouble() ?? 100,
    );
  }

  final String deviceId;
  final String unitId;
  final bool wasOn;
  final double pressurePercent;

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'unitId': unitId,
        'wasOn': wasOn,
        'pressurePercent': pressurePercent,
      };
}

class BulkValveSnapshot {
  const BulkValveSnapshot({
    required this.snapshotId,
    required this.createdAt,
    required this.entries,
  });

  factory BulkValveSnapshot.fromJson(Map<String, dynamic> json) {
    return BulkValveSnapshot(
      snapshotId: json['snapshotId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      entries: (json['entries'] as List<dynamic>)
          .map((e) => BulkValveSnapshotEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  final String snapshotId;
  final DateTime createdAt;
  final List<BulkValveSnapshotEntry> entries;

  Map<String, dynamic> toJson() => {
        'snapshotId': snapshotId,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'entries': entries.map((e) => e.toJson()).toList(),
      };
}
