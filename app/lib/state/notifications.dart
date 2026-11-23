/// Local notifications: remind the user a set time before each class.
///
/// Android/iOS use OS-level scheduling (fires even if the app is closed).
/// Desktop (Linux) has no scheduled-notification API, so we arm in-app timers
/// while the app runs. All universities are in Poland → Europe/Warsaw.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../api/models.dart';
import '../ui/util.dart' show abbrevType;

class NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  final List<Timer> _timers = [];
  bool _ready = false;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'classes', 'Zajęcia',
      channelDescription: 'Przypomnienia o zajęciach',
      importance: Importance.max,
      priority: Priority.high,
    ),
    linux: LinuxNotificationDetails(),
    iOS: DarwinNotificationDetails(),
  );

  Future<void> init() async {
    try {
      tzdata.initializeTimeZones();
      try {
        tz.setLocalLocation(tz.getLocation('Europe/Warsaw'));
      } catch (_) {}
      await _plugin.initialize(const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        linux: LinuxInitializationSettings(defaultActionName: 'Otwórz'),
        iOS: DarwinInitializationSettings(),
      ));
      if (Platform.isAndroid) {
        await _plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      }
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  Future<void> cancelAll() async {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }

  /// (Re)schedule reminders [leadMinutes] before each upcoming class.
  Future<void> scheduleForEvents(
      List<ClassEvent> events, int leadMinutes, String title) async {
    await cancelAll();
    if (!_ready || leadMinutes <= 0) return;
    final now = DateTime.now();
    final horizon = now.add(const Duration(days: 21));
    var scheduled = 0;
    for (final e in events) {
      if (scheduled >= 64) break; // keep it sane
      final start = _startOf(e);
      if (start == null || start.isAfter(horizon)) continue;
      final at = start.subtract(Duration(minutes: leadMinutes));
      if (at.isBefore(now)) continue;
      final id = _idFor(e, start);
      final body = '${e.odGodzina}'
          '${e.sala.isNotEmpty ? " · ${e.sala}" : ""}'
          '${e.typPrzedmiotu.isNotEmpty ? " · ${abbrevType(e.typPrzedmiotu)}" : ""}';
      final text = '${e.przedmiot} — $title';
      try {
        if (Platform.isAndroid || Platform.isIOS) {
          await _plugin.zonedSchedule(
            id, text, body, tz.TZDateTime.from(at, tz.local), _details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
          );
        } else {
          _timers.add(Timer(at.difference(now),
              () => _plugin.show(id, text, body, _details)));
        }
        scheduled++;
      } catch (_) {}
    }
  }

  DateTime? _startOf(ClassEvent e) {
    final d = e.odDzien;
    if (d == null) return null;
    final m = RegExp(r'(\d{1,2})[:.](\d{2})').firstMatch(e.odGodzina);
    if (m == null) return null;
    return DateTime(d.year, d.month, d.day, int.parse(m[1]!), int.parse(m[2]!));
  }

  int _idFor(ClassEvent e, DateTime start) {
    final s = '${e.przedmiot}|${start.millisecondsSinceEpoch}';
    return s.hashCode & 0x7fffffff;
  }
}
