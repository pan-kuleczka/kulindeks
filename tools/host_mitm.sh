#!/usr/bin/env bash
# Terminal C (host, leave open): runs mitmproxy to record API traffic.
#   bash tools/host_mitm.sh        (no sudo needed)
# Captures land (password/tokens redacted) in captures/flows/.
cd "$(dirname "$0")/.."
exec nix shell nixpkgs#mitmproxy --command \
  mitmdump --mode transparent --showhost --set block_global=false \
           -w +captures/raw.mitm \
           -s tools/capture_addon.py
