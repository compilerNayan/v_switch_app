#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter SDK not found. Install from https://docs.flutter.dev/get-started/install"
  exit 1
fi

if [ ! -d android ] || [ ! -d ios ]; then
  echo "Generating Android/iOS platform folders..."
  flutter create . --project-name water_meter_app --org com.vswitch
fi

flutter pub get
echo "Setup complete. Run: flutter run"
