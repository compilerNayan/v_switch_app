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

Map<String, List<UnitUsage>> topPerBlock(List<UnitUsage> items, int count) {
  final byBlock = <String, List<UnitUsage>>{};
  for (final item in items) {
    final block =
        item.unit.block.trim().isNotEmpty ? item.unit.block.trim() : 'Unassigned';
    byBlock.putIfAbsent(block, () => []).add(item);
  }
  return Map.fromEntries(
    byBlock.entries.map(
      (e) => MapEntry(e.key, takeTop(e.value, count)),
    ),
  );
}

Map<String, List<UnitUsage>> topPerWingInBlock(
  List<UnitUsage> items,
  String block,
  int count,
) {
  final filtered =
      items.where((i) => i.unit.block.trim() == block.trim()).toList();
  final byWing = <String, List<UnitUsage>>{};
  for (final item in filtered) {
    final wing =
        item.unit.wing.trim().isNotEmpty ? item.unit.wing.trim() : 'Unassigned';
    byWing.putIfAbsent(wing, () => []).add(item);
  }
  return Map.fromEntries(
    byWing.entries.map(
      (e) => MapEntry(e.key, takeTop(e.value, count)),
    ),
  );
}
