#!/usr/bin/env bash
# Terminal B (returns when done): traffic redirect + system CA + force-stop app.
#   sudo bash tools/root_setup.sh
set -e
RT="/home/jerem/Projects/Studia/mstudent/runtime"
DATA="/home/jerem/.local/share/waydroid/data"
BRIDGE="waydroid0"; SUBNET="192.168.240.0/24"; MITM_PORT=8080; PORTS="80,443,9090"; CERT="c8750f0d.0"

echo "[*] ip_forward + nat REDIRECT (container $PORTS -> mitmproxy:$MITM_PORT) ..."
sysctl -w net.ipv4.ip_forward=1 >/dev/null
iptables -t nat -C PREROUTING -i "$BRIDGE" -s "$SUBNET" -p tcp -m multiport --dports "$PORTS" -j REDIRECT --to-ports "$MITM_PORT" 2>/dev/null \
  || iptables -t nat -A PREROUTING -i "$BRIDGE" -s "$SUBNET" -p tcp -m multiport --dports "$PORTS" -j REDIRECT --to-ports "$MITM_PORT"
iptables -C INPUT -i "$BRIDGE" -p tcp --dport "$MITM_PORT" -j ACCEPT 2>/dev/null \
  || iptables -I INPUT 1 -i "$BRIDGE" -p tcp --dport "$MITM_PORT" -j ACCEPT

echo "[*] installing mitmproxy CA as a system root (bind-mount) ..."
install -m0644 "$RT/$CERT" "$DATA/local/tmp/$CERT"
waydroid shell -- sh -c '
CERT=c8750f0d.0
setenforce 0 2>/dev/null || true
D=/data/local/tmp/cacerts; rm -rf $D; mkdir -p $D
cp /system/etc/security/cacerts/* $D/ 2>/dev/null || true
cp /data/local/tmp/$CERT $D/
chmod 644 $D/*; chown 0:0 $D/* 2>/dev/null || true
chcon u:object_r:system_security_cacerts_file:s0 $D/* 2>/dev/null || chcon u:object_r:system_file:s0 $D/* 2>/dev/null || true
mount --bind $D /system/etc/security/cacerts
if [ -d /apex/com.android.conscrypt/cacerts ]; then
  A=/data/local/tmp/apexcacerts; rm -rf $A; mkdir -p $A
  cp /apex/com.android.conscrypt/cacerts/* $A/ 2>/dev/null || true
  cp /data/local/tmp/$CERT $A/; chmod 644 $A/*
  chcon u:object_r:system_file:s0 $A/* 2>/dev/null || true
  mount --bind $A /apex/com.android.conscrypt/cacerts 2>/dev/null || true
fi
echo -n "[+] CA present: "; ls /system/etc/security/cacerts/ | grep -c c8750f0d
'
echo "[*] force-stopping app so it reloads roots ..."
waydroid shell -- am force-stop com.simple.mSimple_Student || true
echo "[+] setup done. Open the app to the login screen; tell the model to attach."
