import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/client.dart';
import '../api/models.dart';
import '../state/app_state.dart';
import '../state/settings.dart';
import 'settings_screen.dart' show kAppVersion, kLegalese;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _login = TextEditingController();
  final _password = TextEditingController();
  List<College>? _colleges;
  College? _college;
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    _login.text = app.lastLogin ?? '';
    _password.text = app.lastPassword ?? '';
    _loadColleges();
  }

  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _loadColleges() async {
    try {
      final cols = await MStudentClient.discoverColleges();
      cols.sort((a, b) => a.name.compareTo(b.name));
      if (!mounted) return;
      final last = context.read<AppState>().lastCollege;
      setState(() {
        _colleges = cols;
        if (last != null) {
          for (final c in cols) {
            if (c.baseUrl == last.baseUrl) _college = c;
          }
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = '${context.read<AppState>().text.discoverError}: $e');
      }
    }
  }

  bool get _looksLikeEmail => _login.text.contains('@');

  Future<void> _submit() async {
    final t = context.read<AppState>().text;
    if (_college == null || _login.text.isEmpty || _password.text.isEmpty) {
      setState(() => _error = t.pickCollege);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AppState>().login(
            college: _college!,
            login: _login.text.trim(),
            password: _password.text,
          );
    } on ApiException catch (e) {
      setState(() => _error = e.isUnauthorized
          ? t.badCredentials
          : '${t.loginError} (${e.statusCode}).');
    } catch (e) {
      setState(() => _error = '${t.connError}: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _about(AppState s) => showAboutDialog(
        context: context,
        applicationName: 'Kulindeks',
        applicationVersion: kAppVersion,
        applicationLegalese: kLegalese,
        children: [
          const SizedBox(height: 8),
          Text(s.text.aboutBody),
          const SizedBox(height: 12),
          Text(s.text.notAffiliated, style: Theme.of(context).textTheme.bodySmall),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final t = s.text;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.school_outlined, size: 64, color: cs.primary),
                  const SizedBox(height: 8),
                  Text('Kulindeks',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 24),
                  if (_colleges == null)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    DropdownButtonFormField<College>(
                      initialValue: _college,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: t.university,
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        for (final c in _colleges!)
                          DropdownMenuItem(
                            value: c,
                            child: Text(c.name, overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (c) => setState(() => _college = c),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _login,
                    autofillHints: const [AutofillHints.username],
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: t.login,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                  ),
                  if (_looksLikeEmail)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 4, right: 4),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 16, color: cs.error),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(t.emailWarning,
                                style: TextStyle(fontSize: 12, color: cs.error)),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: _obscure,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: t.password,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: cs.error)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(t.signIn),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 8),
                  // Visible, labeled preference controls (#1)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(t.language,
                        style: Theme.of(context).textTheme.labelMedium),
                  ),
                  const SizedBox(height: 6),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'pl', label: Text('🇵🇱 Polski')),
                      ButtonSegment(value: 'en', label: Text('🇬🇧 English')),
                    ],
                    selected: {s.prefs.locale},
                    showSelectedIcon: false,
                    onSelectionChanged: (v) => s.setLocale(v.first),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _LabeledDropdown<AppThemeMode>(
                          label: t.theme,
                          value: s.prefs.theme,
                          items: {
                            AppThemeMode.system: t.themeSystem,
                            AppThemeMode.light: t.themeLight,
                            AppThemeMode.dark: t.themeDark,
                            AppThemeMode.highContrast: t.themeHighContrast,
                          },
                          onChanged: (v) => s.setTheme(v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _LabeledDropdown<double>(
                          label: t.fontScale,
                          value: s.prefs.fontScale,
                          items: {
                            for (final v in [0.8, 0.9, 1.0, 1.1, 1.25, 1.5])
                              v: '${(v * 100).round()}%',
                          },
                          onChanged: (v) => s.setFontScale(v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton.icon(
                      icon: const Icon(Icons.info_outline, size: 18),
                      label: Text(t.about),
                      onPressed: () => _about(s),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LabeledDropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;
  const _LabeledDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final e in items.entries)
          DropdownMenuItem(
              value: e.key,
              child: Text(e.value, overflow: TextOverflow.ellipsis)),
      ],
      onChanged: (v) => v == null ? null : onChanged(v),
    );
  }
}
