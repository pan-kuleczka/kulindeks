/// Portable persistence of the auth session + credentials (for silent refresh).
///
/// Stores a JSON file in the app-support directory (works on Android, iOS and
/// Linux/desktop with no native keyring dependency). The file is base64-wrapped
/// to avoid casual plaintext exposure — this is obfuscation, not encryption.
/// On mobile you can later back this with the platform keystore if desired.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../api/models.dart';

class SessionStore {
  final String? _overrideDir; // for tests
  SessionStore([this._overrideDir]);

  Future<File> _file() async {
    final dir = _overrideDir != null
        ? Directory(_overrideDir)
        : await getApplicationSupportDirectory();
    if (!await dir.exists()) await dir.create(recursive: true);
    return File('${dir.path}/session.json');
  }

  Future<void> save({
    required String baseUrl,
    required String collegeName,
    required String login,
    required String password,
    required AuthSession session,
  }) async {
    final data = {
      'baseUrl': baseUrl,
      'collegeName': collegeName,
      'login': login,
      'password': password,
      'session': session.toJson(),
    };
    final f = await _file();
    await f.writeAsString(base64.encode(utf8.encode(json.encode(data))));
  }

  Future<void> updateSession(AuthSession session) async {
    final cur = await load();
    if (cur == null) return;
    await save(
      baseUrl: cur.baseUrl,
      collegeName: cur.collegeName,
      login: cur.login,
      password: cur.password,
      session: session,
    );
  }

  Future<StoredLogin?> load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return null;
      final raw = utf8.decode(base64.decode(await f.readAsString()));
      final m = json.decode(raw) as Map<String, dynamic>;
      AuthSession? session;
      if (m['session'] != null) {
        try {
          session = AuthSession.fromCache(m['session'] as Map<String, dynamic>);
        } catch (_) {}
      }
      return StoredLogin(
        baseUrl: m['baseUrl'] as String,
        collegeName: m['collegeName'] as String? ?? '',
        login: m['login'] as String,
        password: m['password'] as String,
        session: session,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    try {
      final f = await _file();
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}

class StoredLogin {
  final String baseUrl;
  final String collegeName;
  final String login;
  final String password;
  final AuthSession? session;
  StoredLogin({
    required this.baseUrl,
    required this.collegeName,
    required this.login,
    required this.password,
    this.session,
  });
}
