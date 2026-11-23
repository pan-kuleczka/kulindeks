/// Minimal CalDAV client — enough to push timetable occurrences into a
/// Nextcloud calendar (idempotently, one resource per occurrence).
library;

import 'dart:convert';
import 'dart:io';

import '../state/settings.dart';
import '../ui/util.dart';
import 'models.dart';

class SyncResult {
  final int pushed;
  final int failed;
  final List<String> errors;
  SyncResult(this.pushed, this.failed, this.errors);
  bool get ok => failed == 0;
}

class CaldavClient {
  final NextcloudConfig cfg;
  final HttpClient _http;
  CaldavClient(this.cfg, {HttpClient? httpClient})
      : _http = httpClient ?? HttpClient();

  String get _base {
    final s = cfg.serverUrl.replaceAll(RegExp(r'/+$'), '');
    return '$s/remote.php/dav/calendars/${Uri.encodeComponent(cfg.username)}';
  }

  String get _collection => '$_base/${Uri.encodeComponent(cfg.calendar)}';

  String get _authHeader =>
      'Basic ${base64.encode(utf8.encode('${cfg.username}:${cfg.appPassword}'))}';

  void _auth(HttpClientRequest r) =>
      r.headers.set(HttpHeaders.authorizationHeader, _authHeader);

  /// Create the calendar collection if it doesn't already exist.
  Future<void> ensureCalendar() async {
    final req = await _http.openUrl('MKCALENDAR', Uri.parse('$_collection/'));
    _auth(req);
    req.headers.contentType = ContentType('application', 'xml', charset: 'utf-8');
    req.write('''<?xml version="1.0" encoding="utf-8"?>
<C:mkcalendar xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
  <D:set><D:prop>
    <D:displayname>${cfg.calendar}</D:displayname>
    <C:supported-calendar-component-set>
      <C:comp name="VEVENT"/>
    </C:supported-calendar-component-set>
  </D:prop></D:set>
</C:mkcalendar>''');
    final resp = await req.close();
    await resp.drain<void>();
    // 201 created; 405/412 => already exists; anything else is surfaced later.
  }

  /// PUT one occurrence as its own .ics resource (overwrites on re-sync).
  Future<void> _putOccurrence(ClassEvent e, DateTime day) async {
    final uid = occurrenceUid(e, day);
    final uri = Uri.parse('$_collection/$uid.ics');
    final req = await _http.openUrl('PUT', uri);
    _auth(req);
    req.headers.contentType = ContentType('text', 'calendar', charset: 'utf-8');
    req.write(vcalendarForOccurrence(e, day, uid: uid));
    final resp = await req.close();
    await resp.drain<void>();
    if (resp.statusCode >= 300) {
      throw HttpException('PUT $uid.ics -> ${resp.statusCode}');
    }
  }

  /// Push every occurrence in [byDay]. Returns counts + first few errors.
  Future<SyncResult> push(Map<DateTime, List<ClassEvent>> byDay) async {
    await ensureCalendar();
    var pushed = 0, failed = 0;
    final errors = <String>[];
    for (final entry in byDay.entries) {
      for (final e in entry.value) {
        try {
          await _putOccurrence(e, entry.key);
          pushed++;
        } catch (ex) {
          failed++;
          if (errors.length < 5) errors.add('$ex');
        }
      }
    }
    return SyncResult(pushed, failed, errors);
  }

  void close() => _http.close(force: true);
}
