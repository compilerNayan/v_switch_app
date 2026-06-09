import '../models/water_unit.dart';

typedef UnitUsage = ({WaterUnit unit, double liters});

List<UnitUsage> sortByUsageDesc(List<UnitUsage> items) {
  final copy = [...items];
  copy.sort((a, b) => b.liters.compareTo(a.liters));
  return copy;
}

List<UnitUsage> takeTop(List<UnitUsage> items, int count) {
  return sortByUsageDesc(items).take(count).toList();
}
