class TopConsumersDashboardConfig {
  const TopConsumersDashboardConfig({
    this.showOverall = true,
    this.showByBlock = true,
    this.showByWing = true,
    this.topCount = 5,
    this.wingViewBlock,
  });

  factory TopConsumersDashboardConfig.fromJson(Map<String, dynamic> json) {
    return TopConsumersDashboardConfig(
      showOverall: json['showOverall'] as bool? ?? true,
      showByBlock: json['showByBlock'] as bool? ?? true,
      showByWing: json['showByWing'] as bool? ?? true,
      topCount: json['topCount'] as int? ?? 5,
      wingViewBlock: json['wingViewBlock'] as String?,
    );
  }

  final bool showOverall;
  final bool showByBlock;
  final bool showByWing;
  final int topCount;
  final String? wingViewBlock;

  List<TopConsumersPageType> get enabledPages {
    final pages = <TopConsumersPageType>[];
    if (showOverall) pages.add(TopConsumersPageType.overall);
    if (showByBlock) pages.add(TopConsumersPageType.byBlock);
    if (showByWing) pages.add(TopConsumersPageType.byWing);
    if (pages.isEmpty) pages.add(TopConsumersPageType.overall);
    return pages;
  }

  Map<String, dynamic> toJson() => {
        'showOverall': showOverall,
        'showByBlock': showByBlock,
        'showByWing': showByWing,
        'topCount': topCount,
        if (wingViewBlock != null) 'wingViewBlock': wingViewBlock,
      };

  TopConsumersDashboardConfig copyWith({
    bool? showOverall,
    bool? showByBlock,
    bool? showByWing,
    int? topCount,
    String? wingViewBlock,
    bool clearWingViewBlock = false,
  }) {
    return TopConsumersDashboardConfig(
      showOverall: showOverall ?? this.showOverall,
      showByBlock: showByBlock ?? this.showByBlock,
      showByWing: showByWing ?? this.showByWing,
      topCount: topCount ?? this.topCount,
      wingViewBlock:
          clearWingViewBlock ? null : (wingViewBlock ?? this.wingViewBlock),
    );
  }
}

enum TopConsumersPageType {
  overall,
  byBlock,
  byWing,
}

extension TopConsumersPageTypeLabel on TopConsumersPageType {
  String get label {
    switch (this) {
      case TopConsumersPageType.overall:
        return 'All';
      case TopConsumersPageType.byBlock:
        return 'By block';
      case TopConsumersPageType.byWing:
        return 'By wing';
    }
  }
}
