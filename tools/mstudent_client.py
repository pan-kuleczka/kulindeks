#!/usr/bin/env python3
"""Standalone mStudent API client (no app, no Flutter, no pinning).

Implements the reverse-engineered protocol: university discovery, login, and the
student/timetable/finance/message endpoints. Pure stdlib.

Usage:
    MST_LOGIN=you MST_PASSWORD=secret python3 tools/mstudent_client.py \
        --college "Wroclawiu" [--dump grades|plan|finance|messages|info|all]

Credentials are read from env (MST_LOGIN / MST_PASSWORD) or prompted; they are
never printed. Pick the college by a substring of its name or its base URL.
"""
import argparse, base64, getpass, json, os, sys, urllib.request, urllib.parse

DISCOVERY = "https://mlicenses.simple.com.pl/ifhavemstud.php"
XOR_KEY = b"921A2C25-B544-4328-BE47-527D63ED6374"
UA = "mstudent-client/0.1"


def _get(url, headers=None, data=None, method=None):
    req = urllib.request.Request(url, data=data, method=method,
                                 headers={"User-Agent": UA, **(headers or {})})
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.status, r.read()


def discover():
    _, raw = _get(DISCOVERY)
    raw += b"=" * (-len(raw) % 4)
    dec = base64.b64decode(raw)
    plain = bytes(c ^ XOR_KEY[i % len(XOR_KEY)] for i, c in enumerate(dec))
    return json.loads(plain)


def pick_college(colleges, needle):
    n = needle.lower()
    for c in colleges:
        if n in c["collegeName"].lower() or n in c["simpleCoreURL"].lower():
            return c
    sys.exit(f"no college matching {needle!r}; options:\n" +
             "\n".join(f"  {c['simpleCoreURL']}  {c['collegeName']}" for c in colleges))


class Client:
    def __init__(self, base):
        self.base = base.rstrip("/")
        self.core = f"{self.base}/automatic/rest/mStudent/bazus/wsrest/rest"
        self.token = None
        self.student_id = None
        self.auth_id = None

    def login(self, login, password):
        body = json.dumps({"login": login, "password": password,
                           "applicationName": "mStudent"}).encode()
        st, raw = _get(f"{self.base}/api/auth", {"Content-Type": "application/json",
                                                 "Accept": "application/json"},
                       data=body, method="POST")
        d = json.loads(raw)
        self.token = d["access_token"]
        for src in d.get("availableDataSources", []):
            for i in src.get("identifiers", []):
                if i["type"] == "STUDENT_ID":
                    self.student_id = i["identifier"]
                elif i["type"] == "BAZUS_USER_ID":
                    self.auth_id = i["identifier"]
        return d

    def _call(self, path, **params):
        url = f"{self.core}/{path}"
        if params:
            url += "?" + urllib.parse.urlencode(params)
        st, raw = _get(url, {"Authorization": f"Bearer {self.token}",
                             "Accept": "application/json"})
        d = json.loads(raw)
        return d.get("result", d) if isinstance(d, dict) else d

    # --- endpoints ---
    def info(self):
        return self._call("edu/api/student/infoByAuthIdWithPhoto", authId=self.auth_id)

    def kierunki(self):
        return self._call("edu/api/student/kierunkiByStudentId", studentId=self.student_id)

    def semestry(self, kierunek_id):
        return self._call("edu/api/student/semestryByStudentIdAndKierunekId",
                          studentId=self.student_id, kierunekId=kierunek_id)

    def grades(self, kierunek_id, semestr):
        return self._call("edu/api/student/ocenyStudentaByStudentAndKierunekAndSemestr",
                          studentId=self.student_id, kierunekId=kierunek_id, semestr=semestr)

    def plan(self, semestr):
        return self._call("edu/api/planZajec/planBySemestrAndZalogowany", semestr=semestr)

    def naleznosci(self):
        return self._call("edu/api/student/finanseNaleznosciByStudentId", studentId=self.student_id)

    def messages(self, box="Odebrane"):
        return self._call(f"wiadomosci/grids/wiadomosci{box}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--college", required=True, help="name/url substring")
    ap.add_argument("--dump", default="info",
                    choices=["info", "grades", "plan", "finance", "messages", "all"])
    a = ap.parse_args()

    login = os.environ.get("MST_LOGIN") or input("login: ")
    password = os.environ.get("MST_PASSWORD") or getpass.getpass("password: ")

    col = pick_college(discover(), a.college)
    print(f"# {col['collegeName']}\n# {col['simpleCoreURL']}", file=sys.stderr)
    c = Client(col["simpleCoreURL"])
    c.login(login, password)
    print(f"# studentId={c.student_id} authId={c.auth_id}", file=sys.stderr)

    out = {}
    ks = c.kierunki()
    out["kierunki"] = ks
    kid = ks[0]["id"] if ks else None
    sem = None
    if kid is not None:
        sems = c.semestry(kid)
        out["semestry"] = sems
        sem = next((s["semestr"] for s in sems if s.get("aktywny")), sems[-1]["semestr"] if sems else 1)

    if a.dump in ("info", "all"):
        out["info"] = c.info()
    if a.dump in ("grades", "all") and kid is not None:
        out["grades"] = c.grades(kid, sem)
    if a.dump in ("plan", "all"):
        out["plan"] = c.plan(sem or 1)
    if a.dump in ("finance", "all"):
        out["finance"] = c.naleznosci()
    if a.dump in ("messages", "all"):
        out["messages"] = c.messages()

    json.dump(out, sys.stdout, ensure_ascii=False, indent=2)
    print()


if __name__ == "__main__":
    main()
