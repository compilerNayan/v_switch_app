import 'package:flutter_test/flutter_test.dart';
import 'package:water_meter_app/core/models/water_unit.dart';
import 'package:water_meter_app/core/utils/unit_filters.dart';

WaterUnit _unit({
  required String id,
  String block = '',
  String wing = '',
}) {
  return WaterUnit(
    id: id,
    name: id,
    deviceId: id,
    block: block,
    wing: wing,
  );
}

void main() {
  final units = [
    _unit(id: 'a1', block: 'A', wing: 'East'),
    _unit(id: 'a2', block: 'A', wing: 'West'),
    _unit(id: 'b1', block: 'B', wing: 'East'),
  ];

  test('applyLocationFilters by block', () {
    final result = applyLocationFilters(units, selectedBlocks: {'A'});
    expect(result.map((u) => u.id), ['a1', 'a2']);
  });

  test('applyLocationFilters by wing', () {
    final result = applyLocationFilters(units, selectedWings: {'East'});
    expect(result.map((u) => u.id), ['a1', 'b1']);
  });

  test('applyLocationFilters combines block and wing', () {
    final result = applyLocationFilters(
      units,
      selectedBlocks: {'A'},
      selectedWings: {'West'},
    );
    expect(result.map((u) => u.id), ['a2']);
  });

  test('distinct blocks and wings', () {
    expect(distinctBlocksFromUnits(units), ['A', 'B']);
    expect(distinctWingsFromUnits(units), ['East', 'West']);
    expect(distinctWingsFromUnits(units, blocks: {'A'}), ['East', 'West']);
    expect(distinctWingsFromUnits(units, blocks: {'B'}), ['East']);
  });

  test('unitMatchesSearch includes block and wing', () {
    expect(unitMatchesSearch(units.first, 'east'), isTrue);
    expect(unitMatchesSearch(units.first, 'block z'), isFalse);
  });
}
