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
  --dart-define=API_BASE_URL=https://w77kz2bjb5.execute-api.ap-south-1.amazonaws.com/Prod \
  --dart-define=COGNITO_USER_POOL_ID=ap-south-1_vm19Xv95r \
  --dart-define=COGNITO_CLIENT_ID=46865gj4jba5bp42cc04fo14k1 \
  --dart-define=COGNITO_REGION=ap-south-1 \
  "$@"
