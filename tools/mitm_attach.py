#!/usr/bin/env python3
"""Connect to frida-server in Waydroid, (re)spawn the mStudent app, inject the
Flutter TLS-disable script, and keep running so traffic flows to mitmproxy.

Usage: python tools/mitm_attach.py [--attach]
  default : spawn the app fresh (best for capturing the login handshake)
  --attach: attach to the already-running app instead
"""
import sys, time, frida

HOST = "192.168.240.112:27042"
PKG = "com.simple.mSimple_Student"
SCRIPT = __file__.rsplit("/", 1)[0] + "/_agent.js"

def on_message(msg, data):
    if msg.get("type") == "error":
        print("[script error]", msg.get("stack") or msg.get("description"))
    else:
        p = msg.get("payload")
        if isinstance(p, dict) and p.get("t") == "log":
            print(p.get("m"))
        else:
            print("[script]", p)

def main():
    attach = "--attach" in sys.argv
    dev = frida.get_device_manager().add_remote_device(HOST)
    code = open(SCRIPT, encoding="utf-8").read()
    pid = None
    if attach:
        apps = {a.identifier: a.pid for a in dev.enumerate_applications()}
        target = apps.get(PKG, 0)
        if not target:
            print(f"[!] {PKG} is not running — open it first"); sys.exit(1)
        print(f"[*] attaching to running {PKG} (pid {target})")
        session = dev.attach(target)
    else:
        print(f"[*] spawning {PKG}")
        pid = dev.spawn([PKG])
        session = dev.attach(pid)
    script = session.create_script(code)
    script.on("message", on_message)
    script.load()
    print("[+] TLS-disable script loaded")
    if pid is not None:
        dev.resume(pid)
        print("[+] resumed app — log in now")
    print("[i] Ctrl-C to stop. Watching...")
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("\n[*] detaching")
        session.detach()

if __name__ == "__main__":
    main()
