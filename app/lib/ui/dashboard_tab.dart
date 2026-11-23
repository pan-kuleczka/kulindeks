import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../state/app_state.dart';
import 'student_info_screen.dart';
import 'util.dart';
import 'widgets.dart';

class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return RefreshIndicator(
      onRefresh: s.refreshAll,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const _IdentityCard(),
          const SizedBox(height: 10),
          _NextClassCard(events: s.timetable.value ?? const []),
          const SizedBox(height: 8),
          _StatGrid(s: s),
        ],
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard();
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final info = s.info.value ?? const {};
    final cs = Theme.of(context).colorScheme;
    final name = s.userName ??
        [info['imie'], info['nazwisko']]
            .whereType<String>()
            .where((e) => e.isNotEmpty)
            .join(' ');
    final album = info['numerAlbumu']?.toString();
    return Card(
      // tinted to hint it's tappable
      color: cs.secondaryContainer,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const StudentInfoScreen())),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                child: Text(_initials(name)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name.isEmpty ? '—' : name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: cs.onSecondaryContainer,
                            fontWeight: FontWeight.bold)),
                    if (album != null)
                      Text('${s.text.albumNo}: $album',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.onSecondaryContainer)),
                    Text(s.collegeName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSecondaryContainer)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: cs.onSecondaryContainer),
            ],
          ),
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.split(' ').where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return parts.length == 1
        ? parts.first.characters.first.toUpperCase()
        : (parts.first.characters.first + parts.last.characters.first)
            .toUpperCase();
  }
}

class _NextClassCard extends StatelessWidget {
  final List<ClassEvent> events;
  const _NextClassCard({required this.events});

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final t = app.text;
    final next = _nextClass(events);
    final cs = Theme.of(context).colorScheme;
    if (next == null) {
      return Card(
        color: cs.surfaceContainerHighest,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => app.goToTab(1),
          child: ListTile(
            leading: const Icon(Icons.free_breakfast_outlined),
            title: Text(t.noUpcoming),
          ),
        ),
      );
    }
    final (e, at) = next;
    final df = DateFormat('EEEE, d MMM');
    return Card(
      color: cs.primaryContainer,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => app.focusClass(e, at),
        child: Padding(
          padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.schedule, color: cs.onPrimaryContainer, size: 18),
              const SizedBox(width: 8),
              Text(t.nextClass,
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: cs.onPrimaryContainer)),
            ]),
            const SizedBox(height: 8),
            Text(e.przedmiot,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(color: cs.onPrimaryContainer)),
            Text('${df.format(at)} · ${e.odGodzina}–${e.doGodzina}',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: cs.onPrimaryContainer)),
            if (e.sala.isNotEmpty)
              Text('${e.typPrzedmiotu} · ${e.sala}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: cs.onPrimaryContainer)),
            ],
          ),
        ),
      ),
    );
  }

  (ClassEvent, DateTime)? _nextClass(List<ClassEvent> events) {
    final now = DateTime.now();
    final byDay = expandOccurrences(events);
    (ClassEvent, DateTime)? best;
    byDay.forEach((day, dayEvents) {
      for (final e in dayEvents) {
        final hm = RegExp(r'(\d{1,2})[:.](\d{2})').firstMatch(e.odGodzina);
        if (hm == null) continue;
        final at = DateTime(day.year, day.month, day.day,
            int.parse(hm[1]!), int.parse(hm[2]!));
        if (at.isBefore(now)) continue;
        if (best == null || at.isBefore(best!.$2)) best = (e, at);
      }
    });
    return best;
  }
}

class _StatGrid extends StatelessWidget {
  final AppState s;
  const _StatGrid({required this.s});

  @override
  Widget build(BuildContext context) {
    final t = s.text;
    final grades = s.grades.value ?? const [];
    final gpa = weightedGpa(grades);
    final dues = s.dues.value ?? const [];
    final outstanding =
        dues.where((d) => !d.oplacono).fold<double>(0, (a, d) => a + d.pozostalo);
    final currency = dues.isNotEmpty ? dues.first.waluta : 'PLN';
    final unread = (s.messages.value ?? const []).where((m) => !m.przeczytana).length;

    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        mainAxisExtent: 126,
      ),
      children: [
        StatCard(
          icon: Icons.calculate_outlined,
          label: t.average,
          value: gpa?.toStringAsFixed(2) ?? '—',
          sub: '${grades.length} ${t.subjectsCount}',
          color: gradeColor(gpa, context),
          onTap: () => s.goToTab(2),
        ),
        StatCard(
          icon: Icons.payments_outlined,
          label: t.due,
          value: NumberFormat.currency(locale: 'pl_PL', symbol: currency)
              .format(outstanding),
          color: outstanding > 0 ? Colors.red.shade600 : Colors.green.shade600,
          onTap: () => s.goToTab(3),
        ),
        StatCard(
          icon: Icons.mail_outline,
          label: t.unread,
          value: '$unread',
          sub: t.messagesCount,
          onTap: () => s.goToTab(4),
        ),
        StatCard(
          icon: Icons.event_available_outlined,
          label: t.plannedClasses,
          value: '${(s.timetable.value ?? const []).length}',
          onTap: () => s.goToTab(1),
        ),
      ],
    );
  }
}
