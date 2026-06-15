#!/usr/bin/env bash
# Build and serve the web dashboard (sign-in, building home, unit dashboard + usage).
set -euo pipefail

FLUTTER="${FLUTTER:-flutter}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PORT="${PORT:-8080}"

cd "$ROOT"

"$FLUTTER" build web --release \
  --dart-define=USE_MOCK_AUTH=false \
  --dart-define=USE_MOCK_API=false \
  --dart-define=USE_MOCK_PROVISIONING=false \
  --dart-define=API_BASE_URL=http://water-meter-data-injection-env.eba-udmynr49.ap-south-1.elasticbeanstalk.com \
  --dart-define=COGNITO_USER_POOL_ID=ap-south-1_vm19Xv95r \
  --dart-define=COGNITO_CLIENT_ID=46865gj4jba5bp42cc04fo14k1 \
  --dart-define=COGNITO_REGION=ap-south-1 \
  --dart-define=LIVE_UPDATES_WS_URL=ws://water-meter-data-injection-env.eba-udmynr49.ap-south-1.elasticbeanstalk.com/ws/live \
  --dart-define=LIVE_UPDATES_ENABLED=true

echo ""
echo "Web dashboard built. Open http://localhost:${PORT}"
echo "Press Ctrl+C to stop."
echo ""

cd build/web
exec python3 -m http.server "$PORT"
