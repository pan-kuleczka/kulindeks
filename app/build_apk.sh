#!/usr/bin/env bash
# Build release APKs on NixOS (assembles an Android SDK + JDK + NDK via nix).
#   bash build_apk.sh            -> per-ABI APKs (arm64-v8a, armeabi-v7a, x86_64)
#   bash build_apk.sh universal  -> a single universal APK (all ABIs)
# Outputs land in build/app/outputs/flutter-apk/.
set -e
cd "$(dirname "$0")"

if [ "${1:-}" = "universal" ]; then
  BUILD='flutter build apk --release'
else
  BUILD='flutter build apk --release --split-per-abi'
fi

exec nix-shell android-shell.nix --run \
  "flutter pub get && $BUILD && ls -1 build/app/outputs/flutter-apk/*.apk"
