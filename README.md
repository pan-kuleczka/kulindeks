# kulindeks

## AI disclosure
The project is quite obviously mostly vibe-coded. This may be a flaw to you, but in my opinion it is still better than the original client.
I have done my best to ensure it is as safe as possible. Approach with caution. 

## Contents
Two things live here:
1. **The reverse-engineered protocol** of Simple S.A.'s **mStudent** app
   (`com.simple.mSimple_Student`, Flutter/Dart), plus the tooling and capture rig
   used to recover it.
2. **kulindeks**, a cleaner replacement Flutter client built on that protocol (runs on Android and Linux desktop for now).

## Layout
| Path | What |
|---|---|
| `docs/protocol.md` | **The API reference** — discovery, auth (JWT), every endpoint, params, response shapes. Confirmed by live capture. |
| `docs/RUNBOOK.md` | How to reproduce the MITM capture in Waydroid (TLS + pinning bypass). |
| `tools/` | `discovery.py` (decrypt the university list), `mstudent_client.py` (standalone Python reference client), the frida agent + capture scripts. |
| `runtime/` | Persistent binaries for the capture rig (gitignored). |
| `captures/` | `colleges.json`, decoded flows, raw `raw.mitm` (gitignored). |
| `sync/` | Headless auto-sync of the timetable to Nextcloud (CalDAV) via cron/systemd. See `sync/README.md`. |
| `app/` | **Indeks** Flutter app (Dart client + UI; Android + Linux desktop). See `app/README.md`. |

## TL;DR of the protocol
- Universities + their API base URLs come from an XOR+base64 blob at
  `mlicenses.simple.com.pl/ifhavemstud.php` (key reversed from the binary).
- `POST {base}/api/auth` `{login,password,applicationName:"mStudent"}` → Bearer JWT
  + `studentId`/`authId`.
- Data at `{base}/automatic/rest/mStudent/bazus/wsrest/rest/edu/api/...` with
  `Authorization: Bearer <token>` and query params (`studentId`, `kierunekId`,
  `semestr`). Full list in `docs/protocol.md`.

## Quick starts
```bash
# Decode the university directory
python3 tools/discovery.py

# Pull your own data via the Python reference client
MST_LOGIN=you MST_PASSWORD=... python3 tools/mstudent_client.py --college umw --dump all

# Run the app (needs Flutter + Android SDK)
cd app && flutter pub get && flutter run
```

## How the capture was done
The app is Flutter (logic in `libapp.so`), so static strings gave the endpoint
map, and a Waydroid MITM gave the exact wire format. Three defenses had to fall:
Flutter's BoringSSL verify (frida native hook), the `http_certificate_pinning`
Kotlin plugin (frida Java hook on `checkConnection`), and system-CA trust
(mitmproxy CA bind-mounted as a root). All scripted under `tools/`; see
`docs/RUNBOOK.md`.

> Personal / educational project. Not affiliated with Simple S.A. or any
> university. Only ever used against the author's own account.
