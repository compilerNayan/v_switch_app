class PresenceActivityResponse {
  const PresenceActivityResponse({
    required this.deviceId,
    required this.timezone,
    required this.from,
    required this.to,
    required this.days,
  });

  final String deviceId;
  final String timezone;
  final String from;
  final String to;
  final List<DayPresenceActivity> days;

  factory PresenceActivityResponse.fromJson(Map<String, dynamic> json) {
    final daysJson = json['days'] as List<dynamic>? ?? const [];
    return PresenceActivityResponse(
      deviceId: json['deviceId'] as String? ?? '',
      timezone: json['timezone'] as String? ?? 'UTC',
      from: json['from'] as String? ?? '',
      to: json['to'] as String? ?? '',
      days: daysJson
          .map((day) => DayPresenceActivity.fromJson(day as Map<String, dynamic>))
          .toList(),
    );
  }

  DayPresenceActivity? dayFor(String date) {
    for (final day in days) {
      if (day.date == date) {
        return day;
      }
    }
    return null;
  }
}

class DayPresenceActivity {
  const DayPresenceActivity({
    required this.date,
    required this.segments,
    required this.onlineSeconds,
    required this.offlineSeconds,
    this.bootCount = 0,
  });

  final String date;
  final List<PresenceSegment> segments;
  final int onlineSeconds;
  final int offlineSeconds;
  final int bootCount;

  factory DayPresenceActivity.fromJson(Map<String, dynamic> json) {
    final segmentsJson = json['segments'] as List<dynamic>? ?? const [];
    return DayPresenceActivity(
      date: json['date'] as String? ?? '',
      segments: segmentsJson
          .map(
            (segment) =>
                PresenceSegment.fromJson(segment as Map<String, dynamic>),
          )
          .toList(),
      onlineSeconds: (json['onlineSeconds'] as num?)?.toInt() ?? 0,
      offlineSeconds: (json['offlineSeconds'] as num?)?.toInt() ?? 0,
      bootCount: (json['bootCount'] as num?)?.toInt() ?? 0,
    );
  }

  String get summaryLabel {
    final buffer = StringBuffer(
      'Online ${formatPresenceDuration(onlineSeconds)}'
      ' · Offline ${formatPresenceDuration(offlineSeconds)}',
    );
    if (bootCount > 0) {
      buffer.write(
        ' · $bootCount restart${bootCount == 1 ? '' : 's'}',
      );
    }
    return buffer.toString();
  }
}

class PresenceSegment {
  const PresenceSegment({
    required this.status,
    required this.start,
    required this.end,
    required this.durationSeconds,
  });

  final String status;
  final String start;
  final String end;
  final int durationSeconds;

  bool get isOnline => status == 'online';

  bool get isBoot => status == 'boot';

  factory PresenceSegment.fromJson(Map<String, dynamic> json) {
    return PresenceSegment(
      status: json['status'] as String? ?? 'offline',
      start: json['start'] as String? ?? '',
      end: json['end'] as String? ?? '',
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
    );
  }

  String get timeRangeLabel {
    final startLabel = _formatClock(start);
    final endLabel = _formatClock(end);
    return '$startLabel – $endLabel';
  }

  String get bootTimeLabel => _formatClock(start);

  static String _formatClock(String iso) {
    if (iso.length >= 19) {
      return iso.substring(11, 19);
    }
    if (iso.length >= 16) {
      return iso.substring(11, 16);
    }
    return iso;
  }
}

String formatPresenceDuration(int totalSeconds) {
  if (totalSeconds <= 0) {
    return '0 seconds';
  }
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  final parts = <String>[];
  if (hours > 0) {
    parts.add('$hours h');
  }
  if (minutes > 0) {
    parts.add('$minutes m');
  }
  if (seconds > 0 || parts.isEmpty) {
    parts.add('$seconds seconds');
  }
  return parts.join(' ');
}
