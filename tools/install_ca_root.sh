#!/usr/bin/env bash
# Install mitmproxy CA as a SYSTEM-trusted root in the Waydroid container so
# Flutter/dart:io trusts the proxy. Uses a bind-mount (no image modification).
# Run with: sudo bash tools/install_ca_root.sh
set -e
SC="/tmp/claude-1000/-home-jerem-Projects-Studia-mstudent/fa0365de-d72b-4e3f-b4dd-aa069f03c9fd/scratchpad"
DATA="/home/jerem/.local/share/waydroid/data"
CERT="c8750f0d.0"

echo "[*] staging $CERT into container ..."
install -m0644 "$SC/$CERT" "$DATA/local/tmp/$CERT"

echo "[*] installing into system trust store (bind-mount) ..."
waydroid shell -- sh -c '
CERT=c8750f0d.0
setenforce 0 2>/dev/null || true
D=/data/local/tmp/cacerts
rm -rf $D; mkdir -p $D
cp /system/etc/security/cacerts/* $D/ 2>/dev/null || true
cp /data/local/tmp/$CERT $D/
chmod 644 $D/*; chown 0:0 $D/* 2>/dev/null || true
chcon u:object_r:system_security_cacerts_file:s0 $D/* 2>/dev/null || \
  chcon u:object_r:system_file:s0 $D/* 2>/dev/null || true
mount --bind $D /system/etc/security/cacerts
# Android 14+/apex path (harmless if absent on 13)
if [ -d /apex/com.android.conscrypt/cacerts ]; then
  A=/data/local/tmp/apexcacerts; rm -rf $A; mkdir -p $A
  cp /apex/com.android.conscrypt/cacerts/* $A/ 2>/dev/null || true
  cp /data/local/tmp/$CERT $A/
  chmod 644 $A/*; chcon u:object_r:system_file:s0 $A/* 2>/dev/null || true
  mount --bind $A /apex/com.android.conscrypt/cacerts 2>/dev/null || true
fi
echo "[+] installed; entries matching our hash:"
ls -l /system/etc/security/cacerts/ | grep c8750f0d || echo "  (not listed?!)"
'
echo "[*] restarting the app so it reloads trusted roots ..."
waydroid shell -- sh -c 'am force-stop com.simple.mSimple_Student' || true
echo "[+] done. Reopen the app to the login screen; the model will re-attach frida."
