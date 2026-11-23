// Minimal Flutter TLS-verify bypass for Android x86_64 (no Java bridge needed).
// Scans libflutter.so for ssl_verify_peer_cert / x509 verify prologues and
// forces the verification result to "OK". Patterns from NVISO disable-flutter-tls.
'use strict';
var PATTERNS = [
  { p: "55 41 57 41 56 41 55 41 54 53 50 49 89 F? 4? 8B ?? 4? 8B 4? 30 4C 8B ?? ?? 0? 00 00 4D 85 ?? 74 1? 4D 8B", ret: 0 },
  { p: "55 41 57 41 56 41 55 41 54 53 48 83 EC 18 49 89 FF 48 8B 1F 48 8B 43 30 4C 8B A0 28 02 00 00 4D 85 E4 74", ret: 0 },
  { p: "55 41 57 41 56 41 55 41 54 53 48 83 EC 18 49 89 FE 4C 8B 27 49 8B 44 24 30 48 8B 98 D0 01 00 00 48 85 DB", ret: 0 },
];
var m = Process.findModuleByName("libflutter.so");
if (!m) { console.log("[!] libflutter.so not loaded"); }
else {
  console.log("[+] libflutter.so @ " + m.base + " size " + m.size);
  var ranges = m.enumerateRanges("r-x");
  console.log("[ ] executable ranges: " + ranges.length);
  var hooked = 0;
  PATTERNS.forEach(function (entry, idx) {
    var total = 0;
    ranges.forEach(function (r) {
      try {
        var matches = Memory.scanSync(r.base, r.size, entry.p);
        matches.forEach(function (mm) {
          Interceptor.attach(mm.address, {
            onLeave: function (retval) { retval.replace(ptr(entry.ret)); }
          });
          hooked++; total++;
          console.log("[+] pattern " + idx + " hooked verify fn @ " + mm.address + " (force ret=" + entry.ret + ")");
        });
      } catch (e) { /* skip unreadable range */ }
    });
    console.log("[ ] pattern " + idx + " matches: " + total);
  });
  if (hooked === 0) console.log("[!] no verify function matched — TLS will still be validated");
  else console.log("[+] TLS verification disabled (" + hooked + " hook(s))");
}
