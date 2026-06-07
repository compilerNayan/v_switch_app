import '../models/tariff_config.dart';
import '../models/water_unit.dart';
import '../api/water_api_client.dart';

class UnitReportRow {
  const UnitReportRow({
    required this.unit,
    required this.totalLiters,
    required this.estimatedCost,
    required this.dailyBreakdown,
  });

  final WaterUnit unit;
  final double totalLiters;
  final double estimatedCost;
  final Map<DateTime, double> dailyBreakdown;
}

class ReportBuilder {
  static Future<List<UnitReportRow>> buildMonthlyReport({
    required List<WaterUnit> units,
    required WaterApiClient client,
    required TariffConfig tariff,
    required DateTime from,
    required DateTime to,
    required String timezone,
  }) async {
    final rows = <UnitReportRow>[];

    for (final unit in units) {
      try {
        final daily = await client.getDailySummary(
          deviceId: unit.deviceId,
          from: from,
          to: to,
          timezone: timezone,
        );
        final breakdown = <DateTime, double>{};
        var total = 0.0;
        for (final day in daily.days) {
          breakdown[day.date] = day.totalLiters;
          total += day.totalLiters;
        }
        rows.add(UnitReportRow(
          unit: unit,
          totalLiters: total,
          estimatedCost: tariff.costForLiters(total),
          dailyBreakdown: breakdown,
        ));
      } catch (_) {
        rows.add(UnitReportRow(
          unit: unit,
          totalLiters: 0,
          estimatedCost: 0,
          dailyBreakdown: {},
        ));
      }
    }

    rows.sort((a, b) => b.totalLiters.compareTo(a.totalLiters));
    return rows;
  }

  static String toCsv(List<UnitReportRow> rows, TariffConfig tariff) {
    final buffer = StringBuffer('Unit,Flat,Floor,Total Liters,Cost (${tariff.currencySymbol})\n');
    for (final row in rows) {
      buffer.writeln(
        '"${row.unit.name}","${row.unit.flatNumber}","${row.unit.floor}",'
        '${row.totalLiters.toStringAsFixed(1)},${row.estimatedCost.toStringAsFixed(2)}',
      );
    }
    return buffer.toString();
  }
}
