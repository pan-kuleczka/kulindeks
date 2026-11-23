#!/usr/bin/env bash
# Undo setup_mitm_root.sh. Run with: sudo bash tools/teardown_mitm_root.sh
set -uo pipefail
BRIDGE="waydroid0"; SUBNET="192.168.240.0/24"; MITM_PORT=8080; PORTS="80,443,9090"
iptables -t nat -D PREROUTING -i "$BRIDGE" -s "$SUBNET" -p tcp -m multiport --dports "$PORTS" -j REDIRECT --to-ports "$MITM_PORT" 2>/dev/null && echo "[-] removed REDIRECT" || true
iptables -D INPUT -i "$BRIDGE" -p tcp --dport "$MITM_PORT" -j ACCEPT 2>/dev/null && echo "[-] removed INPUT accept" || true
waydroid shell -- sh -c 'pkill -f frida-server' 2>/dev/null && echo "[-] stopped frida-server" || true
echo "[+] teardown complete"
