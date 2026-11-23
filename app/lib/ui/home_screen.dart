import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import 'dashboard_tab.dart';
import 'finance_tab.dart';
import 'grades_tab.dart';
import 'messages_tab.dart';
import 'settings_screen.dart';
import 'timetable_tab.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _tabs = [
    DashboardTab(),
    TimetableTab(),
    GradesTab(),
    FinanceTab(),
    MessagesTab(),
  ];

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final t = s.text;
    final titles = [t.dashboard, t.timetable, t.grades, t.finance, t.messages];
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Scaffold(
      appBar: AppBar(
        // keep a flat bar: don't tint when content scrolls under it (#3)
        scrolledUnderElevation: 0,
        title: Text(titles[s.tab]),
        actions: [
          const _LangFlag(),
          _RefreshButton(spinning: s.refreshing, onPressed: () => s.refreshAll()),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            color: onSurface,
            tooltip: t.settings,
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
          PopupMenuButton<String>(
            iconColor: onSurface,
            onSelected: (v) {
              if (v == 'logout') s.logout();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Text('${s.userName ?? ''}\n${s.collegeName}',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(value: 'logout', child: Text(t.logout)),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (s.offline) _OfflineBar(text: t.offline),
          Expanded(child: IndexedStack(index: s.tab, children: _tabs)),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: s.tab,
        onDestinationSelected: s.goToTab,
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.dashboard_outlined), label: t.dashboard),
          NavigationDestination(
              icon: const Icon(Icons.calendar_today_outlined), label: t.timetable),
          NavigationDestination(
              icon: const Icon(Icons.grade_outlined), label: t.grades),
          NavigationDestination(
              icon: const Icon(Icons.payments_outlined), label: t.finance),
          NavigationDestination(
              icon: const Icon(Icons.mail_outline), label: t.messages),
        ],
      ),
    );
  }
}

/// Clickable language flag → menu of languages with flags (#9).
class _LangFlag extends StatelessWidget {
  const _LangFlag();
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return PopupMenuButton<String>(
      tooltip: s.text.language,
      onSelected: (l) => s.setLocale(l),
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'pl', child: Text('🇵🇱  Polski')),
        PopupMenuItem(value: 'en', child: Text('🇬🇧  English')),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Center(
          child: Text(s.prefs.locale == 'en' ? '🇬🇧' : '🇵🇱',
              style: const TextStyle(fontSize: 22)),
        ),
      ),
    );
  }
}

/// Plain (un-tinted) refresh icon that spins while refreshing (#8).
class _RefreshButton extends StatefulWidget {
  final bool spinning;
  final VoidCallback onPressed;
  const _RefreshButton({required this.spinning, required this.onPressed});
  @override
  State<_RefreshButton> createState() => _RefreshButtonState();
}

class _RefreshButtonState extends State<_RefreshButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void initState() {
    super.initState();
    if (widget.spinning) _c.repeat();
  }

  @override
  void didUpdateWidget(_RefreshButton old) {
    super.didUpdateWidget(old);
    if (widget.spinning && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.spinning && _c.isAnimating) {
      _c.stop();
      _c.animateTo(0, duration: const Duration(milliseconds: 150));
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: context.read<AppState>().text.refresh,
      onPressed: widget.spinning ? null : widget.onPressed,
      icon: RotationTransition(
        turns: _c,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}

class _OfflineBar extends StatelessWidget {
  final String text;
  const _OfflineBar({required this.text});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.errorContainer,
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off, size: 16, color: cs.onErrorContainer),
              const SizedBox(width: 8),
              Flexible(
                child: Text(text,
                    style: TextStyle(color: cs.onErrorContainer, fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
