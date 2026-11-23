#!/usr/bin/env bash
# Build a release APK on NixOS (assembles an Android SDK + JDK via nix).
#   bash build_apk.sh        -> build/app/outputs/flutter-apk/app-release.apk
set -e
cd "$(dirname "$0")"
exec nix-shell android-shell.nix --run \
  'flutter pub get && flutter build apk --release --target-platform android-arm64 \
     && echo "APK -> build/app/outputs/flutter-apk/app-release.apk"'
