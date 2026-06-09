class TopConsumersDashboardConfig {
  const TopConsumersDashboardConfig({
    this.topCount = 5,
  });

  factory TopConsumersDashboardConfig.fromJson(Map<String, dynamic> json) {
    return TopConsumersDashboardConfig(
      topCount: json['topCount'] as int? ?? 5,
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
