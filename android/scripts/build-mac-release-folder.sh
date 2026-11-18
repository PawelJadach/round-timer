#!/usr/bin/env bash
# Signed Play AAB into ~/round-timer-release using your existing upload key (not repo secrets).
set -euo pipefail

HOME_DIR="${HOME:?}"
REPO="${ROUND_TIMER_REPO:-$HOME_DIR/repos/round-timer}"
SIGNING="${ROUND_TIMER_SIGNING:-$HOME_DIR/round-timer-upload-signing.properties}"
KEYSTORE="${ROUND_TIMER_KEYSTORE:-$HOME_DIR/round-timer-upload.keystore}"
OUT_DIR="${ROUND_TIMER_OUT:-$HOME_DIR/round-timer-release}"

if [[ ! -f "$SIGNING" ]]; then
  echo "Brak pliku podpisu: $SIGNING" >&2
  exit 1
fi
if [[ ! -f "$KEYSTORE" ]]; then
  echo "Brak keystore: $KEYSTORE" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"
cd "$REPO"
git pull --ff-only origin main 2>/dev/null || git pull --ff-only || true

cp "$SIGNING" android/keystore.properties
if ! grep -q '^storeFile=' android/keystore.properties; then
  echo "storeFile=$KEYSTORE" >> android/keystore.properties
fi

cd android
./gradlew :app:bundleRelease --no-daemon

BUILT="app/build/outputs/bundle/release/app-release.aab"
VERSION_NAME=$(awk -F'"' '/versionName =/ {print $2; exit}' app/build.gradle.kts)
VERSION_CODE=$(awk -F' = ' '/versionCode =/ {print $2; exit}' app/build.gradle.kts)
DEST="$OUT_DIR/round-timer-${VERSION_NAME}-${VERSION_CODE}.aab"
cp "$BUILT" "$DEST"
ls -la "$DEST"
open -R "$DEST" 2>/dev/null || open "$OUT_DIR" 2>/dev/null || true
echo "Gotowe: $DEST"