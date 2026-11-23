/// mStudent (bazus) API client — dependency-free (`dart:io`), works standalone
/// and inside Flutter on Android/iOS.
///
/// Design notes vs. the original app:
///  * One [AuthSession] held in memory; auto re-login on 401 or near-expiry
///    (the official app re-POSTs /api/auth constantly — we don't).
///  * Optional [onToken] callback so the UI layer can persist the session.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'models.dart';

/// Thrown for non-2xx responses.
class ApiException implements Exception {
  final int statusCode;
  final String path;
  final String? body;
  ApiException(this.statusCode, this.path, [this.body]);
  bool get isUnauthorized => statusCode == 401;
  @override
  String toString() => 'ApiException($statusCode $path): ${body ?? ''}';
}

/// Repeating-key XOR + base64 obfuscation used by the discovery endpoint.
const _discoveryUrl = 'https://mlicenses.simple.com.pl/ifhavemstud.php';
final _xorKey = ascii.encode('921A2C25-B544-4328-BE47-527D63ED6374');

class MStudentClient {
  final String baseUrl;
  final HttpClient _http;
  AuthSession? _session;
  String? _login;
  String? _password;

  /// Called whenever a fresh [AuthSession] is obtained (for persistence).
  void Function(AuthSession)? onToken;

  MStudentClient(String baseUrl, {HttpClient? httpClient})
      : baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), ''),
        _http = httpClient ?? HttpClient() {
    _http.userAgent = 'mstudent-client/0.1';
  }

  String get _core => '$baseUrl/automatic/rest/mStudent/bazus/wsrest/rest';
  AuthSession? get session => _session;

  // Endpoint paths (relative to _core) — single source of truth.
  static const epKierunki = 'edu/api/student/kierunkiByStudentId';
  static const epSemestry = 'edu/api/student/semestryByStudentIdAndKierunekId';
  static const epGrades =
      'edu/api/student/ocenyStudentaByStudentAndKierunekAndSemestr';
  static const epInfo = 'edu/api/student/infoByAuthIdWithPhoto';
  static const epTimetable = 'edu/api/planZajec/planBySemestrAndZalogowany';
  static const epDues = 'edu/api/student/finanseNaleznosciByStudentId';
  static const epAverage = 'edu/api/student/sredniaOcenStudentaByStudent';
  static const epGroups = 'edu/api/student/grupyByStudentId';
  static const epStipend = 'edu/api/student/finanseStypendiumByStudentId';

  /// Restore a persisted session (e.g. from secure storage) + credentials for
  /// silent refresh.
  void restore({AuthSession? session, String? login, String? password}) {
    _session = session;
    _login = login;
    _password = password;
  }

  // ---------------------------------------------------------------- discovery
  /// Fetch & decrypt the list of universities. Static; needs no auth.
  static Future<List<College>> discoverColleges({HttpClient? httpClient}) async {
    final http = httpClient ?? HttpClient();
    try {
      final req = await http.getUrl(Uri.parse(_discoveryUrl));
      final resp = await req.close();
      final b64 = (await resp.transform(utf8.decoder).join()).trim();
      final enc = base64.decode(_pad(b64));
      final plain = List<int>.generate(
          enc.length, (i) => enc[i] ^ _xorKey[i % _xorKey.length]);
      final list = json.decode(utf8.decode(plain)) as List;
      return list
          .map((e) => College.fromJson(e as Map<String, dynamic>))
          .where((c) => c.baseUrl.isNotEmpty)
          .toList();
    } finally {
      if (httpClient == null) http.close(force: true);
    }
  }

  static String _pad(String s) => s + '=' * ((4 - s.length % 4) % 4);

  // --------------------------------------------------------------------- auth
  Future<AuthSession> login(String login, String password) async {
    _login = login;
    _password = password;
    final body = json.encode({
      'login': login,
      'password': password,
      'applicationName': 'mStudent',
    });
    final raw = await _send('POST', '$baseUrl/api/auth',
        headers: {'Content-Type': 'application/json'}, body: body, auth: false);
    final s = AuthSession.fromJson(json.decode(raw) as Map<String, dynamic>);
    _session = s;
    onToken?.call(s);
    return s;
  }

  Future<void> _ensureAuth() async {
    if (_session == null || _session!.isExpired) {
      if (_login != null && _password != null) {
        await login(_login!, _password!);
      } else {
        throw ApiException(401, '/api/auth', 'no session and no credentials');
      }
    }
  }

  void logout() {
    _session = null;
    _login = null;
    _password = null;
  }

  // ------------------------------------------------------------ core GET call
  /// Performs an authenticated GET against a core endpoint and returns the
  /// unwrapped `result` (raw JSON: `List`, `Map`, or null). Re-logins on 401.
  Future<Object?> coreResult(String path, Map<String, String> params) async {
    await _ensureAuth();
    final uri = Uri.parse('$_core/$path').replace(queryParameters: params);
    String raw;
    try {
      raw = await _send('GET', uri.toString(), auth: true);
    } on ApiException catch (e) {
      if (e.isUnauthorized && _login != null) {
        _session = null;
        await _ensureAuth();
        raw = await _send('GET', uri.toString(), auth: true);
      } else {
        rethrow;
      }
    }
    final decoded = json.decode(raw);
    if (decoded is Map<String, dynamic> && decoded.containsKey('result')) {
      return decoded['result'];
    }
    return decoded;
  }

  List<T> _list<T>(Object? result, T Function(Map<String, dynamic>) f) {
    if (result is List) {
      return result.map((e) => f(e as Map<String, dynamic>)).toList();
    }
    return const [];
  }

  // --------------------------------------------------------------- endpoints
  Map<String, String> studentParams() => {'studentId': _studentId};
  Map<String, String> authParams() => {'authId': _authId};

  Future<Map<String, dynamic>?> studentInfo() async {
    final r = await coreResult(epInfo, authParams());
    return r is Map<String, dynamic> ? r : null;
  }

  Future<List<Kierunek>> kierunki() async =>
      _list(await coreResult(epKierunki, studentParams()), Kierunek.fromJson);

  Future<List<Semestr>> semestry(int kierunekId) async => _list(
      await coreResult(
          epSemestry, {'studentId': _studentId, 'kierunekId': '$kierunekId'}),
      Semestr.fromJson);

  Future<List<Grade>> grades(int kierunekId, int semestr) async => _list(
      await coreResult(epGrades, {
        'studentId': _studentId,
        'kierunekId': '$kierunekId',
        'semestr': '$semestr',
      }),
      Grade.fromJson);

  Future<List<ClassEvent>> timetable(int semestr) async => _list(
      await coreResult(epTimetable, {'semestr': '$semestr'}), ClassEvent.fromJson);

  Future<List<Naleznosc>> dues() async =>
      _list(await coreResult(epDues, studentParams()), Naleznosc.fromJson);

  /// Grid endpoints (messages) require pagination params.
  static Map<String, String> gridParams({int start = 0, int limit = 100, int page = 0}) =>
      {'start': '$start', 'limit': '$limit', 'page': '$page'};

  Future<List<MessageHeader>> messages([String box = 'Odebrane']) async => _list(
      await coreResult('wiadomosci/grids/wiadomosci$box', gridParams()),
      MessageHeader.fromJson);

  Future<List<Grupa>> groups() async =>
      _list(await coreResult(epGroups, studentParams()), Grupa.fromJson);

  Future<MessageDetail> messageDetail(int id) async {
    final r = await coreResult(
        'wiadomosci/podglad/wiadomosc', {'wiadomoscId': '$id'});
    return MessageDetail.fromJson((r as Map).cast<String, dynamic>());
  }

  /// Parse a raw cached `result` into a typed list.
  static List<T> parseList<T>(
          Object? result, T Function(Map<String, dynamic>) f) =>
      result is List
          ? result.map((e) => f(e as Map<String, dynamic>)).toList()
          : const [];

  // -------------------------------------------------------------- HTTP helper
  String get _studentId {
    final id = _session?.studentId;
    if (id == null) throw ApiException(400, 'studentId', 'no STUDENT_ID in session');
    return id;
  }

  String get _authId {
    final id = _session?.authId;
    if (id == null) throw ApiException(400, 'authId', 'no BAZUS_USER_ID in session');
    return id;
  }

  Future<String> _send(String method, String url,
      {Map<String, String>? headers, String? body, required bool auth}) async {
    final uri = Uri.parse(url);
    final req = await _http.openUrl(method, uri);
    req.headers.set(HttpHeaders.acceptHeader, 'application/json');
    headers?.forEach(req.headers.set);
    if (auth && _session != null) {
      req.headers.set(HttpHeaders.authorizationHeader,
          '${_session!.tokenType} ${_session!.accessToken}');
    }
    if (body != null) req.write(body);
    final resp = await req.close();
    final text = await resp.transform(utf8.decoder).join();
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(resp.statusCode, uri.path, text);
    }
    return text;
  }

  void close() => _http.close(force: true);
}
