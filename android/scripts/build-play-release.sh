#!/usr/bin/env bash
# Build signed Google Play bundle (app-release.aab). Run from repo root on a Mac/Linux box with Android SDK.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ANDROID="$ROOT/android"
cd "$ANDROID"

if [[ ! -f keystore.properties ]]; then
  echo "Missing android/keystore.properties (see android/play/KEYSTORE.md)." >&2
  exit 1
fi

if [[ -z "${ANDROID_HOME:-}" && ! -f local.properties ]]; then
  echo "Set ANDROID_HOME or android/local.properties with sdk.dir=..." >&2
  exit 1
fi

./gradlew :app:bundleRelease --no-daemon
OUT="$ANDROID/app/build/outputs/bundle/release/app-release.aab"
if [[ -f "$OUT" ]]; then
  echo "OK: $OUT"
  ls -la "$OUT"
else
  echo "Build finished but AAB not found at $OUT" >&2
  exit 1
fi