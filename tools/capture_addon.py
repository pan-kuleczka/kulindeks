"""mitmproxy addon: record mStudent API traffic to readable JSON files.

Robust + self-diagnosing: writes a load marker, logs every flow host it sees,
and logs any per-flow exception. Redacts credentials/tokens before disk.
Run via: mitmdump --mode transparent -s tools/capture_addon.py
"""
import json, os, re, time, traceback

BASE = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "captures"))
OUT = os.path.join(BASE, "flows")
JSONL = os.path.join(BASE, "flows.jsonl")
SEEN = os.path.join(BASE, "seen_hosts.log")
ERRLOG = os.path.join(BASE, "addon_errors.log")
os.makedirs(OUT, exist_ok=True)

# backend hosts we care about (university backends + simple.com.pl)
HOST_RE = re.compile(r"(simple\.com\.pl|edu\.pl|\.study|varsovia|uniwersytetkaliski|"
                     r"collegiumwitelona|gwsh|ansbb|filmschool|ewspa|sopocka|pansjar|"
                     r"pans\b|mazowiecka)", re.I)
SECRET_KEYS = re.compile(r"(pass(word|wd)?|haslo|secret|pin|authchallenge)", re.I)
_n = 0


def load(loader):
    try:
        with open(os.path.join(BASE, "addon_loaded.txt"), "w") as f:
            f.write("capture_addon loaded at " + time.strftime("%Y-%m-%d %H:%M:%S") + "\n")
    except Exception:
        pass


def _log(path, line):
    try:
        with open(path, "a", encoding="utf-8") as f:
            f.write(line + "\n")
    except Exception:
        pass


def _redact(obj):
    if isinstance(obj, dict):
        return {k: ("***REDACTED***" if SECRET_KEYS.search(k) else _redact(v)) for k, v in obj.items()}
    if isinstance(obj, list):
        return [_redact(v) for v in obj]
    return obj


def _body(msg):
    try:
        raw = msg.get_text(strict=False)
    except Exception:
        raw = None
    if not raw:
        return None
    try:
        return _redact(json.loads(raw))
    except Exception:
        return raw[:20000]


def _hdrs(msg):
    out = {}
    try:
        for k, v in msg.headers.items():
            if k.lower() == "authorization":
                v = re.sub(r"(Basic|Bearer)\s+\S+", r"\1 ***REDACTED***", v)
            out[k] = v
    except Exception:
        pass
    return out


def response(flow):
    global _n
    host = flow.request.pretty_host or flow.request.host
    _log(SEEN, time.strftime("%H:%M:%S ") + flow.request.method + " " + host + flow.request.path.split("?")[0])
    if not HOST_RE.search(host):
        return
    try:
        _n += 1
        rec = {
            "ts": time.strftime("%Y-%m-%dT%H:%M:%S"),
            "method": flow.request.method,
            "url": flow.request.pretty_url,
            "host": host,
            "path": flow.request.path,
            "req_headers": _hdrs(flow.request),
            "req_body": _body(flow.request),
            "status": flow.response.status_code,
            "resp_headers": _hdrs(flow.response),
            "resp_body": _body(flow.response),
        }
        safe = re.sub(r"[^A-Za-z0-9]+", "_", flow.request.path.split("?")[0]).strip("_")[:80]
        with open(os.path.join(OUT, f"{_n:03d}_{flow.request.method}_{safe}.json"), "w", encoding="utf-8") as f:
            json.dump(rec, f, ensure_ascii=False, indent=2)
        with open(JSONL, "a", encoding="utf-8") as f:
            f.write(json.dumps(rec, ensure_ascii=False) + "\n")
        print(f"[capture] {flow.response.status_code} {flow.request.method} {host}{flow.request.path.split('?')[0]}")
    except Exception:
        _log(ERRLOG, "---- " + time.strftime("%H:%M:%S") + " on " + host + flow.request.path + "\n" + traceback.format_exc())
