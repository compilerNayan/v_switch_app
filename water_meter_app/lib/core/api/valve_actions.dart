import '../models/valve_state.dart';
import 'water_api_client.dart';

Future<ValveState> setDeviceValvePressure(
  WaterApiClient client,
  String deviceId,
  double percent,
) {
  return client.setValvePressure(
    deviceId,
    ValveUpdateRequest(pressurePercent: percent),
  );
}

Future<ValveState> restoreDeviceValvePressure(
  WaterApiClient client,
  String deviceId,
) {
  return client.setValvePressure(
    deviceId,
    const ValveUpdateRequest(action: 'restore'),
  );
}

Future<ValveState> toggleDeviceValve(
  WaterApiClient client,
  String deviceId,
  ValveState current,
) {
  if (current.isOff) {
    return restoreDeviceValvePressure(client, deviceId);
  }
  return setDeviceValvePressure(client, deviceId, 0);
}
