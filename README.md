# Kulindeks

**An independent, open-source client for the mStudent university app's API** — plus
the reverse-engineering work and tooling used to recover that API.

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
![Platforms](https://img.shields.io/badge/platforms-Android%20%7C%20Linux-informational)

> Independent project. **Not affiliated with, endorsed by, or connected to
> Simple S.A. or any university.** "mStudent" is used only to name the API this
> app talks to. Use it with your own account against your own university.

Poland's **mStudent** app (by Simple S.A.) is a thin, closed Flutter client that
many universities use for grades, timetables, finances and messages. Kulindeks is
a cleaner, faster, open client for the same backend — built on a fully
reverse-engineered map of its API.

## AI disclosure

The project is quite obviously mostly vibe-coded. This may be a flaw to you, but
in my opinion it is still better than the original client. I have done my best to
ensure it is as safe as possible. Approach with caution.

---

## The app

A Flutter client for **Android and Linux desktop**:

- **Dashboard** — identity card, next class, GPA, outstanding dues, unread messages (every tile taps through to its section).
- **Timetable** — a real calendar with Day / Week / Month views, events laid out on a time grid, swipe navigation, room maps (the API returns room GPS), `.ics` export, and one-tap **Nextcloud (CalDAV) sync**.
- **Grades** — ECTS-weighted and arithmetic averages, color-coded, per programme/semester.
- **Finances** — dues and scholarships.
- **Messages** — inbox with read/unread and full message view.
- **Quality of life** — instant cached loads (refreshes in the background), light/dark/high-contrast themes, a custom accent color, adjustable font size, **Polish & English**, class reminders (local notifications), and a clear **offline** indicator that keeps showing cached data.

See [`app/README.md`](app/README.md) for build & run instructions, and the
[Releases](https://github.com/pan-kuleczka/kulindeks/releases) page for prebuilt APKs.

## The protocol

The API is documented from scratch in [`docs/protocol.md`](docs/protocol.md):
university discovery, JWT auth, and every endpoint with its parameters and
response shapes — confirmed against live traffic.

**TL;DR**
- Universities and their API base URLs come from an XOR+base64 blob at
  `mlicenses.simple.com.pl/ifhavemstud.php` (key recovered from the binary).
- `POST {base}/api/auth` `{login, password, applicationName:"mStudent"}` → a Bearer
  JWT plus the student's numeric IDs.
- Data lives under `{base}/automatic/rest/mStudent/bazus/wsrest/rest/edu/api/...`,
  authorized with `Authorization: Bearer <token>`.

[`tools/discovery.py`](tools/discovery.py) decrypts the university directory, and
[`tools/mstudent_client.py`](tools/mstudent_client.py) is a dependency-free Python
reference client you can run against your own account.

## Repository layout

| Path | What |
|---|---|
| `app/` | The Kulindeks Flutter app (Android + Linux). |
| `docs/protocol.md` | The reverse-engineered API reference. |
| `docs/RUNBOOK.md` | How the live capture was reproduced (Waydroid MITM, TLS + pinning bypass). |
| `tools/` | Discovery decryptor, Python reference client, and the capture rig. |
| `sync/` | Headless Nextcloud auto-sync daemon (CalDAV, cron/systemd). |

## Quick start

```bash
# Decode the university directory (no account needed)
python3 tools/discovery.py

# Pull your own data via the Python reference client
MST_LOGIN=you MST_PASSWORD=... python3 tools/mstudent_client.py --college umw --dump all

# Run the app from source (needs Flutter)
cd app && flutter pub get && flutter run
```

## Legal & privacy

- **Unofficial.** No affiliation with Simple S.A. or any university; no vendor
  branding, logos, or assets are redistributed here.
- **Your data stays yours.** The app talks only to your university's server with
  your own credentials and caches data locally on your device. Nothing is sent
  anywhere else; there is no analytics or telemetry.
- Credentials are stored on-device only (see [`app/README.md`](app/README.md)).

## License

[GNU GPL v3](LICENSE). You're free to use, study, modify and redistribute it;
distributed modified versions must also be open-sourced under the GPL.
