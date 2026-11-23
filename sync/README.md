# Auto-sync: timetable → Nextcloud

Two ways to get your plan into Nextcloud. The **app** already does one-shot CalDAV
pushes (Settings → *Synchronizuj plan teraz*). This folder is the **headless /
automatic** option for a server, NAS, or your always-on machine.

`nextcloud_sync.py` logs into the mStudent API, builds dated occurrences from your
timetable, and pushes each to a Nextcloud calendar over **CalDAV**. UIDs are
deterministic and **match the app's**, so running both never duplicates events —
whichever ran last wins, and re-runs just update.

## Prerequisites
- Python 3 (stdlib only — no pip installs).
- A Nextcloud **app password** (Nextcloud → Settings → Security → *Create new app
  password*). Never use your main password.

## Run once
```bash
MST_LOGIN=you MST_PASSWORD=... MST_COLLEGE=umw \
NC_URL=https://cloud.example.com NC_USER=you NC_PASS=app-password NC_CAL=kulindeks \
python3 sync/nextcloud_sync.py
```
Env vars: `MST_LOGIN`, `MST_PASSWORD`, `MST_COLLEGE` (name/url substring),
optional `MST_SEMESTER` (default: active); `NC_URL`, `NC_USER`, `NC_PASS`,
optional `NC_CAL` (default `kulindeks`). The calendar is created if missing.

## Mode A — automatic push on a timer (recommended)
Put the env in a root-600 file and run on a schedule.

`/etc/indeks-sync.env`:
```
MST_LOGIN=you
MST_PASSWORD=...
MST_COLLEGE=umw
NC_URL=https://cloud.example.com
NC_USER=you
NC_PASS=app-password
NC_CAL=kulindeks
```

systemd (`~/.config/systemd/user/` for a user service, or `/etc/systemd/system/`):

`indeks-sync.service`
```ini
[Unit]
Description=Sync mStudent timetable to Nextcloud
[Service]
Type=oneshot
EnvironmentFile=%h/.config/indeks-sync.env
ExecStart=/usr/bin/python3 %h/Projects/Studia/mstudent/sync/nextcloud_sync.py
```
`indeks-sync.timer`
```ini
[Unit]
Description=Sync mStudent timetable daily
[Timer]
OnCalendar=*-*-* 06:30:00
Persistent=true
[Install]
WantedBy=timers.target
```
```bash
systemctl --user enable --now indeks-sync.timer
```
Or cron: `30 6 * * * . /etc/indeks-sync.env; python3 .../sync/nextcloud_sync.py`.

## Mode B — ICS subscription (no CalDAV writes)
If you'd rather have Nextcloud *pull* an auto-refreshing feed: have this script
(or a tiny variant) write the full `.ics` to a path your web server exposes, then
in Nextcloud Calendar → *New subscription* point at that URL. Nextcloud refreshes
it periodically. Trade-off: the feed must be reachable by Nextcloud and you decide
its privacy (unguessable path, or auth at the web server). Mode A keeps everything
inside your Nextcloud account and is simpler to secure.

> Uses your own credentials against your own account. Keep the env file private.
