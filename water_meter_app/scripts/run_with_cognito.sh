#!/usr/bin/env bash
# Run the app against real Cognito + water_meter_service Lambda API.
set -euo pipefail

FLUTTER="${FLUTTER:-/tmp/flutter-sdk/bin/flutter}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

cd "$ROOT"

exec "$FLUTTER" run \
  --dart-define=USE_MOCK_AUTH=false \
  --dart-define=USE_MOCK_API=false \
  --dart-define=USE_MOCK_PROVISIONING=false \
  --dart-define=API_BASE_URL=https://tkl8wm622f.execute-api.ap-south-1.amazonaws.com/Prod \
  --dart-define=COGNITO_USER_POOL_ID=ap-south-1_vm19Xv95r \
  --dart-define=COGNITO_CLIENT_ID=46865gj4jba5bp42cc04fo14k1 \
  --dart-define=COGNITO_REGION=ap-south-1 \
  --dart-define=LIVE_UPDATES_WS_URL=ws://water-meter-data-injection-env.eba-xxxxx.ap-south-1.elasticbeanstalk.com/ws/live \
  --dart-define=LIVE_UPDATES_ENABLED=true \
  "$@"
