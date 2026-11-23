import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/caldav.dart';
import '../api/models.dart';
import '../state/app_state.dart';
import '../state/settings.dart';
import 'util.dart';

const kAppVersion = '0.1.0';

const kAccentPalette = [
  '#2962FF', // blue (default)
  '#3F51B5', // indigo
  '#009688', // teal
  '#2E7D32', // green
  '#F59E0B', // amber
  '#E64A19', // deep orange
  '#C62828', // red
  '#7B1FA2', // purple
  '#D81B60', // pink
  '#455A64', // slate
];

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _store = SettingsStore();
  final _server = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _cal = TextEditingController(text: 'kulindeks');
  bool _loaded = false;
  bool _busy = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_server, _user, _pass, _cal]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final c = await _store.loadNextcloud();
    _server.text = c.serverUrl;
    _user.text = c.username;
    _pass.text = c.appPassword;
    _cal.text = c.calendar;
    setState(() => _loaded = true);
  }

  NextcloudConfig get _config => NextcloudConfig(
        serverUrl: _server.text.trim(),
        username: _user.text.trim(),
        appPassword: _pass.text,
        calendar: _cal.text.trim().isEmpty ? 'kulindeks' : _cal.text.trim(),
      );

  Future<void> _syncNow() async {
    final t = context.read<AppState>().text;
    final cfg = _config;
    if (!cfg.isComplete) {
      setState(() => _status = t.fillNextcloud);
      return;
    }
    final events = context.read<AppState>().timetable.value ?? const <ClassEvent>[];
    if (events.isEmpty) {
      setState(() => _status = t.noPlanToSync);
      return;
    }
    await _store.saveNextcloud(cfg);
    setState(() {
      _busy = true;
      _status = null;
    });
    final client = CaldavClient(cfg);
    try {
      final res = await client.push(expandOccurrences(events));
      setState(() => _status = res.ok
          ? '✓ ${t.syncOk}: ${res.pushed} → „${cfg.calendar}"'
          : '${t.syncPartial} ${res.pushed}, ${res.failed} ✗: ${res.errors.join("; ")}');
    } catch (e) {
      setState(() => _status = '${t.syncError}: $e');
    } finally {
      client.close();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final t = s.text;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t.settings),
          bottom: TabBar(
            tabs: [
              Tab(text: t.appearance),
              Tab(text: t.tabSync),
              Tab(text: t.tabAbout),
            ],
          ),
        ),
        body: !_loaded
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _appearanceTab(context, s, t),
                  _syncTab(context, t),
                  _aboutTab(context, t),
                ],
              ),
      ),
    );
  }

  // ------------------------------------------------------------- Wygląd
  Widget _appearanceTab(BuildContext context, AppState s, dynamic t) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(t.theme as String, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: [
            for (final e in {
              AppThemeMode.system: t.themeSystem as String,
              AppThemeMode.light: t.themeLight as String,
              AppThemeMode.dark: t.themeDark as String,
              AppThemeMode.highContrast: t.themeHighContrast as String,
            }.entries)
              ChoiceChip(
                label: Text(e.value),
                selected: s.prefs.theme == e.key,
                onSelected: (_) => s.setTheme(e.key),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Text(t.language as String,
                style: Theme.of(context).textTheme.labelLarge),
            const Spacer(),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'pl', label: Text('🇵🇱 Polski')),
                ButtonSegment(value: 'en', label: Text('🇬🇧 English')),
              ],
              selected: {s.prefs.locale},
              showSelectedIcon: false,
              onSelectionChanged: (v) => s.setLocale(v.first),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(t.accentColor as String,
            style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final hex in kAccentPalette)
              _Swatch(
                hex: hex,
                selected: s.prefs.accentColor.toLowerCase() == hex.toLowerCase(),
                onTap: () => s.setAccent(hex),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text('${t.fontScale}  (${(s.prefs.fontScale * 100).round()}%)',
            style: Theme.of(context).textTheme.labelLarge),
        Slider(
          value: s.prefs.fontScale,
          min: 0.8,
          max: 1.5,
          divisions: 7,
          label: '${(s.prefs.fontScale * 100).round()}%',
          onChanged: (v) => s.setFontScale(v),
        ),
        const Divider(height: 28),
        Text(t.notifications as String,
            style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          initialValue: s.prefs.notifLeadMinutes,
          decoration: InputDecoration(
              labelText: t.notifLead as String,
              border: const OutlineInputBorder()),
          items: [
            DropdownMenuItem(value: 0, child: Text(t.notifOff as String)),
            for (final m in [5, 10, 15, 30, 60])
              DropdownMenuItem(value: m, child: Text('$m ${t.notifMinutes}')),
          ],
          onChanged: (v) => v == null ? null : s.setNotifLead(v),
        ),
      ],
    );
  }

  // ----------------------------------------------------- Synchronizacja
  Widget _syncTab(BuildContext context, dynamic t) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(t.nextcloudTitle as String,
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(t.nextcloudHint as String,
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        _field(_server, t.serverAddress as String, hint: 'https://cloud.example.com'),
        const SizedBox(height: 12),
        _field(_user, t.username as String),
        const SizedBox(height: 12),
        _field(_pass, t.appPassword as String, obscure: true),
        const SizedBox(height: 12),
        _field(_cal, t.calendarName as String),
        if (_status != null) ...[
          const SizedBox(height: 16),
          Text(_status!,
              style: TextStyle(color: Theme.of(context).colorScheme.primary)),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _busy ? null : _syncNow,
          icon: _busy
              ? const SizedBox(
                  height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.cloud_sync_outlined),
          label: Text(t.syncNow as String),
        ),
        const SizedBox(height: 16),
        Text(t.autoSyncNote as String, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  // ----------------------------------------------------------- Informacje
  Widget _aboutTab(BuildContext context, dynamic t) {
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: Text(t.version as String),
          subtitle: const Text('Kulindeks $kAppVersion'),
        ),
        ListTile(
          leading: const Icon(Icons.description_outlined),
          title: Text(t.licenses as String),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showLicensePage(
            context: context,
            applicationName: 'Kulindeks',
            applicationVersion: kAppVersion,
          ),
        ),
        ListTile(
          leading: const Icon(Icons.help_outline),
          title: Text(t.about as String),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showAboutDialog(
            context: context,
            applicationName: 'Kulindeks',
            applicationVersion: kAppVersion,
            children: [
              Text(t.aboutBody as String),
              const SizedBox(height: 12),
              Text(t.notAffiliated as String,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(t.notAffiliated as String,
              style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }

  Widget _field(TextEditingController c, String label,
          {String? hint, bool obscure = false}) =>
      TextField(
        controller: c,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
      );
}

class _Swatch extends StatelessWidget {
  final String hex;
  final bool selected;
  final VoidCallback onTap;
  const _Swatch({required this.hex, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = hexColor(hex);
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.onSurface
                : Colors.transparent,
            width: 3,
          ),
        ),
        child: selected
            ? const Icon(Icons.check, color: Colors.white, size: 20)
            : null,
      ),
    );
  }
}
