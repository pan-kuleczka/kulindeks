#!/usr/bin/env python3
"""Fetch & decrypt the mStudent university-discovery blob.

The app downloads a list of colleges (name, backend URL, branding, MFA flags)
from a static license endpoint. The body is XOR-encrypted (repeating key) then
base64-encoded. The key is a GUID hard-coded in libapp.so.
"""
import base64, json, sys, urllib.request

URL = "https://mlicenses.simple.com.pl/ifhavemstud.php"
KEY = b"921A2C25-B544-4328-BE47-527D63ED6374"  # from libapp.so

def xor(data: bytes, key: bytes) -> bytes:
    return bytes(c ^ key[i % len(key)] for i, c in enumerate(data))

def fetch_colleges():
    raw = urllib.request.urlopen(URL, timeout=30).read()
    pad = b"=" * (-len(raw) % 4)
    return json.loads(xor(base64.b64decode(raw + pad), KEY))

if __name__ == "__main__":
    cols = fetch_colleges()
    slim = [{k: v for k, v in c.items() if k != "emblem"} for c in cols]
    json.dump(slim, sys.stdout, ensure_ascii=False, indent=2)
    print()
