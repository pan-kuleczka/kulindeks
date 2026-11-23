#!/usr/bin/env bash
# Launch the built Linux desktop app on NixOS with the right runtime libs.
#   bash run_linux.sh
# (Build first with: bash build_linux.sh)
set -e
cd "$(dirname "$0")"
BIN="build/linux/x64/release/bundle/kulindeks"
if [ ! -x "$BIN" ]; then
  echo "Not built yet — run: bash build_linux.sh"; exit 1
fi
exec nix-shell -p gtk3 glib pango cairo gdk-pixbuf atk at-spi2-core \
  libepoxy harfbuzz pcre2 util-linux libGL libnotify --run '
    LP=""; for p in $buildInputs; do [ -d "$p/lib" ] && LP="$LP:$p/lib"; done
    export LD_LIBRARY_PATH="${LP#:}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    exec ./build/linux/x64/release/bundle/kulindeks
  '
