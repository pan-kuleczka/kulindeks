import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../state/app_state.dart';
import 'widgets.dart';

class FinanceTab extends StatelessWidget {
  const FinanceTab({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final t = s.text;
    final stipends = s.stipends.value ?? const <Map<String, dynamic>>[];
    return ResourceView<List<Naleznosc>>(
      resource: s.dues,
      isEmpty: (v) => v.isEmpty && stipends.isEmpty,
      onRefresh: s.refreshDues,
      emptyText: t.noDues,
      builder: (context, dues) {
        final outstanding =
            dues.where((d) => !d.oplacono).fold<double>(0, (a, d) => a + d.pozostalo);
        final currency = dues.isNotEmpty ? dues.first.waluta : 'PLN';
        final fmt = NumberFormat.currency(locale: 'pl_PL', symbol: currency);
        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            if (dues.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: StatCard(
                  icon: Icons.account_balance_wallet_outlined,
                  label: t.due,
                  value: fmt.format(outstanding),
                  sub: '${dues.where((d) => !d.oplacono).length} ${t.unpaidN}',
                  color:
                      outstanding > 0 ? Colors.red.shade600 : Colors.green.shade600,
                ),
              ),
            for (final d in dues) _DueTile(d: d, fmt: fmt),
            // scholarships (#5)
            if (stipends.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(t.scholarships,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary)),
              ),
              for (final sp in stipends) _StipendTile(data: sp),
            ],
          ],
        );
      },
    );
  }
}

class _DueTile extends StatelessWidget {
  final Naleznosc d;
  final NumberFormat fmt;
  const _DueTile({required this.d, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        d.oplacono ? Icons.check_circle : Icons.pending_outlined,
        color: d.oplacono ? Colors.green.shade600 : Colors.orange.shade700,
      ),
      title: Text(d.tytul.isNotEmpty ? d.tytul : d.rodzaj,
          maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text([d.rodzaj, d.typ].where((x) => x.isNotEmpty).join(' · ')),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(fmt.format(d.kwota),
              style: const TextStyle(fontWeight: FontWeight.bold)),
          if (!d.oplacono && d.pozostalo > 0)
            Text('${context.read<AppState>().text.remaining} ${fmt.format(d.pozostalo)}',
                style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// Scholarship row — the API shape isn't fixed, so pull best-effort fields.
class _StipendTile extends StatelessWidget {
  final Map<String, dynamic> data;
  const _StipendTile({required this.data});

  Object? _first(List<String> keys) {
    for (final k in keys) {
      final v = data[k];
      if (v != null && v.toString().isNotEmpty) return v;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final title = _first(
            ['tytul', 'typStypendiumNazwa', 'rodzaj', 'typ', 'nazwa'])
        ?.toString();
    final amount = _first(['kwota', 'kwotaWyplaty', 'kwotaDoWyplaty', 'ma', 'wysokosc']);
    final date = _first(['data', 'dataWyplaty', 'miesiac', 'okres', 'terminWyplaty']);
    final waluta = data['waluta']?.toString() ?? 'PLN';
    return ListTile(
      leading: Icon(Icons.school_outlined,
          color: Theme.of(context).colorScheme.primary),
      title: Text(title ?? '—', maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: date == null ? null : Text(date.toString()),
      trailing: amount == null
          ? null
          : Text(
              amount is num
                  ? NumberFormat.currency(locale: 'pl_PL', symbol: waluta)
                      .format(amount)
                  : amount.toString(),
              style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}
