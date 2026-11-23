/// Nextcloud CalDAV settings, persisted to a local file.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class NextcloudConfig {
  final String serverUrl; // e.g. https://cloud.example.com
  final String username;
  final String appPassword; // Nextcloud app password (Settings → Security)
  final String calendar; // calendar collection name

  const NextcloudConfig({
    required this.serverUrl,
    required this.username,
    required this.appPassword,
    this.calendar = 'kulindeks',
  });

  bool get isComplete =>
      serverUrl.isNotEmpty && username.isNotEmpty && appPassword.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'serverUrl': serverUrl,
        'username': username,
        'appPassword': appPassword,
        'calendar': calendar,
      };

  factory NextcloudConfig.fromJson(Map<String, dynamic> j) => NextcloudConfig(
        serverUrl: j['serverUrl'] as String? ?? '',
        username: j['username'] as String? ?? '',
        appPassword: j['appPassword'] as String? ?? '',
        calendar: j['calendar'] as String? ?? 'kulindeks',
      );

  static const empty = NextcloudConfig(serverUrl: '', username: '', appPassword: '');
}

enum AppThemeMode { system, light, dark, highContrast }

const kDefaultAccent = '#2962FF'; // blue

class Prefs {
  final AppThemeMode theme;
  final String locale; // 'pl' | 'en'
  final double fontScale; // 0.8 .. 1.5
  final int notifLeadMinutes; // 0 = off
  final String accentColor; // hex, drives the app's seed color

  const Prefs({
    this.theme = AppThemeMode.system,
    this.locale = 'pl',
    this.fontScale = 1.0,
    this.notifLeadMinutes = 0,
    this.accentColor = kDefaultAccent,
  });

  Prefs copyWith({
    AppThemeMode? theme,
    String? locale,
    double? fontScale,
    int? notifLeadMinutes,
    String? accentColor,
  }) =>
      Prefs(
        theme: theme ?? this.theme,
        locale: locale ?? this.locale,
        fontScale: fontScale ?? this.fontScale,
        notifLeadMinutes: notifLeadMinutes ?? this.notifLeadMinutes,
        accentColor: accentColor ?? this.accentColor,
      );

  Map<String, dynamic> toJson() => {
        'theme': theme.name,
        'locale': locale,
        'fontScale': fontScale,
        'notifLeadMinutes': notifLeadMinutes,
        'accentColor': accentColor,
      };

  factory Prefs.fromJson(Map<String, dynamic> j) => Prefs(
        theme: AppThemeMode.values.firstWhere(
            (t) => t.name == j['theme'], orElse: () => AppThemeMode.system),
        locale: j['locale'] as String? ?? 'pl',
        fontScale: (j['fontScale'] as num?)?.toDouble() ?? 1.0,
        notifLeadMinutes: (j['notifLeadMinutes'] as num?)?.toInt() ?? 0,
        accentColor: j['accentColor'] as String? ?? kDefaultAccent,
      );
}

class SettingsStore {
  final String? _overrideDir;
  SettingsStore([this._overrideDir]);

  Future<File> _file() async {
    final dir = _overrideDir != null
        ? Directory(_overrideDir)
        : await getApplicationSupportDirectory();
    if (!await dir.exists()) await dir.create(recursive: true);
    return File('${dir.path}/settings.json');
  }

  Future<Map<String, dynamic>> _read() async {
    try {
      final f = await _file();
      if (!await f.exists()) return {};
      return (json.decode(await f.readAsString()) as Map).cast<String, dynamic>();
    } catch (_) {
      return {};
    }
  }

  Future<void> _write(Map<String, dynamic> m) async {
    final f = await _file();
    await f.writeAsString(json.encode(m));
  }

  Future<NextcloudConfig> loadNextcloud() async {
    final m = await _read();
    if (m['nextcloud'] is Map) {
      return NextcloudConfig.fromJson((m['nextcloud'] as Map).cast<String, dynamic>());
    }
    return NextcloudConfig.empty;
  }

  Future<void> saveNextcloud(NextcloudConfig c) async {
    final m = await _read();
    m['nextcloud'] = c.toJson();
    await _write(m);
  }

  Future<Prefs> loadPrefs() async {
    final m = await _read();
    if (m['prefs'] is Map) {
      return Prefs.fromJson((m['prefs'] as Map).cast<String, dynamic>());
    }
    return const Prefs();
  }

  Future<void> savePrefs(Prefs p) async {
    final m = await _read();
    m['prefs'] = p.toJson();
    await _write(m);
  }
}
