class DailySummaryDay {
  const DailySummaryDay({
    required this.date,
    required this.totalLiters,
    required this.peakHour,
    required this.peakHourLiters,
  });

  factory DailySummaryDay.fromJson(Map<String, dynamic> json) {
    return DailySummaryDay(
      date: DateTime.parse(json['date'] as String),
      totalLiters: (json['totalLiters'] as num).toDouble(),
      peakHour: json['peakHour'] as int,
      peakHourLiters: (json['peakHourLiters'] as num).toDouble(),
    );
  }

  final DateTime date;
  final double totalLiters;
  final int peakHour;
  final double peakHourLiters;

  Map<String, dynamic> toJson() => {
        'date':
            '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        'totalLiters': totalLiters,
        'peakHour': peakHour,
        'peakHourLiters': peakHourLiters,
      };
}

class DailySummaryResponse {
  const DailySummaryResponse({
    required this.unit,
    required this.days,
  });

  factory DailySummaryResponse.fromJson(Map<String, dynamic> json) {
    return DailySummaryResponse(
      unit: json['unit'] as String,
      days: (json['days'] as List<dynamic>)
          .map((e) => DailySummaryDay.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  final String unit;
  final List<DailySummaryDay> days;

  Map<String, dynamic> toJson() => {
        'unit': unit,
        'days': days.map((d) => d.toJson()).toList(),
      };
}

class HourlyPatternHour {
  const HourlyPatternHour({
    required this.hour,
    required this.avgLiters,
  });

  factory HourlyPatternHour.fromJson(Map<String, dynamic> json) {
    return HourlyPatternHour(
      hour: json['hour'] as int,
      avgLiters: (json['avgLiters'] as num).toDouble(),
    );
  }

  final int hour;
  final double avgLiters;

  Map<String, dynamic> toJson() => {
        'hour': hour,
        'avgLiters': avgLiters,
      };
}

class HourlyPatternResponse {
  const HourlyPatternResponse({
    required this.unit,
    required this.hours,
  });

  factory HourlyPatternResponse.fromJson(Map<String, dynamic> json) {
    return HourlyPatternResponse(
      unit: json['unit'] as String,
      hours: (json['hours'] as List<dynamic>)
          .map((e) => HourlyPatternHour.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  final String unit;
  final List<HourlyPatternHour> hours;

  Map<String, dynamic> toJson() => {
        'unit': unit,
        'hours': hours.map((h) => h.toJson()).toList(),
      };
}
