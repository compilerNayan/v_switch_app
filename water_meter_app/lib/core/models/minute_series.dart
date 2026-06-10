class MinutesTodayResponse {
  const MinutesTodayResponse({
    required this.deviceId,
    required this.date,
    required this.timezone,
    required this.slotMinutes,
    required this.startAt,
    required this.v,
  });

  factory MinutesTodayResponse.fromJson(Map<String, dynamic> json) {
    return MinutesTodayResponse(
      deviceId: json['deviceId'] as String,
      date: json['date'] as String,
      timezone: json['timezone'] as String,
      slotMinutes: json['slotMinutes'] as int,
      startAt: json['startAt'] as String,
      v: (json['v'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList(),
    );
  }

  final String deviceId;
  final String date;
  final String timezone;
  final int slotMinutes;
  final String startAt;
  final List<double> v;
}

class MinutesDaySeries {
  const MinutesDaySeries({
    required this.date,
    required this.startAt,
    required this.v,
  });

  factory MinutesDaySeries.fromJson(Map<String, dynamic> json) {
    return MinutesDaySeries(
      date: json['date'] as String,
      startAt: json['startAt'] as String,
      v: (json['v'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList(),
    );
  }

  final String date;
  final String startAt;
  final List<double> v;
}

class MinutesHistoryResponse {
  const MinutesHistoryResponse({
    required this.deviceId,
    required this.timezone,
    required this.slotMinutes,
    required this.days,
  });

  factory MinutesHistoryResponse.fromJson(Map<String, dynamic> json) {
    return MinutesHistoryResponse(
      deviceId: json['deviceId'] as String,
      timezone: json['timezone'] as String,
      slotMinutes: json['slotMinutes'] as int,
      days: (json['days'] as List<dynamic>)
          .map((e) => MinutesDaySeries.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  final String deviceId;
  final String timezone;
  final int slotMinutes;
  final List<MinutesDaySeries> days;
}

class BuildingDailyEntry {
  const BuildingDailyEntry({
    required this.date,
    required this.totalLiters,
  });

  factory BuildingDailyEntry.fromJson(Map<String, dynamic> json) {
    return BuildingDailyEntry(
      date: json['date'] as String,
      totalLiters: (json['totalLiters'] as num).toDouble(),
    );
  }

  final String date;
  final double totalLiters;
}

class BuildingDailyResponse {
  const BuildingDailyResponse({
    required this.timezone,
    required this.days,
  });

  factory BuildingDailyResponse.fromJson(Map<String, dynamic> json) {
    return BuildingDailyResponse(
      timezone: json['timezone'] as String,
      days: (json['days'] as List<dynamic>)
          .map((e) => BuildingDailyEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  final String timezone;
  final List<BuildingDailyEntry> days;
}
