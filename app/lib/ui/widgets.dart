import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';

/// Renders a [Resource]: shows cached value immediately, a spinner only when
/// loading with no value, an error with retry, or an empty state.
class ResourceView<T> extends StatelessWidget {
  final Resource<T> resource;
  final bool Function(T value) isEmpty;
  final Widget Function(BuildContext, T value) builder;
  final Future<void> Function() onRefresh;
  final String emptyText;

  const ResourceView({
    super.key,
    required this.resource,
    required this.isEmpty,
    required this.builder,
    required this.onRefresh,
    this.emptyText = 'Brak danych',
  });

  @override
  Widget build(BuildContext context) {
    final r = resource;
    Widget child;
    if (!r.hasValue && r.loading) {
      child = const Center(child: CircularProgressIndicator());
    } else if (!r.hasValue && r.error != null) {
      child = _Error(error: r.error!, onRetry: onRefresh);
    } else if (!r.hasValue || isEmpty(r.value as T)) {
      child = _Empty(text: emptyText);
    } else {
      child = builder(context, r.value as T);
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: Stack(
        children: [
          Positioned.fill(child: child),
          if (r.loading && r.hasValue)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(minHeight: 2),
            ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final String text;
  const _Empty({required this.text});
  @override
  Widget build(BuildContext context) => ListView(
        children: [
          const SizedBox(height: 120),
          Icon(Icons.inbox_outlined,
              size: 56, color: Theme.of(context).disabledColor),
          const SizedBox(height: 12),
          Center(child: Text(text, style: Theme.of(context).textTheme.bodyLarge)),
        ],
      );
}

class _Error extends StatelessWidget {
  final Object error;
  final Future<void> Function() onRetry;
  const _Error({required this.error, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    final t = context.read<AppState>().text;
    return ListView(
      children: [
        const SizedBox(height: 100),
        Icon(Icons.error_outline,
            size: 56, color: Theme.of(context).colorScheme.error),
        const SizedBox(height: 12),
        Center(child: Text('${t.error}: $error', textAlign: TextAlign.center)),
        const SizedBox(height: 12),
        Center(
          child: FilledButton.tonal(onPressed: onRetry, child: Text(t.retry)),
        ),
      ],
    );
  }
}

/// Compact metric card for the dashboard.
class StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? sub;
  final Color? color;
  final VoidCallback? onTap;
  const StatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.sub,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icon, color: c, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(label,
                      style: Theme.of(context).textTheme.labelLarge,
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value,
                    maxLines: 1,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(color: c, fontWeight: FontWeight.bold)),
              ),
              if (sub != null)
                Text(sub!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
