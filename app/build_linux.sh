#!/usr/bin/env bash
# Build the Linux desktop app on NixOS. Then launch with: bash run_linux.sh
set -e
cd "$(dirname "$0")"
exec nix-shell -p flutter cmake ninja pkg-config gtk3 clang libnotify --run \
  'flutter pub get && flutter build linux --release && echo "OK -> build/linux/x64/release/bundle/kulindeks"'
