#!/usr/bin/env bash
# Build iOS release with production Cognito + API (same config as Android APK).
set -euo pipefail

FLUTTER="${FLUTTER:-/tmp/flutter-sdk/bin/flutter}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODE="${MODE:-device}" # device | ipa | simulator

cd "$ROOT"

COMMON_ARGS=(
  --dart-define=USE_MOCK_AUTH=false
  --dart-define=USE_MOCK_API=false
  --dart-define=USE_MOCK_PROVISIONING=false
  --dart-define=API_BASE_URL=http://water-meter-data-injection-env.eba-udmynr49.ap-south-1.elasticbeanstalk.com
  --dart-define=COGNITO_USER_POOL_ID=ap-south-1_vm19Xv95r
  --dart-define=COGNITO_CLIENT_ID=46865gj4jba5bp42cc04fo14k1
  --dart-define=COGNITO_REGION=ap-south-1
  --dart-define=LIVE_UPDATES_WS_URL=ws://water-meter-data-injection-env.eba-udmynr49.ap-south-1.elasticbeanstalk.com/ws/live
  --dart-define=LIVE_UPDATES_ENABLED=true
)

case "$MODE" in
  device)
    "$FLUTTER" build ios --release --no-codesign "${COMMON_ARGS[@]}"
    echo ""
    echo "Built: build/ios/iphoneos/Runner.app"
    echo "To install on iPhone: set up signing in Xcode, then run MODE=ipa $0"
    ;;
  ipa)
    "$FLUTTER" build ipa --release "${COMMON_ARGS[@]}"
    echo ""
    echo "IPA: build/ios/ipa/*.ipa"
    ;;
  simulator)
    "$FLUTTER" build ios --debug --simulator "${COMMON_ARGS[@]}"
    echo ""
    echo "Built: build/ios/iphonesimulator/Runner.app"
    ;;
  *)
    echo "Unknown MODE=$MODE (use device, ipa, or simulator)" >&2
    exit 1
    ;;
esac
