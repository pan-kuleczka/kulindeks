#!/usr/bin/env bash
# Terminal A (leave open): stages + runs frida-server in the container.
#   sudo bash tools/root_frida.sh
set -e
RT="/home/jerem/Projects/Studia/mstudent/runtime"
DATA="/home/jerem/.local/share/waydroid/data"
install -m0755 "$RT/frida-server" "$DATA/local/tmp/frida-server"
waydroid shell -- sh -c 'pkill -f frida-server 2>/dev/null; sleep 1' || true
echo "[*] frida-server 17.19.0 -> 0.0.0.0:27042 (leave this terminal open; Ctrl-C to stop)"
exec waydroid shell -- /data/local/tmp/frida-server -l 0.0.0.0:27042
