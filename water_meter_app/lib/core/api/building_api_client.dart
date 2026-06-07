class BuildingSummary {
  const BuildingSummary({
    required this.totalTodayLiters,
    required this.totalMonthLiters,
    required this.unitsOnline,
    required this.unitsOffline,
    required this.unitsTotal,
    required this.activeAlerts,
    required this.topConsumers,
  });

  final double totalTodayLiters;
  final double totalMonthLiters;
  final int unitsOnline;
  final int unitsOffline;
  final int unitsTotal;
  final int activeAlerts;
  final List<({String unitId, String name, double liters})> topConsumers;
}

class BuildingRanking {
  const BuildingRanking({
    required this.unitId,
    required this.name,
    required this.liters,
    required this.quotaPercent,
  });

  final String unitId;
  final String name;
  final double liters;
  final double? quotaPercent;
}

abstract class BuildingApiClient {
  Future<BuildingSummary> getSummary({required String tenantId});
  Future<List<BuildingRanking>> getRankings({
    required String tenantId,
    required String period,
  });
}
