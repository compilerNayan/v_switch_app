import '../models/water_unit.dart';

List<WaterUnit> applyLocationFilters(
  List<WaterUnit> units, {
  Set<String> selectedBlocks = const {},
  Set<String> selectedWings = const {},
}) {
  var result = units;
  if (selectedBlocks.isNotEmpty) {
    result = result.where((u) => selectedBlocks.contains(u.block)).toList();
  }
  if (selectedWings.isNotEmpty) {
    result = result.where((u) => selectedWings.contains(u.wing)).toList();
  }
  return result;
}

List<String> distinctBlocksFromUnits(List<WaterUnit> units) {
  return units
      .map((u) => u.block.trim())
      .where((b) => b.isNotEmpty)
      .toSet()
      .toList()
    ..sort();
}

List<String> distinctWingsFromUnits(
  List<WaterUnit> units, {
  Set<String> blocks = const {},
}) {
  var filtered = units;
  if (blocks.isNotEmpty) {
    filtered = filtered.where((u) => blocks.contains(u.block)).toList();
  }
  return filtered
      .map((u) => u.wing.trim())
      .where((w) => w.isNotEmpty)
      .toSet()
      .toList()
    ..sort();
}

bool unitMatchesSearch(WaterUnit unit, String query) {
  if (query.isEmpty) return true;
  final q = query.toLowerCase();
  return unit.name.toLowerCase().contains(q) ||
      unit.flatNumber.toLowerCase().contains(q) ||
      unit.floor.toLowerCase().contains(q) ||
      unit.block.toLowerCase().contains(q) ||
      unit.wing.toLowerCase().contains(q) ||
      unit.deviceId.toLowerCase().contains(q);
}
