class ScheduleRule {
  const ScheduleRule({
    required this.id,
    required this.name,
    required this.startHour,
    required this.endHour,
    required this.pressureCapPercent,
    this.enabled = true,
  });

  factory ScheduleRule.fromJson(Map<String, dynamic> json) {
    return ScheduleRule(
      id: json['id'] as String,
      name: json['name'] as String,
      startHour: json['startHour'] as int,
      endHour: json['endHour'] as int,
      pressureCapPercent: (json['pressureCapPercent'] as num).toDouble(),
      enabled: json['enabled'] as bool? ?? true,
    );
  }

  static const defaultNightRule = ScheduleRule(
    id: 'night_reduction',
    name: 'Night reduction (11pm–6am)',
    startHour: 23,
    endHour: 6,
    pressureCapPercent: 50,
  );

  final String id;
  final String name;
  final int startHour;
  final int endHour;
  final double pressureCapPercent;
  final bool enabled;

  bool isActiveAt(DateTime now) {
    if (!enabled) return false;
    final hour = now.hour;
    if (startHour < endHour) {
      return hour >= startHour && hour < endHour;
    }
    return hour >= startHour || hour < endHour;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'startHour': startHour,
        'endHour': endHour,
        'pressureCapPercent': pressureCapPercent,
        'enabled': enabled,
      };

  ScheduleRule copyWith({
    bool? enabled,
    double? pressureCapPercent,
  }) {
    return ScheduleRule(
      id: id,
      name: name,
      startHour: startHour,
      endHour: endHour,
      pressureCapPercent: pressureCapPercent ?? this.pressureCapPercent,
      enabled: enabled ?? this.enabled,
    );
  }
}
