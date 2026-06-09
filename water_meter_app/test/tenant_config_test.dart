import 'package:flutter_test/flutter_test.dart';

import 'package:water_meter_app/core/models/tenant_config.dart';

void main() {
  test('parses wing objects with floorCount', () {
    final structure = TenantStructure.fromJson({
      'blocks': [
        {
          'id': 'B',
          'wings': [
            {'name': 'North', 'floorCount': 12},
          ],
        },
      ],
    });

    expect(structure.hasFloors, isTrue);
    expect(structure.floorCountForWing('B', 'North'), 12);
  });

  test('serializes wing objects', () {
    const structure = TenantStructure(
      blocks: [
        TenantBlock(
          id: 'A',
          label: 'Tower A',
          wings: [TenantWing(name: 'East', floorCount: 6)],
        ),
      ],
    );

    final json = structure.toJson();
    final wing = json['blocks'][0]['wings'][0] as Map<String, dynamic>;
    expect(wing['name'], 'East');
    expect(wing['floorCount'], 6);
  });
}
