class DeviceHealth {
  const DeviceHealth({
    required this.unitId,
    required this.lastSeenAt,
    required this.isOnline,
  });

  final String unitId;
  final DateTime lastSeenAt;
  final bool isOnline;

  static const offlineThreshold = Duration(seconds: 30);

  static DeviceHealth fromReading({
    required String unitId,
    required DateTime readingTimestamp,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final age = current.difference(readingTimestamp);
    return DeviceHealth(
      unitId: unitId,
      lastSeenAt: readingTimestamp,
      isOnline: age <= offlineThreshold,
    );
  }

  String lastSeenLabel(DateTime now) {
    final diff = now.difference(lastSeenAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
