// mStudent capture agent: defeat http_certificate_pinning + Flutter TLS verify.
import Java from 'frida-java-bridge';

function log(m) { send({ t: 'log', m: m }); }

// ---- 1) Java: force the pinning plugin to report a secure connection ----
function hookPinningPlugin() {
  Java.perform(function () {
    try {
      var Plugin = Java.use('diefferson.http_certificate_pinning.HttpCertificatePinningPlugin');
      // checkConnexion(String, List, Map, int, String): boolean  (private)
      var overloads = Plugin.checkConnection.overloads;
      overloads.forEach(function (ov) {
        ov.implementation = function () {
          log('[java] checkConnection() intercepted -> forcing true');
          return true;
        };
      });
      log('[java] hooked HttpCertificatePinningPlugin.checkConnection (' + overloads.length + ' overload(s))');
    } catch (e) {
      log('[java] plugin hook error: ' + e);
    }
  });
}

// ---- 2) Native: force Flutter BoringSSL cert verify to succeed (belt & braces) ----
var PATTERNS = [
  "55 41 57 41 56 41 55 41 54 53 50 49 89 F? 4? 8B ?? 4? 8B 4? 30 4C 8B ?? ?? 0? 00 00 4D 85 ?? 74 1? 4D 8B",
  "55 41 57 41 56 41 55 41 54 53 48 83 EC 18 49 89 FF 48 8B 1F 48 8B 43 30 4C 8B A0 28 02 00 00 4D 85 E4 74",
  "55 41 57 41 56 41 55 41 54 53 48 83 EC 18 49 89 FE 4C 8B 27 49 8B 44 24 30 48 8B 98 D0 01 00 00 48 85 DB"
];
function hookFlutterNative() {
  var m = Process.findModuleByName('libflutter.so');
  if (!m) { log('[native] libflutter.so not loaded'); return; }
  var ranges = m.enumerateRanges('r-x');
  var hooked = 0;
  PATTERNS.forEach(function (p, idx) {
    ranges.forEach(function (r) {
      try {
        Memory.scanSync(r.base, r.size, p).forEach(function (mm) {
          Interceptor.attach(mm.address, { onLeave: function (rv) { rv.replace(ptr(0)); } });
          hooked++;
          log('[native] pattern ' + idx + ' hooked @ ' + mm.address);
        });
      } catch (e) {}
    });
  });
  log('[native] flutter verify hooks: ' + hooked);
}

hookFlutterNative();
if (Java.available) hookPinningPlugin();
else log('[java] Java NOT available in this runtime');
