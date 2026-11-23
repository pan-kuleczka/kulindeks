import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';

class StudentInfoScreen extends StatelessWidget {
  const StudentInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final info = s.info.value ?? const {};
    final en = s.prefs.locale == 'en';
    final photo = _decodePhoto(info['photo']);

    String v(Object? x) => x == null ? '—' : x.toString();
    final fullName = [info['imie'], info['drugieImie'], info['nazwisko']]
        .whereType<String>()
        .where((e) => e.isNotEmpty)
        .join(' ');

    final pesel = (info['pesel'] ?? '').toString();
    final rows = <(String, String, String)>[
      ('Nr albumu', 'Student ID', v(info['numerAlbumu'])),
      ('Data urodzenia', 'Date of birth', _date(info['dataUrodzenia'])),
      ('Miejsce urodzenia', 'Place of birth', v(info['miejsceUrodzenia'])),
      ('Obywatelstwo', 'Citizenship', v(_val(info['obywatelstwo']))),
      ('Adres zamieszkania', 'Residence', _address(info['adresZamieszkania'])),
      ('Adres korespondencyjny', 'Mailing address',
          _address(info['adresKorespondencyjny'])),
    ].where((r) => r.$3.isNotEmpty && r.$3 != '—').toList();

    return Scaffold(
      appBar: AppBar(title: Text(en ? 'Student info' : 'Dane studenta')),
      body: s.info.value == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 52,
                        backgroundColor:
                            Theme.of(context).colorScheme.surfaceContainerHighest,
                        backgroundImage:
                            photo != null ? MemoryImage(photo) : null,
                        child: photo == null
                            ? const Icon(Icons.person, size: 52)
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Text(fullName,
                          style: Theme.of(context).textTheme.titleLarge),
                      Text(s.collegeName,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                for (final r in rows)
                  ListTile(
                    dense: true,
                    title: Text(en ? r.$2 : r.$1,
                        style: Theme.of(context).textTheme.labelMedium),
                    subtitle: Text(r.$3,
                        style: Theme.of(context).textTheme.bodyLarge),
                  ),
                if (pesel.isNotEmpty)
                  ListTile(
                    dense: true,
                    title: Text(en ? 'National ID (PESEL)' : 'PESEL',
                        style: Theme.of(context).textTheme.labelMedium),
                    subtitle: _SecretText(value: pesel),
                  ),
                if ((s.groups.value ?? const []).isNotEmpty) ...[
                  const Divider(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(en ? 'Groups' : 'Grupy',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: Theme.of(context).colorScheme.primary)),
                  ),
                  for (final g in s.groups.value!)
                    ListTile(
                      leading: Icon(
                        g.aktywny ? Icons.group : Icons.group_outlined,
                        color: g.aktywny
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).disabledColor,
                      ),
                      title: Text(g.nazwa.isEmpty ? g.typGrupy : g.nazwa),
                      subtitle: Text([
                        if (g.typGrupy.isNotEmpty) g.typGrupy,
                        if (g.kierunek.isNotEmpty) g.kierunek,
                        if (g.specjalizacja.isNotEmpty) g.specjalizacja,
                        if (g.jezyk.isNotEmpty) g.jezyk,
                      ].join(' · ')),
                      trailing: g.rokAkademicki > 0
                          ? Text('${g.rokAkademicki}',
                              style: Theme.of(context).textTheme.labelSmall)
                          : null,
                    ),
                ],
              ],
            ),
    );
  }

  static Object? _val(Object? o) =>
      (o is Map && o['value'] != null) ? o['value'] : o;

  static String _date(Object? o) {
    if (o == null) return '';
    final s = o.toString();
    return s.length >= 10 ? s.substring(0, 10) : s;
  }

  static String _address(Object? o) {
    if (o is! Map) return '';
    final street = [o['ulica'], o['numerDomu']]
        .whereType<String>()
        .where((e) => e.isNotEmpty)
        .join(' ');
    final flat = (o['numerMieszkania'] as String?)?.isNotEmpty == true
        ? '/${o['numerMieszkania']}'
        : '';
    final city = [o['kodPocztowy'], o['miejscowosc']]
        .whereType<String>()
        .where((e) => e.isNotEmpty)
        .join(' ');
    return [if (street.isNotEmpty) '$street$flat', city]
        .where((e) => e.isNotEmpty)
        .join(', ');
  }

  static Uint8List? _decodePhoto(Object? o) {
    if (o is! String || o.isEmpty) return null;
    try {
      final b64 = o.contains(',') ? o.split(',').last : o;
      return base64.decode(b64);
    } catch (_) {
      return null;
    }
  }
}

/// Sensitive value that's masked until tapped (e.g. PESEL).
class _SecretText extends StatefulWidget {
  final String value;
  const _SecretText({required this.value});
  @override
  State<_SecretText> createState() => _SecretTextState();
}

class _SecretTextState extends State<_SecretText> {
  bool _shown = false;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => setState(() => _shown = !_shown),
      child: Row(
        children: [
          Text(_shown ? widget.value : '•' * widget.value.length,
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(width: 8),
          Icon(_shown ? Icons.visibility_off : Icons.visibility,
              size: 16, color: Theme.of(context).disabledColor),
        ],
      ),
    );
  }
}
