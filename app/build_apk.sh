#!/usr/bin/env bash
# Build release artifacts on NixOS (assembles an Android SDK + JDK + NDK via nix).
#   bash build_apk.sh            -> per-ABI APKs (arm64-v8a, armeabi-v7a, x86_64)
#   bash build_apk.sh universal  -> a single universal APK (all ABIs)
#   bash build_apk.sh aab        -> an Android App Bundle (.aab) for Google Play
# Outputs land in build/app/outputs/.
set -e
cd "$(dirname "$0")"
case "${1:-}" in
  universal) BUILD='flutter build apk --release' ;;
  aab)       BUILD='flutter build appbundle --release' ;;
  *)         BUILD='flutter build apk --release --split-per-abi' ;;
esac
exec nix-shell android-shell.nix --run \
  "flutter pub get && $BUILD && find build/app/outputs -name '*.apk' -o -name '*.aab' | sort"
