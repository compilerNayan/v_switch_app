import '../models/valve_state.dart';

double resolveRestorePressurePercent({
  required double cachedPressure,
  ValveState? current,
  double? telemetryOpenPercent,
  bool? telemetryIsOff,
}) {
  if (cachedPressure > 0) return cachedPressure;
  if (current != null && current.lastUserPressurePercent > 0) {
    return current.lastUserPressurePercent;
  }
  if (telemetryIsOff == false &&
      telemetryOpenPercent != null &&
      telemetryOpenPercent > 0) {
    return telemetryOpenPercent;
  }
  return 100;
}

double pressureBeforeTurningOff({
  ValveState? current,
  double? telemetryOpenPercent,
  bool? telemetryIsOff,
  required double cachedPressure,
}) {
  if (current != null && current.targetPressurePercent > 0) {
    return current.targetPressurePercent;
  }
  if (telemetryIsOff == false &&
      telemetryOpenPercent != null &&
      telemetryOpenPercent > 0) {
    return telemetryOpenPercent;
  }
  if (cachedPressure > 0) return cachedPressure;
  return 100;
}
