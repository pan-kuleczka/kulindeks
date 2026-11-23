#!/usr/bin/env python3
"""Headless auto-sync: mStudent timetable -> Nextcloud calendar (CalDAV).

Reuses the reference client in ../tools/mstudent_client.py. Logs in, fetches the
timetable for the active semester, expands weekly entries into dated occurrences,
and PUTs each as its own .ics resource (idempotent — stable UIDs, so re-runs
update rather than duplicate). Run it from cron or a systemd timer.

Config via environment:
  MST_LOGIN, MST_PASSWORD, MST_COLLEGE        (e.g. umw)
  MST_SEMESTER         optional; default = active semester
  NC_URL               https://cloud.example.com
  NC_USER, NC_PASS     Nextcloud user + APP PASSWORD (not the main password)
  NC_CAL               calendar collection name (default: kulindeks)

Example:
  MST_LOGIN=you MST_PASSWORD=... MST_COLLEGE=umw \
  NC_URL=https://cloud.example.com NC_USER=you NC_PASS=app-pw \
  python3 sync/nextcloud_sync.py
"""
import base64
import datetime as dt
import os
import sys
import urllib.request
import importlib.util

HERE = os.path.dirname(os.path.abspath(__file__))

# import the reference client without needing it on PYTHONPATH
_spec = importlib.util.spec_from_file_location(
    "mstudent_client", os.path.join(HERE, "..", "tools", "mstudent_client.py"))
mst = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(mst)

POLISH_DAYS = ["poniedziałek", "wtorek", "środa", "czwartek",
               "piątek", "sobota", "niedziela"]


def env(name, default=None, required=False):
    v = os.environ.get(name, default)
    if required and not v:
        sys.exit(f"missing required env {name}")
    return v


def fnv1a(s: str) -> str:
    h = 0x811c9dc5
    for c in s.encode("utf-8"):
        h = ((h ^ c) * 0x01000193) & 0xFFFFFFFF
    return f"indeks-{h:08x}@mstudent"


def parse_date(s):
    """bazus plan dates are DD-MM-YYYY; fall back to ISO."""
    if not s:
        return None
    import re
    m = re.match(r"^(\d{1,2})[-./](\d{1,2})[-./](\d{4})", s.strip())
    if m:
        return dt.date(int(m[3]), int(m[2]), int(m[1]))
    try:
        return dt.date.fromisoformat(s[:10])
    except ValueError:
        return None


def hhmm(s):
    import re
    m = re.search(r"(\d{1,2})[:.](\d{2})", s or "")
    return (int(m[1]), int(m[2])) if m else (0, 0)


def occurrences(events):
    """Yield (event, date) for every weekly occurrence within its date range."""
    for e in events:
        start = parse_date(e.get("odDzien"))
        if not start:
            continue
        end = parse_date(e.get("doDzien")) or start
        day_name = (e.get("dzienTygodnia") or "").strip().lower()
        if day_name in POLISH_DAYS:
            wd = POLISH_DAYS.index(day_name)  # 0=Mon
            cur = start
            while cur.weekday() != wd:
                cur += dt.timedelta(days=1)
            while cur <= end:
                yield e, cur
                cur += dt.timedelta(days=7)
        else:
            yield e, start


def ics_escape(s):
    return (s or "").replace("\\", "\\\\").replace(",", "\\,").replace(";", "\\;")


def abbrev_type(t):
    s = (t or "").lower()
    if "wychowania fizycznego" in s or ("fizyczn" in s and "wych" in s):
        return "WF"
    if "laboratoryjne" in s:
        return "CL"
    if "niekliniczne" in s:
        return "CN"
    if "symulowan" in s:
        return "CS"
    if "seminarium" in s:
        return "SEM"
    if "lektorat" in s:
        return "LEK"
    if "wykład" in s or "wyklad" in s:
        return "WYK"
    if "ćwiczenia" in s or "cwiczenia" in s:
        return "CW"
    return t or ""


def vcalendar(e, day, uid):
    sh, sm = hhmm(e.get("odGodzina"))
    eh, em = hhmm(e.get("doGodzina"))
    start = dt.datetime(day.year, day.month, day.day, sh, sm)
    end = dt.datetime(day.year, day.month, day.day, eh, em)
    stamp = dt.datetime.utcnow().strftime("%Y%m%dT%H%M%SZ")
    fmt = lambda d: d.strftime("%Y%m%dT%H%M%S")
    loc = f"{e.get('sala','')} {e.get('salaAdres','')}".strip()
    lecturer = " ".join(x for x in [e.get("tytul"), e.get("imie"), e.get("nazwisko")] if x)
    desc = " — ".join(x for x in [e.get("typPrzedmiotu"), lecturer, e.get("temat")] if x)
    return "\r\n".join([
        "BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//kulindeks//sync//PL",
        "BEGIN:VEVENT", f"UID:{uid}", f"DTSTAMP:{stamp}",
        f"DTSTART:{fmt(start)}", f"DTEND:{fmt(end)}",
        f"SUMMARY:{ics_escape(e.get('przedmiot'))} ({ics_escape(abbrev_type(e.get('typPrzedmiotu')))})",
        f"LOCATION:{ics_escape(loc)}", f"DESCRIPTION:{ics_escape(desc)}",
        "END:VEVENT", "END:VCALENDAR", "",
    ])


class Caldav:
    def __init__(self, url, user, password, calendar):
        self.base = url.rstrip("/") + f"/remote.php/dav/calendars/{user}"
        self.collection = f"{self.base}/{calendar}"
        self.auth = "Basic " + base64.b64encode(f"{user}:{password}".encode()).decode()

    def _req(self, method, url, body=None, ctype=None):
        headers = {"Authorization": self.auth}
        if ctype:
            headers["Content-Type"] = ctype
        data = body.encode("utf-8") if body else None
        req = urllib.request.Request(url, data=data, method=method, headers=headers)
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                return r.status
        except urllib.error.HTTPError as ex:
            return ex.code

    def ensure_calendar(self):
        body = ('<?xml version="1.0" encoding="utf-8"?>'
                '<C:mkcalendar xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">'
                '<D:set><D:prop>'
                '<C:supported-calendar-component-set><C:comp name="VEVENT"/>'
                '</C:supported-calendar-component-set></D:prop></D:set></C:mkcalendar>')
        self._req("MKCALENDAR", self.collection + "/", body, "application/xml")

    def put(self, uid, ics):
        return self._req("PUT", f"{self.collection}/{uid}.ics", ics, "text/calendar")


def main():
    login = env("MST_LOGIN", required=True)
    password = env("MST_PASSWORD", required=True)
    college = env("MST_COLLEGE", required=True)
    nc = Caldav(env("NC_URL", required=True), env("NC_USER", required=True),
                env("NC_PASS", required=True), env("NC_CAL", "kulindeks"))

    col = mst.pick_college(mst.discover(), college)
    c = mst.Client(col["simpleCoreURL"])
    c.login(login, password)

    # active semester
    sem = env("MST_SEMESTER")
    if not sem:
        ks = c.kierunki()
        if ks:
            sems = c.semestry(ks[0]["id"])
            active = next((s for s in sems if s.get("aktywny")), sems[-1] if sems else None)
            sem = active["semestr"] if active else 1
        else:
            sem = 1
    events = c.plan(int(sem))
    print(f"[sync] {len(events)} timetable entries, semester {sem}", file=sys.stderr)

    nc.ensure_calendar()
    pushed = failed = 0
    for e, day in occurrences(events):
        grupa = e.get("grupa") or e.get("grupas") or ""
        uid = fnv1a(f"{e.get('przedmiot') or ''}|{e.get('typPrzedmiotu') or ''}|{grupa}|"
                    f"{day.year}-{day.month}-{day.day}|{e.get('odGodzina') or ''}")
        status = nc.put(uid, vcalendar(e, day, uid))
        if status < 300:
            pushed += 1
        else:
            failed += 1
            print(f"[sync] PUT {uid} -> {status}", file=sys.stderr)
    print(f"[sync] done: pushed {pushed}, failed {failed}")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
