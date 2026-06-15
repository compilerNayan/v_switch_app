#!/usr/bin/env bash
# Collect Flutter / auth logs from a connected Android device.
set -euo pipefail

OUT="${1:-/tmp/water_meter_app_logs.txt}"
echo "Writing logs to $OUT (Ctrl+C to stop)..."

adb logcat -c
adb logcat -v time \
  flutter:V \
  Amplify:V \
  AWSMobileClient:V \
  CognitoIdentityProvider:V \
  *:S \
  | tee "$OUT"
