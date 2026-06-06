#!/usr/bin/env bash
set -euo pipefail

# Installs the Android SDK packages required to build v_switch_app from the CLI.
# Does not install Android Studio.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK_ROOT="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}"
CMDLINE_TOOLS="$SDK_ROOT/cmdline-tools/latest"

echo "Using Android SDK: $SDK_ROOT"

if [[ ! -x "$(command -v java)" ]]; then
  echo "ERROR: Java not found. Install JDK 17, e.g.: brew install openjdk@17"
  exit 1
fi

mkdir -p "$SDK_ROOT"

if [[ ! -x "$CMDLINE_TOOLS/bin/sdkmanager" ]]; then
  echo "Android command-line tools not found. Downloading..."
  TMP_ZIP="$(mktemp /tmp/cmdline-tools.XXXXXX.zip)"
  curl -fsSL -o "$TMP_ZIP" \
    "https://dl.google.com/android/repository/commandlinetools-mac-11076708_latest.zip"
  mkdir -p "$SDK_ROOT/cmdline-tools"
  unzip -q -o "$TMP_ZIP" -d "$SDK_ROOT/cmdline-tools"
  mv "$SDK_ROOT/cmdline-tools/cmdline-tools" "$CMDLINE_TOOLS"
  rm -f "$TMP_ZIP"
fi

export ANDROID_HOME="$SDK_ROOT"
export ANDROID_SDK_ROOT="$SDK_ROOT"
export PATH="$CMDLINE_TOOLS/bin:$PATH"

yes | sdkmanager --licenses >/dev/null
sdkmanager \
  "platform-tools" \
  "platforms;android-34" \
  "build-tools;34.0.0"

cat > "$ROOT_DIR/local.properties" <<EOF
sdk.dir=$SDK_ROOT
EOF

echo "SDK setup complete."
echo "Wrote $ROOT_DIR/local.properties"
