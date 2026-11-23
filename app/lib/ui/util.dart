/// Small UI helpers: color parsing, GPA, grade coloring, ICS export.
library;

import 'dart:convert';

import 'package:flutter/material.dart';

import '../api/models.dart';

/// Polish weekday names in Mon..Sun order (index+1 == DateTime.weekday).
const polishDays = [
  'poniedziałek',
  'wtorek',
  'środa',
  'czwartek',
  'piątek',
  'sobota',
  'niedziela',
];

/// Map a Polish weekday name to DateTime.weekday (1=Mon..7=Sun), or null.
int? polishWeekday(String name) {
  final i = polishDays.indexOf(name.trim().toLowerCase());
  return i < 0 ? null : i + 1;
}

DateTime dayKey(DateTime d) => DateTime.utc(d.year, d.month, d.day);

/// Expand weekly-recurring timetable entries into concrete dated occurrences,
/// keyed by (UTC-normalized) day. Each entry recurs weekly on its [dzienTygodnia]
/// between [odDzien] and [doDzien] (inclusive).
Map<DateTime, List<ClassEvent>> expandOccurrences(List<ClassEvent> events) {
  final map = <DateTime, List<ClassEvent>>{};
  void add(DateTime d, ClassEvent e) =>
      map.putIfAbsent(dayKey(d), () => []).add(e);
  for (final e in events) {
    final start = e.odDzien;
    if (start == null) continue;
    final end = e.doDzien ?? e.odDzien!;
    final w = polishWeekday(e.dzienTygodnia);
    if (w == null) {
      add(start, e);
      continue;
    }
    var cur = DateTime(start.year, start.month, start.day);
    while (cur.weekday != w) {
      cur = cur.add(const Duration(days: 1));
    }
    final last = DateTime(end.year, end.month, end.day);
    while (!cur.isAfter(last)) {
      add(cur, e);
      cur = cur.add(const Duration(days: 7));
    }
  }
  for (final list in map.values) {
    list.sort((a, b) => a.odGodzina.compareTo(b.odGodzina));
  }
  return map;
}

/// Abbreviate a class type (typPrzedmiotu) to the short codes used on campus.
String abbrevType(String type) {
  final s = type.toLowerCase();
  if (s.contains('wychowania fizycznego') ||
      (s.contains('fizyczn') && s.contains('wych'))) {
    return 'WF';
  }
  if (s.contains('laboratoryjne')) return 'CL';
  if (s.contains('niekliniczne')) return 'CN';
  if (s.contains('symulowan')) return 'CS';
  if (s.contains('seminarium')) return 'SEM';
  if (s.contains('lektorat')) return 'LEK';
  if (s.contains('wykład') || s.contains('wyklad')) return 'WYK';
  if (s.contains('ćwiczenia') || s.contains('cwiczenia')) return 'CW';
  return type;
}

/// True when a class is held online (no physical room / map).
bool isOnline(ClassEvent e) {
  final s = '${e.sala} ${e.salaAdres}'.toLowerCase();
  return s.contains('online') || s.contains('teams') || s.contains('zdaln');
}

/// The room code — the part of `sala` before the street ("… Ul. …").
String roomCode(String sala) {
  final i = sala.indexOf(RegExp(r'\s+[Uu]l\.'));
  return (i > 0 ? sala.substring(0, i) : sala).trim();
}

/// Extract a clean room identifier: "nr N" from "_nr_N", or "Prosektorium".
/// Returns '' when nothing recognizable is present.
String roomNumber(String sala) {
  final code = roomCode(sala);
  final nr = RegExp(r'_nr_([^\s_]+)').firstMatch(code);
  if (nr != null) return 'nr ${nr.group(1)}';
  if (code.toLowerCase().contains('prosektorium')) return 'Prosektorium';
  return '';
}

Color hexColor(String hex, [Color fallback = const Color(0xFF2962FF)]) {
  var h = hex.replaceAll('#', '').trim();
  if (h.length == 6) h = 'FF$h';
  final v = int.tryParse(h, radix: 16);
  return v == null ? fallback : Color(v);
}

/// ECTS-weighted average over graded, numeric entries (latest term only).
double? weightedGpa(List<Grade> grades) {
  double num = 0, den = 0;
  for (final g in grades) {
    final v = g.numeric;
    if (v == null) continue;
    final w = g.ects > 0 ? g.ects : 1;
    num += v * w;
    den += w;
  }
  return den == 0 ? null : num / den;
}

/// Simple arithmetic mean over numeric grades.
double? meanGrade(List<Grade> grades) {
  final xs = grades.map((g) => g.numeric).whereType<double>().toList();
  if (xs.isEmpty) return null;
  return xs.reduce((a, b) => a + b) / xs.length;
}

Color gradeColor(double? v, BuildContext ctx) {
  if (v == null) return Theme.of(ctx).disabledColor;
  if (v >= 4.5) return Colors.green.shade600;
  if (v >= 3.5) return Colors.lightGreen.shade700;
  if (v >= 3.0) return Colors.orange.shade700;
  return Colors.red.shade600;
}

/// Build an iCalendar document from timetable events.
String buildIcs(List<ClassEvent> events, {String calName = 'mStudent plan'}) {
  final b = StringBuffer()
    ..writeln('BEGIN:VCALENDAR')
    ..writeln('VERSION:2.0')
    ..writeln('PRODID:-//mstudent//plan//PL')
    ..writeln('X-WR-CALNAME:$calName');
  var i = 0;
  for (final e in events) {
    final start = _combine(e.odDzien, e.odGodzina);
    final end = _combine(e.doDzien ?? e.odDzien, e.doGodzina);
    if (start == null || end == null) continue;
    b
      ..writeln('BEGIN:VEVENT')
      ..writeln('UID:mstudent-${i++}-${start.millisecondsSinceEpoch}@local')
      ..writeln('DTSTART:${_ics(start)}')
      ..writeln('DTEND:${_ics(end)}')
      ..writeln('SUMMARY:${_esc(e.przedmiot)} (${_esc(abbrevType(e.typPrzedmiotu))})')
      ..writeln('LOCATION:${_esc(e.sala)} ${_esc(e.salaAdres)}')
      ..writeln('DESCRIPTION:${_esc(_icsDesc(e))}')
      ..writeln('END:VEVENT');
  }
  b.writeln('END:VCALENDAR');
  return b.toString();
}

/// Deterministic (FNV-1a) UID for a class occurrence — stable across syncs so
/// re-pushing to CalDAV updates rather than duplicates.
String occurrenceUid(ClassEvent e, DateTime day) {
  final s = '${e.przedmiot}|${e.typPrzedmiotu}|${e.grupa}|'
      '${day.year}-${day.month}-${day.day}|${e.odGodzina}';
  var h = 0x811c9dc5;
  for (final c in utf8.encode(s)) {
    h = (h ^ c) & 0xffffffff;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return 'indeks-${h.toRadixString(16).padLeft(8, '0')}@mstudent';
}

/// A complete VCALENDAR with a single VEVENT for one occurrence on [day].
String vcalendarForOccurrence(ClassEvent e, DateTime day, {String? uid}) {
  final start = _combine(day, e.odGodzina);
  final end = _combine(day, e.doGodzina) ?? start;
  final b = StringBuffer()
    ..writeln('BEGIN:VCALENDAR')
    ..writeln('VERSION:2.0')
    ..writeln('PRODID:-//indeks//plan//PL')
    ..writeln('BEGIN:VEVENT')
    ..writeln('UID:${uid ?? occurrenceUid(e, day)}')
    ..writeln('DTSTAMP:${_ics(DateTime.now())}')
    ..writeln('DTSTART:${_ics(start ?? day)}')
    ..writeln('DTEND:${_ics(end ?? day)}')
    ..writeln('SUMMARY:${_esc(e.przedmiot)} (${_esc(abbrevType(e.typPrzedmiotu))})')
    ..writeln('LOCATION:${_esc(e.sala)} ${_esc(e.salaAdres)}')
    ..writeln('DESCRIPTION:${_esc(_icsDesc(e))}')
    ..writeln('END:VEVENT')
    ..writeln('END:VCALENDAR');
  return b.toString();
}

DateTime? _combine(DateTime? day, String hhmm) {
  if (day == null) return null;
  final m = RegExp(r'(\d{1,2})[:.](\d{2})').firstMatch(hhmm);
  if (m == null) return day;
  return DateTime(day.year, day.month, day.day, int.parse(m[1]!), int.parse(m[2]!));
}

String _ics(DateTime d) {
  String p(int n, [int w = 2]) => n.toString().padLeft(w, '0');
  return '${p(d.year, 4)}${p(d.month)}${p(d.day)}T${p(d.hour)}${p(d.minute)}00';
}

String _icsDesc(ClassEvent e) => [
      if (e.typPrzedmiotu.isNotEmpty) e.typPrzedmiotu, // full type name (#1)
      if (e.lecturer.isNotEmpty) e.lecturer,
      if (e.temat.isNotEmpty) e.temat,
    ].join(' — ');

String _esc(String s) =>
    s.replaceAll('\\', '\\\\').replaceAll(',', '\\,').replaceAll(';', '\\;').replaceAll('\n', '\\n');
