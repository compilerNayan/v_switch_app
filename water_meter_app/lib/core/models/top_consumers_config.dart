class TopConsumersDashboardConfig {
  const TopConsumersDashboardConfig({
    this.topCount = 3,
  });

  factory TopConsumersDashboardConfig.fromJson(Map<String, dynamic> json) {
    return TopConsumersDashboardConfig(
      topCount: json['topCount'] as int? ?? 3,
    );
  }

  final int topCount;

  Map<String, dynamic> toJson() => {
        'topCount': topCount,
      };

  TopConsumersDashboardConfig copyWith({
    int? topCount,
  }) {
    return TopConsumersDashboardConfig(
      topCount: topCount ?? this.topCount,
    );
  }
}
