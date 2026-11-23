#!/usr/bin/env bash
# PRIVILEGED setup for MITM capture of the Waydroid mStudent app.
# Run with: sudo bash tools/setup_mitm_root.sh
# Does three things: (1) push+start frida-server in the container,
# (2) redirect container 80/443/9090 into mitmproxy on the host:8080,
# (3) allow those redirected packets in on the host firewall.
set -euo pipefail

SC="/tmp/claude-1000/-home-jerem-Projects-Studia-mstudent/fa0365de-d72b-4e3f-b4dd-aa069f03c9fd/scratchpad"
DATA="/home/jerem/.local/share/waydroid/data"
BRIDGE="waydroid0"
SUBNET="192.168.240.0/24"
MITM_PORT=8080
PORTS="80,443,9090"

echo "[*] Staging frida-server into container /data/local/tmp ..."
install -m0755 "$SC/frida-server" "$DATA/local/tmp/frida-server"

echo "[*] Starting frida-server in the container (listening on 0.0.0.0:27042) ..."
# kill any previous instance, then launch detached
waydroid shell -- sh -c 'pkill -f frida-server 2>/dev/null; sleep 1; \
  setsid /data/local/tmp/frida-server -l 0.0.0.0:27042 >/data/local/tmp/frida.log 2>&1 < /dev/null &' || true
sleep 2
waydroid shell -- sh -c 'ps -A | grep -i frida-server | grep -v grep' && echo "[+] frida-server running" || echo "[!] frida-server may not be running — check /data/local/tmp/frida.log"

echo "[*] Enabling ip_forward ..."
sysctl -w net.ipv4.ip_forward=1 >/dev/null

echo "[*] Installing nat REDIRECT (container -> mitmproxy:$MITM_PORT) ..."
iptables -t nat -C PREROUTING -i "$BRIDGE" -s "$SUBNET" -p tcp -m multiport --dports "$PORTS" -j REDIRECT --to-ports "$MITM_PORT" 2>/dev/null \
  || iptables -t nat -A PREROUTING -i "$BRIDGE" -s "$SUBNET" -p tcp -m multiport --dports "$PORTS" -j REDIRECT --to-ports "$MITM_PORT"

echo "[*] Allowing redirected packets in on the host firewall ..."
iptables -C INPUT -i "$BRIDGE" -p tcp --dport "$MITM_PORT" -j ACCEPT 2>/dev/null \
  || iptables -I INPUT 1 -i "$BRIDGE" -p tcp --dport "$MITM_PORT" -j ACCEPT

echo "[+] Done. Redirect rules:"
iptables -t nat -L PREROUTING -n --line-numbers | grep -E "$BRIDGE|REDIRECT" || true
echo "[i] mitmproxy must already be listening on $MITM_PORT (transparent mode)."
