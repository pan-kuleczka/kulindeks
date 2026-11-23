/// Tiny JSON cache with TTL on top of shared_preferences.
///
/// Enables the "instant load, refresh in background" UX: screens render cached
/// data immediately, then update when the network returns.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class JsonCache {
  final SharedPreferences _p;
  JsonCache(this._p);

  static Future<JsonCache> open() async =>
      JsonCache(await SharedPreferences.getInstance());

  /// Store any JSON-encodable value under [key] with the current timestamp.
  Future<void> put(String key, Object? value) async {
    await _p.setString(
      'cache:$key',
      json.encode({'ts': DateTime.now().millisecondsSinceEpoch, 'v': value}),
    );
  }

  /// Returns the cached value (decoded) or null; [maxAge] null = ignore age.
  Object? get(String key, {Duration? maxAge}) {
    final raw = _p.getString('cache:$key');
    if (raw == null) return null;
    try {
      final m = json.decode(raw) as Map<String, dynamic>;
      if (maxAge != null) {
        final ts = DateTime.fromMillisecondsSinceEpoch(m['ts'] as int);
        if (DateTime.now().difference(ts) > maxAge) return null;
      }
      return m['v'];
    } catch (_) {
      return null;
    }
  }

  DateTime? ageOf(String key) {
    final raw = _p.getString('cache:$key');
    if (raw == null) return null;
    try {
      final m = json.decode(raw) as Map<String, dynamic>;
      return DateTime.fromMillisecondsSinceEpoch(m['ts'] as int);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearAll() async {
    for (final k in _p.getKeys().where((k) => k.startsWith('cache:'))) {
      await _p.remove(k);
    }
  }
}
