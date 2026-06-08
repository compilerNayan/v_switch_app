import 'package:flutter_test/flutter_test.dart';
import 'package:water_meter_app/core/models/water_unit.dart';
import 'package:water_meter_app/core/utils/top_consumers_rankings.dart';

WaterUnit _unit(String id, {String block = '', String wing = ''}) {
  return WaterUnit(
    id: id,
    name: id,
    deviceId: id,
    block: block,
    wing: wing,
  );
}

UnitUsage _usage(String id, double liters, {String block = '', String wing = ''}) {
  return (unit: _unit(id, block: block, wing: wing), liters: liters);
}

void main() {
  final items = [
    _usage('u1', 100, block: 'A', wing: 'East'),
    _usage('u2', 80, block: 'A', wing: 'West'),
    _usage('u3', 60, block: 'B', wing: 'East'),
    _usage('u4', 40, block: 'A', wing: 'East'),
  ];

  test('takeTop returns highest usage first', () {
    final top = takeTop(items, 2);
    expect(top.map((e) => e.unit.id), ['u1', 'u2']);
  });

  test('topPerBlock groups and ranks within block', () {
    final grouped = topPerBlock(items, 2);
    expect(grouped['A']!.map((e) => e.unit.id), ['u1', 'u2']);
    expect(grouped['B']!.map((e) => e.unit.id), ['u3']);
  });

  test('topPerWingInBlock groups by wing in selected block', () {
    final grouped = topPerWingInBlock(items, 'A', 2);
    expect(grouped['East']!.map((e) => e.unit.id), ['u1', 'u4']);
    expect(grouped['West']!.map((e) => e.unit.id), ['u2']);
  });
}
