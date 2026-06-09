import 'package:flutter_test/flutter_test.dart';

import 'package:water_meter_app/core/provisioning/provisioning_state.dart';

void main() {
  group('ProvisioningState', () {
    test('canEnroll requires wifi, tenant association, and metadata', () {
      const none = ProvisioningState();
      expect(none.canEnroll, isFalse);

      const wifiOnly = ProvisioningState(wifiConfigured: true);
      expect(wifiOnly.canEnroll, isFalse);

      const tenantOnly = ProvisioningState(tenantAssociated: true);
      expect(tenantOnly.canEnroll, isFalse);

      const metadataOnly = ProvisioningState(metadataComplete: true);
      expect(metadataOnly.canEnroll, isFalse);

      const wifiAndTenant = ProvisioningState(
        wifiConfigured: true,
        tenantAssociated: true,
      );
      expect(wifiAndTenant.canEnroll, isFalse);

      const ready = ProvisioningState(
        wifiConfigured: true,
        tenantAssociated: true,
        metadataComplete: true,
      );
      expect(ready.canEnroll, isTrue);

      final alreadyStarted = ready.copyWith(enrollStarted: true);
      expect(alreadyStarted.canEnroll, isFalse);
    });

    test('isEnrolling reflects enrollStarted without enrollComplete', () {
      const pending = ProvisioningState(
        enrollStarted: true,
        enrollComplete: false,
      );
      expect(pending.isEnrolling, isTrue);

      const done = ProvisioningState(
        enrollStarted: true,
        enrollComplete: true,
      );
      expect(done.isEnrolling, isFalse);
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
