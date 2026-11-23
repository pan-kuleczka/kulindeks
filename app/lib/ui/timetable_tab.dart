import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/models.dart';
import '../l10n/strings.dart';
import '../state/app_state.dart';
import 'util.dart';

const _gutter = 48.0;

enum _Mode { day, week, month }

class TimetableTab extends StatefulWidget {
  const TimetableTab({super.key});
  @override
  State<TimetableTab> createState() => _TimetableTabState();
}

class _TimetableTabState extends State<TimetableTab> {
  _Mode _mode = _Mode.week;
  DateTime? _focus; // focused day (day/month) / any day in the week
  _Selected? _selected;
  int _seenFocusSeq = 0;

  DateTime _mondayOf(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final t = s.text;
    final res = s.timetable;
    final events = res.value ?? const <ClassEvent>[];
    final byDay = expandOccurrences(events);
    if (!res.hasValue && res.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    _focus ??= _initialDay(byDay.keys);

    // Apply a pending "open this class" request from the dashboard (#3).
    if (s.focusSeq != _seenFocusSeq) {
      _seenFocusSeq = s.focusSeq;
      final ev = s.pendingEvent, day = s.pendingDay;
      if (ev != null && day != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _mode = _Mode.day;
            _focus = day;
            _selected = _Selected(ev, day);
          });
        });
      }
    }

    return Column(
      children: [
        _Toolbar(
          mode: _mode,
          label: _label(),
          modeLabels: [t.day, t.week, t.month],
          exportTip: t.exportIcs,
          onMode: (m) => setState(() => _mode = m),
          onPrev: () => setState(_prev),
          onNext: () => setState(_next),
          onToday: () => setState(() => _focus = DateTime.now()),
          onExport: events.isEmpty ? null : () => _exportIcs(context, events),
        ),
        Expanded(
          // horizontal swipe navigates to the previous/next period (#1)
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragEnd: (d) {
              final v = d.primaryVelocity ?? 0;
              if (v < -200) setState(_next);
              if (v > 200) setState(_prev);
            },
            child: switch (_mode) {
              _Mode.day => _grid(context, [_focus!], byDay, s, t),
              _Mode.week => _grid(context, _weekDays(), byDay, s, t),
              _Mode.month => _MonthView(
                  month: _focus!,
                  byDay: byDay,
                  dayAbbr: t.dayAbbr,
                  onSelectDay: (d) => setState(() {
                    _focus = d;
                    _mode = _Mode.day;
                  }),
                ),
            },
          ),
        ),
        if (_selected != null)
          _DetailPanel(
            sel: _selected!,
            t: t,
            onClose: () => setState(() => _selected = null),
            onMap: _openMap,
          ),
      ],
    );
  }

  List<DateTime> _weekDays() {
    final start = _mondayOf(_focus!);
    return List.generate(7, (i) => start.add(Duration(days: i)));
  }

  Widget _grid(BuildContext context, List<DateTime> days,
      Map<DateTime, List<ClassEvent>> byDay, AppState s, AppText t) {
    final weekEvents = <ClassEvent>[];
    for (final d in days) {
      weekEvents.addAll(byDay[dayKey(d)] ?? const []);
    }
    final (hStart, hEnd) = _hourRange(weekEvents);
    return Column(
      children: [
        _DayHeader(days: days, dayAbbr: t.dayAbbr),
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              final hours = hEnd - hStart;
              // stretch rows to fill the height; scroll only when cramped (#10)
              final rowH = math.max(box.maxHeight / hours, 44.0);
              return RefreshIndicator(
                onRefresh: s.refreshTimetable,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                    height: rowH * hours,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _HourGutter(hStart: hStart, hEnd: hEnd, pxPerHour: rowH),
                        for (final d in days)
                          Expanded(
                            child: _DayColumn(
                              day: d,
                              events: byDay[dayKey(d)] ?? const [],
                              hStart: hStart,
                              pxPerHour: rowH,
                              detailed: days.length == 1, // Day view: rich blocks (#1)
                              selectedUid: _selected == null
                                  ? null
                                  : occurrenceUid(_selected!.event, _selected!.day),
                              onTap: (e) =>
                                  setState(() => _selected = _Selected(e, d)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  DateTime _initialDay(Iterable<DateTime> keys) {
    final now = DateTime.now();
    final upcoming = keys.where((k) => !k.isBefore(dayKey(now))).toList()..sort();
    if (upcoming.isNotEmpty) return upcoming.first;
    final all = keys.toList()..sort();
    return all.isEmpty ? now : all.last;
  }

  String _label() {
    final f = _focus!;
    switch (_mode) {
      case _Mode.day:
        return DateFormat('EEEE, d MMM yyyy').format(f);
      case _Mode.week:
        final start = _mondayOf(f), end = _mondayOf(f).add(const Duration(days: 6));
        return start.month == end.month
            ? '${DateFormat('d').format(start)}–${DateFormat('d MMM yyyy').format(end)}'
            : '${DateFormat('d MMM').format(start)} – ${DateFormat('d MMM yyyy').format(end)}';
      case _Mode.month:
        return DateFormat('LLLL yyyy').format(f);
    }
  }

  void _prev() {
    final f = _focus!;
    _focus = switch (_mode) {
      _Mode.day => f.subtract(const Duration(days: 1)),
      _Mode.week => f.subtract(const Duration(days: 7)),
      _Mode.month => DateTime(f.year, f.month - 1, 1),
    };
  }

  void _next() {
    final f = _focus!;
    _focus = switch (_mode) {
      _Mode.day => f.add(const Duration(days: 1)),
      _Mode.week => f.add(const Duration(days: 7)),
      _Mode.month => DateTime(f.year, f.month + 1, 1),
    };
  }

  /// Window = intersection of the events' span with 08:00–20:00 (per #7).
  (int, int) _hourRange(List<ClassEvent> events) {
    int? lo, hi;
    for (final e in events) {
      final s = _min(e.odGodzina), en = _min(e.doGodzina);
      if (s != null) lo = (lo == null) ? s ~/ 60 : (lo < s ~/ 60 ? lo : s ~/ 60);
      if (en != null) {
        final ceil = (en + 59) ~/ 60;
        hi = (hi == null) ? ceil : (hi > ceil ? hi : ceil);
      }
    }
    final start = (lo == null) ? 8 : (lo > 8 ? lo : 8);
    var end = (hi == null) ? 20 : (hi < 20 ? hi : 20);
    if (end <= start) end = start + 1;
    return (start, end);
  }

  Future<void> _exportIcs(BuildContext context, List<ClassEvent> events) async {
    try {
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/plan.ics');
      await f.writeAsString(buildIcs(events));
      await Share.shareXFiles([XFile(f.path, mimeType: 'text/calendar')],
          subject: 'Plan zajęć');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Nie udało się wyeksportować: $e')));
      }
    }
  }

  Future<void> _openMap(ClassEvent e) async {
    if (e.salaLat == null || e.salaLong == null) return;
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${e.salaLat},${e.salaLong}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _Selected {
  final ClassEvent event;
  final DateTime day;
  _Selected(this.event, this.day);
}

int? _min(String hhmm) {
  final m = RegExp(r'(\d{1,2})[:.](\d{2})').firstMatch(hhmm);
  return m == null ? null : int.parse(m[1]!) * 60 + int.parse(m[2]!);
}

Color _typeColor(String typ, BuildContext c) {
  final t = typ.toLowerCase();
  if (t.contains('wyk')) return Colors.indigo;
  if (t.contains('ćw') || t.contains('cw')) return Colors.teal;
  if (t.contains('lab')) return Colors.deepOrange;
  if (t.contains('sem')) return Colors.purple;
  return Theme.of(c).colorScheme.primary;
}

// ----------------------------------------------------------------- toolbar
class _Toolbar extends StatelessWidget {
  final _Mode mode;
  final String label;
  final List<String> modeLabels; // [day, week, month]
  final String exportTip;
  final void Function(_Mode) onMode;
  final VoidCallback onPrev, onNext, onToday;
  final VoidCallback? onExport;
  const _Toolbar({
    required this.mode,
    required this.label,
    required this.modeLabels,
    required this.exportTip,
    required this.onMode,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
          child: Row(
            children: [
              SegmentedButton<_Mode>(
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                segments: [
                  ButtonSegment(value: _Mode.day, label: Text(modeLabels[0])),
                  ButtonSegment(value: _Mode.week, label: Text(modeLabels[1])),
                  ButtonSegment(value: _Mode.month, label: Text(modeLabels[2])),
                ],
                selected: {mode},
                showSelectedIcon: false,
                onSelectionChanged: (s) => onMode(s.first),
              ),
              const Spacer(),
              IconButton(
                onPressed: onExport,
                icon: const Icon(Icons.ios_share),
                tooltip: exportTip,
              ),
            ],
          ),
        ),
        Row(
          children: [
            IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left)),
            Expanded(
              child: Center(
                child: TextButton(
                  onPressed: onToday,
                  child: Text(label, style: Theme.of(context).textTheme.titleSmall),
                ),
              ),
            ),
            IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
          ],
        ),
      ],
    );
  }
}

class _DayHeader extends StatelessWidget {
  final List<DateTime> days;
  final List<String> dayAbbr;
  const _DayHeader({required this.days, required this.dayAbbr});
  @override
  Widget build(BuildContext context) {
    final today = dayKey(DateTime.now());
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          const SizedBox(width: _gutter),
          for (final d in days)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    Text(dayAbbr[d.weekday - 1],
                        style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: 2),
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: dayKey(d) == today
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                      ),
                      child: Center(
                        child: Text('${d.day}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: dayKey(d) == today
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : null,
                            )),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HourGutter extends StatelessWidget {
  final int hStart, hEnd;
  final double pxPerHour;
  const _HourGutter(
      {required this.hStart, required this.hEnd, required this.pxPerHour});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _gutter,
      child: Column(
        children: [
          for (int h = hStart; h < hEnd; h++)
            SizedBox(
              height: pxPerHour,
              child: Padding(
                padding: const EdgeInsets.only(right: 4, top: 2),
                child: Text('${h.toString().padLeft(2, '0')}:00',
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.labelSmall),
              ),
            ),
        ],
      ),
    );
  }
}

class _DayColumn extends StatelessWidget {
  final DateTime day;
  final List<ClassEvent> events;
  final int hStart;
  final double pxPerHour;
  final bool detailed;
  final String? selectedUid;
  final void Function(ClassEvent) onTap;
  const _DayColumn({
    required this.day,
    required this.events,
    required this.hStart,
    required this.pxPerHour,
    required this.detailed,
    required this.selectedUid,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final placed = _layout(events);
    return Container(
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          return Stack(
            children: [
              for (int i = 0; (i * pxPerHour) < box.maxHeight; i++)
                Positioned(
                  top: i * pxPerHour,
                  left: 0,
                  right: 0,
                  child: Divider(
                      height: 1,
                      color: Theme.of(context).dividerColor.withValues(alpha: 0.4)),
                ),
              for (final p in placed)
                Positioned(
                  top: (p.start - hStart * 60) * pxPerHour / 60,
                  height: (p.end - p.start) * pxPerHour / 60 - 2,
                  left: (p.lane * w / p.lanes) + 1,
                  width: w / p.lanes - 2,
                  child: _EventBlock(
                    e: p.e,
                    detailed: detailed,
                    selected: selectedUid != null &&
                        occurrenceUid(p.e, day) == selectedUid,
                    onTap: () => onTap(p.e),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  List<_Placed> _layout(List<ClassEvent> events) {
    final items = <_Placed>[];
    for (final e in events) {
      final s = _min(e.odGodzina), en = _min(e.doGodzina);
      if (s == null) continue;
      items.add(_Placed(e, s, (en != null && en > s) ? en : s + 45));
    }
    items.sort((a, b) =>
        a.start != b.start ? a.start.compareTo(b.start) : a.end.compareTo(b.end));
    var cluster = <_Placed>[];
    int clusterEnd = -1;
    void flush() {
      if (cluster.isEmpty) return;
      final laneEnds = <int>[];
      for (final p in cluster) {
        var lane = laneEnds.indexWhere((end) => end <= p.start);
        if (lane == -1) {
          lane = laneEnds.length;
          laneEnds.add(p.end);
        } else {
          laneEnds[lane] = p.end;
        }
        p.lane = lane;
      }
      for (final p in cluster) {
        p.lanes = laneEnds.length;
      }
      cluster = [];
      clusterEnd = -1;
    }

    for (final p in items) {
      if (cluster.isNotEmpty && p.start >= clusterEnd) flush();
      cluster.add(p);
      clusterEnd = clusterEnd > p.end ? clusterEnd : p.end;
    }
    flush();
    return items;
  }
}

class _Placed {
  final ClassEvent e;
  final int start, end;
  int lane = 0, lanes = 1;
  _Placed(this.e, this.start, this.end);
}

class _EventBlock extends StatelessWidget {
  final ClassEvent e;
  final bool selected;
  final bool detailed;
  final VoidCallback onTap;
  const _EventBlock(
      {required this.e,
      required this.onTap,
      this.selected = false,
      this.detailed = false});

  @override
  Widget build(BuildContext context) {
    final c = _typeColor(e.typPrzedmiotu, context);
    final online = isOnline(e);
    final rNum = roomNumber(e.sala);
    final roomLine = online
        ? 'Online'
        : rNum.isNotEmpty
            ? '${roomCode(e.sala)} ($rNum)'
            : roomCode(e.sala);
    const white = TextStyle(color: Colors.white);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.9), // opaque (#2)
          borderRadius: BorderRadius.circular(4),
          border: selected
              ? Border.all(color: Colors.white, width: 2)
              : Border(left: BorderSide(color: _darken(c), width: 3)),
        ),
        clipBehavior: Clip.hardEdge,
        // Fade the bottom edge so clipped text fades out instead of a hard cut (#3)
        child: ShaderMask(
          shaderCallback: (rect) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Colors.white, Colors.transparent],
            stops: [0.0, 0.85, 1.0],
          ).createShader(rect),
          blendMode: BlendMode.dstIn,
          child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: detailed ? 10 : 4, vertical: detailed ? 6 : 2),
            child: detailed
                // Day view: bigger font + all details in the box (#1)
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${e.odGodzina}–${e.doGodzina}',
                          style: white.copyWith(
                              fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(e.przedmiot,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: white.copyWith(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                      Text('${abbrevType(e.typPrzedmiotu)} · ${e.typPrzedmiotu}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: white.copyWith(fontSize: 12)),
                      if (e.lecturer.isNotEmpty)
                        Text(e.lecturer,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: white.copyWith(fontSize: 12)),
                      if (e.sala.isNotEmpty)
                        Text(roomLine,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: white.copyWith(fontSize: 12)),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          '${e.odGodzina} · ${abbrevType(e.typPrzedmiotu)}\n${e.przedmiot}',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: white.copyWith(
                              fontSize: 11, fontWeight: FontWeight.w600)),
                      if (e.sala.isNotEmpty)
                        Text(online ? 'Online' : roomCode(e.sala),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: white.copyWith(fontSize: 10)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Color _darken(Color c) =>
      HSLColor.fromColor(c).withLightness(
          (HSLColor.fromColor(c).lightness - 0.15).clamp(0.0, 1.0)).toColor();
}

// --------------------------------------------------------------- detail panel
class _DetailPanel extends StatelessWidget {
  final _Selected sel;
  final AppText t;
  final VoidCallback onClose;
  final Future<void> Function(ClassEvent) onMap;
  const _DetailPanel(
      {required this.sel,
      required this.t,
      required this.onClose,
      required this.onMap});

  @override
  Widget build(BuildContext context) {
    final e = sel.event;
    final c = _typeColor(e.typPrzedmiotu, context);
    final online = isOnline(e);
    final hasGeo = e.salaLat != null && e.salaLong != null && !online;
    final rNum = online ? '' : roomNumber(e.sala);
    final primary = Theme.of(context).colorScheme.primary;
    return Material(
      elevation: 8,
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: c, width: 3)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(e.przedmiot,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close),
                  onPressed: onClose,
                ),
              ],
            ),
            // full type name (#1)
            Text(
              '${e.typPrzedmiotu} · ${DateFormat('EEEE, d MMM').format(sel.day)}'
              ' · ${e.odGodzina}–${e.doGodzina}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (e.lecturer.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(e.lecturer, style: Theme.of(context).textTheme.bodySmall),
              ),
            if (online)
              _row(context, Icons.videocam_outlined,
                  e.sala.isNotEmpty ? e.sala : t.online)
            else ...[
              // room number row (#4)
              if (rNum.isNotEmpty)
                _row(context, Icons.meeting_room_outlined, '${t.room}: $rNum'),
              // clickable map address (#4) — only when we have coordinates (#3)
              if (hasGeo && e.salaAdres.isNotEmpty)
                InkWell(
                  onTap: () => onMap(e),
                  child: _row(context, Icons.place_outlined,
                      '${e.salaAdres}  ·  ${t.mapLabel}',
                      color: primary),
                ),
              // raw location row (#4)
              if (e.sala.isNotEmpty)
                _row(context, Icons.info_outline, e.sala),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, IconData icon, String text, {Color? color}) =>
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color)),
          ),
        ]),
      );
}

// --------------------------------------------------------------------- month
class _MonthView extends StatelessWidget {
  final DateTime month;
  final Map<DateTime, List<ClassEvent>> byDay;
  final List<String> dayAbbr;
  final void Function(DateTime) onSelectDay;
  const _MonthView({
    required this.month,
    required this.byDay,
    required this.dayAbbr,
    required this.onSelectDay,
  });

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final gridStart = first.subtract(Duration(days: first.weekday - 1));
    final today = dayKey(DateTime.now());
    return Column(
      children: [
        Row(
          children: [
            for (final d in dayAbbr)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Center(
                      child: Text(d, style: Theme.of(context).textTheme.labelSmall)),
                ),
              ),
          ],
        ),
        Expanded(
          child: GridView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            // fixed, comfortable cell height so the month scrolls instead of
            // cramming 6 tiny rows into the viewport (#2)
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7, mainAxisExtent: 104),
            itemCount: 42,
            itemBuilder: (context, i) {
              final day = gridStart.add(Duration(days: i));
              final inMonth = day.month == month.month;
              final evs = byDay[dayKey(day)] ?? const [];
              return InkWell(
                onTap: () => onSelectDay(day),
                child: Container(
                  clipBehavior: Clip.hardEdge,
                  decoration: BoxDecoration(
                    color: inMonth
                        ? null
                        : Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.4),
                    border: Border.all(
                        color: Theme.of(context).dividerColor.withValues(alpha: 0.4)),
                  ),
                  padding: const EdgeInsets.all(3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: dayKey(day) == today
                                ? Theme.of(context).colorScheme.primary
                                : Colors.transparent,
                          ),
                          child: Center(
                            child: Text('${day.day}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: dayKey(day) == today
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : inMonth
                                          ? null
                                          : Theme.of(context).disabledColor,
                                )),
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      for (final e in evs.take(4))
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          padding:
                              const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                          decoration: BoxDecoration(
                            color: _typeColor(e.typPrzedmiotu, context)
                                .withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                              '${e.odGodzina} ${abbrevType(e.typPrzedmiotu)} ${e.przedmiot}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 9, color: Colors.white)),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
