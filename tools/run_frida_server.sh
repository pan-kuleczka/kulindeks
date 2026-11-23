#!/usr/bin/env bash
# Run in a DEDICATED terminal with sudo, and leave it running:
#   sudo bash tools/run_frida_server.sh
# Stages the version-matched frida-server into the container and runs it in the
# foreground (Ctrl-C to stop). Keep this terminal open during capture.
set -e
SC="/tmp/claude-1000/-home-jerem-Projects-Studia-mstudent/fa0365de-d72b-4e3f-b4dd-aa069f03c9fd/scratchpad"
install -m0755 "$SC/frida-server-17.19.0" /home/jerem/.local/share/waydroid/data/local/tmp/frida-server
waydroid shell -- sh -c 'pkill -f frida-server 2>/dev/null; sleep 1' || true
echo "[*] launching frida-server 17.19.0 on 0.0.0.0:27042 (leave this terminal open)"
exec waydroid shell -- /data/local/tmp/frida-server -l 0.0.0.0:27042
