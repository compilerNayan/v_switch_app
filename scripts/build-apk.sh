#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK_ROOT="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}"

if [[ -z "${JAVA_HOME:-}" ]] && [[ -x /usr/libexec/java_home ]]; then
  export JAVA_HOME="$(/usr/libexec/java_home -v 17 2>/dev/null || /usr/libexec/java_home)"
fi

export ANDROID_HOME="$SDK_ROOT"
export ANDROID_SDK_ROOT="$SDK_ROOT"

if [[ ! -f "$ROOT_DIR/local.properties" ]]; then
  echo "Creating local.properties -> $SDK_ROOT"
  echo "sdk.dir=$SDK_ROOT" > "$ROOT_DIR/local.properties"
fi

if [[ ! -d "$SDK_ROOT/platforms/android-34" ]]; then
  echo "Android SDK platform 34 not found."
  echo "Run: $ROOT_DIR/scripts/setup-android-sdk.sh"
  exit 1
fi

cd "$ROOT_DIR"
chmod +x ./gradlew
./gradlew assembleDebug --no-daemon

APK="$ROOT_DIR/app/build/outputs/apk/debug/app-debug.apk"
echo
echo "Build complete:"
echo "  $APK"
echo
echo "Install on a connected device:"
echo "  adb install -r \"$APK\""
