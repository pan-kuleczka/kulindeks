# Capture runbook (repeat after every reboot)

Goal: MITM the mStudent (Flutter) app in Waydroid to record the real API traffic.
What's defeated: BoringSSL verify (native hook) + `http_certificate_pinning` Kotlin
plugin (Java hook) + Flutter's system-CA trust (mitmproxy CA installed as a root).

Persistent assets live in `runtime/` (gitignored): `frida-server` (17.19.0, android-x64),
`c8750f0d.0` (mitmproxy CA, Android-hashed), `agent/` (frida agent source + build).
Compiled agent: `tools/_agent.js`. Proxy CA on host: `~/.mitmproxy/`.

Everything below assumes paths under `/home/jerem/Projects/Studia/mstudent`.

## Order of operations

1. **Start Waydroid** (user, no sudo):
   ```
   waydroid session start      # or just: waydroid show-full-ui
   ```
   Wait until the home screen is up. Do NOT open mStudent yet.

2. **Terminal A — frida-server** (user, leave open):
   ```
   sudo bash tools/root_frida.sh
   ```
   Leaves frida-server running on 0.0.0.0:27042. If it exits, Waydroid wasn't ready — retry.

3. **Terminal B — redirect + CA** (user, returns):
   ```
   sudo bash tools/root_setup.sh
   ```
   Adds the nat REDIRECT (container 80/443/9090 -> host:8080), installs the mitmproxy
   CA as a system root, and force-stops the app. Should print `CA present: 1`.

4. **Terminal C — mitmproxy** (host, no sudo, leave open):
   ```
   bash tools/host_mitm.sh
   ```
   Transparent capture on :8080; writes redacted JSON to `captures/flows/`.
   (Run in a real terminal — the model's sandboxed shell can't keep it alive.)

5. **Open mStudent** to the login screen (user). Don't log in yet.

6. **Attach the bypass agent** (model/host):
   ```
   nix-shell -p 'python3.withPackages(ps:[ps.frida-python])' \
     --run 'python3 -u tools/mitm_attach.py --attach'
   ```
   Expect: `native ... hooked`, `java ... hooked ... checkConnection`.

7. **Log in and browse** every screen once (grades, GPA, timetable, finances,
   messages, notifications, lecturers, academic-year). Flows land in `captures/flows/`.

## Teardown (optional)
```
sudo bash tools/teardown_mitm_root.sh   # removes iptables rules + stops frida-server
```
The CA bind-mount and redirect vanish on reboot anyway.

## Notes / gotchas
- Host is NixOS: pip-frida's helper can't exec (no nix-ld) — always use the nix
  `frida-python` env for the attach, and `nix shell nixpkgs#mitmproxy` for the proxy.
- frida 17 dropped the built-in `Java` bridge; the agent bundles `frida-java-bridge`
  (rebuild: `cd runtime/agent && nix shell nixpkgs#nodejs --command npm run build`,
  then `cp _agent.js ../../tools/_agent.js`).
- The app process name is `mStudent`; the agent resolves the pid by package id.
- Android 13 (SDK 33). dart:io trusts `/system/etc/security/cacerts` (system roots).
