import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../state/app_state.dart';
import 'util.dart';
import 'widgets.dart';

class GradesTab extends StatelessWidget {
  const GradesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final t = s.text;
    return Column(
      children: [
        _Selectors(s: s),
        Expanded(
          child: ResourceView<List<Grade>>(
            resource: s.grades,
            isEmpty: (v) => v.isEmpty,
            onRefresh: s.refreshGrades,
            emptyText: t.noGrades,
            builder: (context, grades) {
              final gpa = weightedGpa(grades);
              final mean = meanGrade(grades);
              final ects = grades.fold<double>(0, (a, g) => a + g.ects);
              return ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  _GpaHeader(gpa: gpa, mean: mean, ects: ects, count: grades.length),
                  for (final g in grades) _GradeTile(g: g),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Selectors extends StatelessWidget {
  final AppState s;
  const _Selectors({required this.s});

  @override
  Widget build(BuildContext context) {
    final t = s.text;
    final kier = s.kierunki.value ?? const [];
    final sems = s.semestry.value ?? const [];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<int>(
              initialValue: s.kierunekId,
              isExpanded: true,
              decoration: InputDecoration(
                  labelText: t.programme,
                  border: const OutlineInputBorder(),
                  isDense: true),
              items: [
                for (final k in kier)
                  DropdownMenuItem(
                      value: k.id,
                      child: Text(k.nazwa, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => v == null ? null : s.selectKierunek(v),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 1,
            child: DropdownButtonFormField<int>(
              initialValue: s.semestr,
              isExpanded: true,
              decoration: InputDecoration(
                  labelText: t.semShort,
                  border: const OutlineInputBorder(),
                  isDense: true),
              items: [
                for (final sem in sems)
                  DropdownMenuItem(value: sem.semestr, child: Text('${sem.semestr}')),
              ],
              onChanged: (v) => v == null ? null : s.selectSemestr(v),
            ),
          ),
        ],
      ),
    );
  }
}

class _GpaHeader extends StatelessWidget {
  final double? gpa;
  final double? mean;
  final double ects;
  final int count;
  const _GpaHeader(
      {required this.gpa, required this.mean, required this.ects, required this.count});

  @override
  Widget build(BuildContext context) {
    final t = context.read<AppState>().text;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: StatCard(
              icon: Icons.calculate_outlined,
              label: t.weightedAvg,
              value: gpa?.toStringAsFixed(2) ?? '—',
              sub: '${t.arithmetic}: ${mean?.toStringAsFixed(2) ?? "—"}',
              color: gradeColor(gpa, context),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StatCard(
              icon: Icons.workspace_premium_outlined,
              label: t.ectsSubjects,
              value: ects.toStringAsFixed(0),
              sub: '$count ${t.subjectsN}',
            ),
          ),
        ],
      ),
    );
  }
}

class _GradeTile extends StatelessWidget {
  final Grade g;
  const _GradeTile({required this.g});

  @override
  Widget build(BuildContext context) {
    final t = context.read<AppState>().text;
    final v = g.numeric;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: gradeColor(v, context).withValues(alpha: 0.15),
        child: Text(g.ocena ?? '—',
            style: TextStyle(
                color: gradeColor(v, context), fontWeight: FontWeight.bold)),
      ),
      title: Text(g.przedmiot, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          abbrevType(g.typPrzedmiotu),
          if (g.lecturer.isNotEmpty) g.lecturer,
          if (g.ects > 0) '${g.ects.toStringAsFixed(0)} ECTS',
          if (g.numerTerminu > 1) '${t.attempt} ${g.numerTerminu}',
        ].join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: g.typZakonczenia.isEmpty
          ? null
          : Text(g.typZakonczenia, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}
