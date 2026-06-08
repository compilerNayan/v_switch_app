import 'package:flutter_test/flutter_test.dart';

import 'package:water_meter_app/core/provisioning/provisioning_state.dart';

void main() {
  group('ProvisioningState', () {
    test('canEnroll requires wifi and tenant association', () {
      const none = ProvisioningState();
      expect(none.canEnroll, isFalse);

      const wifiOnly = ProvisioningState(wifiConfigured: true);
      expect(wifiOnly.canEnroll, isFalse);

      const tenantOnly = ProvisioningState(tenantAssociated: true);
      expect(tenantOnly.canEnroll, isFalse);

      const ready = ProvisioningState(
        wifiConfigured: true,
        tenantAssociated: true,
      );
      expect(ready.canEnroll, isTrue);
    });

    test('setDeviceSerial resets provisioning flags', () {
      const state = ProvisioningState(
        deviceSerial: 'OLD',
        wifiConfigured: true,
        tenantAssociated: true,
      );
      final updated = state.copyWith(
        deviceSerial: 'NEW',
        resetProvisioningFlags: true,
      );
      expect(updated.deviceSerial, 'NEW');
      expect(updated.wifiConfigured, isFalse);
      expect(updated.tenantAssociated, isFalse);
    });
  });
}
