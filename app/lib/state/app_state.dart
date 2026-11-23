/// App-wide state: auth, selection, and cache-first data loading.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../api/client.dart';
import '../api/models.dart';
import '../l10n/strings.dart';
import 'cache.dart';
import 'notifications.dart';
import 'session_store.dart';
import 'settings.dart';

enum AuthStatus { unknown, loggedOut, loggedIn }

/// A loadable value with loading/error flags (for "instant cache then refresh").
class Resource<T> {
  T? value;
  bool loading;
  Object? error;
  DateTime? updatedAt;
  Resource({this.value, this.loading = false, this.error, this.updatedAt});
  bool get hasValue => value != null;
}

class AppState extends ChangeNotifier {
  final SessionStore _store;
  final JsonCache _cache;
  final SettingsStore _settings;
  final NotificationService _notes;

  AppState(this._store, this._cache, this._settings, this._notes);

  MStudentClient? _client;
  AuthStatus status = AuthStatus.unknown;
  String collegeName = '';
  String primaryColor = '#2962FF';

  Prefs _prefs = const Prefs();
  Prefs get prefs => _prefs;
  AppText get text => AppText.of(_prefs.locale);
  bool offline = false;
  bool refreshing = false;

  int tab = 0;
  void goToTab(int i) {
    tab = i;
    notifyListeners();
  }

  // Request the timetable to open a specific class in Day view (#3).
  ClassEvent? pendingEvent;
  DateTime? pendingDay;
  int focusSeq = 0;
  void focusClass(ClassEvent e, DateTime day) {
    pendingEvent = e;
    pendingDay = DateTime(day.year, day.month, day.day);
    focusSeq++;
    tab = 1;
    notifyListeners();
  }

  int? kierunekId;
  int? semestr;

  // Remembered for pre-filling the login form after logout (#5). In-memory only.
  String? lastLogin;
  String? lastPassword;
  College? lastCollege;

  final kierunki = Resource<List<Kierunek>>();
  final semestry = Resource<List<Semestr>>();
  final grades = Resource<List<Grade>>();
  final timetable = Resource<List<ClassEvent>>();
  final dues = Resource<List<Naleznosc>>();
  final messages = Resource<List<MessageHeader>>();
  final info = Resource<Map<String, dynamic>>();
  final groups = Resource<List<Grupa>>();
  final stipends = Resource<List<Map<String, dynamic>>>();

  String? get userName => _client?.session?.userName;
  String? get studentId => _client?.session?.studentId;

  // -------------------------------------------------------------- prefs
  Future<void> _applyLocale() async {
    Intl.defaultLocale = _prefs.locale == 'en' ? 'en' : 'pl_PL';
    await initializeDateFormatting(Intl.defaultLocale);
  }

  Future<void> setTheme(AppThemeMode t) async {
    _prefs = _prefs.copyWith(theme: t);
    await _settings.savePrefs(_prefs);
    notifyListeners();
  }

  Future<void> setLocale(String l) async {
    _prefs = _prefs.copyWith(locale: l);
    await _applyLocale();
    await _settings.savePrefs(_prefs);
    notifyListeners();
  }

  Future<void> setFontScale(double s) async {
    _prefs = _prefs.copyWith(fontScale: s);
    await _settings.savePrefs(_prefs);
    notifyListeners();
  }

  Future<void> setAccent(String hex) async {
    _prefs = _prefs.copyWith(accentColor: hex);
    await _settings.savePrefs(_prefs);
    notifyListeners();
  }

  Future<void> setNotifLead(int minutes) async {
    _prefs = _prefs.copyWith(notifLeadMinutes: minutes);
    await _settings.savePrefs(_prefs);
    notifyListeners();
    await _rescheduleNotifications();
  }

  Future<void> _rescheduleNotifications() async {
    await _notes.scheduleForEvents(
        timetable.value ?? const [], _prefs.notifLeadMinutes, text.nextClass);
  }

  // ------------------------------------------------------------- bootstrap
  Future<void> bootstrap() async {
    _prefs = await _settings.loadPrefs();
    await _applyLocale();
    await _notes.init();
    final stored = await _store.load();
    if (stored == null) {
      status = AuthStatus.loggedOut;
      notifyListeners();
      return;
    }
    collegeName = stored.collegeName;
    _client = MStudentClient(stored.baseUrl)
      ..restore(
          session: stored.session,
          login: stored.login,
          password: stored.password)
      ..onToken = (s) => _store.updateSession(s);
    status = AuthStatus.loggedIn;
    notifyListeners();
    // warm essential selection from cache, then refresh in background.
    _loadSelection();
    unawaited(refreshAll());
  }

  // ----------------------------------------------------------------- login
  Future<void> login({
    required College college,
    required String login,
    required String password,
  }) async {
    final client = MStudentClient(college.baseUrl)
      ..onToken = (s) => _store.updateSession(s);
    final session = await client.login(login, password);
    _client = client;
    collegeName = college.name;
    primaryColor = college.primaryColor;
    lastLogin = login;
    lastPassword = password;
    lastCollege = college;
    await _store.save(
      baseUrl: college.baseUrl,
      collegeName: college.name,
      login: login,
      password: password,
      session: session,
    );
    status = AuthStatus.loggedIn;
    notifyListeners();
    await refreshAll();
  }

  Future<void> logout() async {
    _client?.logout();
    _client?.close();
    _client = null;
    await _store.clear();
    await _cache.clearAll();
    for (final r in [
      kierunki, semestry, grades, timetable, dues, messages, info, groups, stipends
    ]) {
      r.value = null;
      r.error = null;
      r.updatedAt = null;
    }
    kierunekId = null;
    semestr = null;
    status = AuthStatus.loggedOut;
    notifyListeners();
  }

  void _loadSelection() {
    kierunekId = _cache.get('sel:kierunek') as int?;
    semestr = _cache.get('sel:semestr') as int?;
  }

  Future<void> selectKierunek(int id) async {
    kierunekId = id;
    await _cache.put('sel:kierunek', id);
    notifyListeners();
    await refreshSemestry();
  }

  Future<void> selectSemestr(int s) async {
    semestr = s;
    await _cache.put('sel:semestr', s);
    notifyListeners();
    await Future.wait([refreshGrades(), refreshTimetable()]);
  }

  // ------------------------------------------------- generic cache-first load
  Future<void> _load<T>(
    Resource<T> res,
    String cacheKey,
    Future<Object?> Function() fetchRaw,
    T Function(Object? raw) parse,
  ) async {
    // 1) instant cache
    final cached = _cache.get(cacheKey);
    if (cached != null && !res.hasValue) {
      try {
        res.value = parse(cached);
        res.updatedAt = _cache.ageOf(cacheKey);
      } catch (_) {}
    }
    res.loading = true;
    res.error = null;
    notifyListeners();
    // 2) network
    try {
      final raw = await fetchRaw();
      res.value = parse(raw);
      res.updatedAt = DateTime.now();
      await _cache.put(cacheKey, raw);
      if (offline) {
        offline = false;
      }
    } catch (e) {
      res.error = e;
      if (_isNetworkError(e)) offline = true;
    } finally {
      res.loading = false;
      notifyListeners();
    }
  }

  bool _isNetworkError(Object e) =>
      e is SocketException ||
      e is HttpException ||
      e.toString().contains('SocketException') ||
      e.toString().contains('Failed host lookup');

  MStudentClient get _c {
    final c = _client;
    if (c == null) throw StateError('not logged in');
    return c;
  }

  Future<void> refreshAll() async {
    if (refreshing) return;
    refreshing = true;
    notifyListeners();
    try {
      await refreshKierunki();
      await Future.wait([
        refreshInfo(), refreshDues(), refreshMessages(), refreshGroups(),
        refreshStipends()
      ]);
      if (kierunekId != null) await refreshSemestry();
      if (semestr != null) {
        await Future.wait([refreshGrades(), refreshTimetable()]);
      }
    } finally {
      refreshing = false;
      notifyListeners();
    }
  }

  Future<void> refreshKierunki() => _load(
        kierunki,
        'kierunki',
        () => _c.coreResult(MStudentClient.epKierunki, _c.studentParams()),
        (raw) {
          final list = MStudentClient.parseList(raw, Kierunek.fromJson);
          kierunekId ??= list.isNotEmpty ? list.first.id : null;
          return list;
        },
      );

  Future<void> refreshSemestry() async {
    if (kierunekId == null) return;
    await _load(
      semestry,
      'semestry:$kierunekId',
      () => _c.coreResult(MStudentClient.epSemestry,
          {..._c.studentParams(), 'kierunekId': '$kierunekId'}),
      (raw) {
        final list = MStudentClient.parseList(raw, Semestr.fromJson);
        if (semestr == null && list.isNotEmpty) {
          semestr = list.firstWhere((s) => s.aktywny, orElse: () => list.last).semestr;
        }
        return list;
      },
    );
  }

  Future<void> refreshGrades() async {
    if (kierunekId == null || semestr == null) return;
    await _load(
      grades,
      'grades:$kierunekId:$semestr',
      () => _c.coreResult(MStudentClient.epGrades, {
        ..._c.studentParams(),
        'kierunekId': '$kierunekId',
        'semestr': '$semestr',
      }),
      (raw) => MStudentClient.parseList(raw, Grade.fromJson),
    );
  }

  Future<void> refreshTimetable() async {
    if (semestr == null) return;
    await _load(
      timetable,
      'timetable:$semestr',
      () => _c.coreResult(MStudentClient.epTimetable, {'semestr': '$semestr'}),
      (raw) => MStudentClient.parseList(raw, ClassEvent.fromJson),
    );
    await _rescheduleNotifications();
  }

  Future<void> refreshDues() => _load(
        dues,
        'dues',
        () => _c.coreResult(MStudentClient.epDues, _c.studentParams()),
        (raw) => MStudentClient.parseList(raw, Naleznosc.fromJson),
      );

  Future<void> refreshMessages() => _load(
        messages,
        'messages',
        () => _c.coreResult(
            'wiadomosci/grids/wiadomosciOdebrane', MStudentClient.gridParams()),
        (raw) => MStudentClient.parseList(raw, MessageHeader.fromJson),
      );

  Future<void> refreshGroups() => _load(
        groups,
        'groups',
        () => _c.coreResult(MStudentClient.epGroups, _c.studentParams()),
        (raw) => MStudentClient.parseList(raw, Grupa.fromJson),
      );

  Future<void> refreshStipends() => _load(
        stipends,
        'stipends',
        () => _c.coreResult(MStudentClient.epStipend, _c.studentParams()),
        (raw) => raw is List
            ? raw.map((e) => (e as Map).cast<String, dynamic>()).toList()
            : <Map<String, dynamic>>[],
      );

  Future<MessageDetail> loadMessage(int id) => _c.messageDetail(id);

  Future<void> refreshInfo() => _load(
        info,
        'info',
        () => _c.coreResult(MStudentClient.epInfo, _c.authParams()),
        (raw) => (raw as Map).cast<String, dynamic>(),
      );
}
