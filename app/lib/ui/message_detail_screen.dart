import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/models.dart';
import '../l10n/strings.dart';
import '../state/app_state.dart';

class MessageDetailScreen extends StatefulWidget {
  final MessageHeader header;
  const MessageDetailScreen({super.key, required this.header});
  @override
  State<MessageDetailScreen> createState() => _MessageDetailScreenState();
}

class _MessageDetailScreenState extends State<MessageDetailScreen> {
  MessageDetail? _msg;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final m = await context.read<AppState>().loadMessage(widget.header.id);
      if (mounted) setState(() => _msg = m);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = _msg;
    final t = context.watch<AppState>().text;
    return Scaffold(
      appBar: AppBar(title: Text(t.message)),
      body: _error != null
          ? _retry()
          : m == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(m.temat.isEmpty ? t.noSubject : m.temat,
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Row(children: [
                      const Icon(Icons.person_outline, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(m.nadawca)),
                      if (m.data != null)
                        Text(DateFormat('d MMM yyyy, HH:mm').format(m.data!),
                            style: Theme.of(context).textTheme.bodySmall),
                    ]),
                    const Divider(height: 24),
                    SelectableText(_htmlToText(m.tresc),
                        style: Theme.of(context).textTheme.bodyMedium),
                    if (m.zalaczniki.isNotEmpty) ...[
                      const Divider(height: 24),
                      Text('${t.attachments} (${m.zalaczniki.length})',
                          style: Theme.of(context).textTheme.titleSmall),
                      for (final a in m.zalaczniki)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.attach_file),
                          title: Text(a.nazwa),
                          trailing: const Icon(Icons.open_in_new, size: 18),
                          dense: true,
                          onTap: () => _attachmentDialog(context, t),
                        ),
                    ],
                  ],
                ),
    );
  }

  Future<void> _attachmentDialog(BuildContext context, AppText t) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.attach_file),
        title: Text(t.attachmentTitle),
        content: Text(t.attachmentBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(t.close),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.open_in_new, size: 18),
            label: Text(t.openWu),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final uri = Uri.parse('https://wu.umw.edu.pl');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _retry() {
    final t = context.read<AppState>().text;
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('${t.loadFailed}: $_error'),
        const SizedBox(height: 12),
        FilledButton.tonal(
            onPressed: () {
              setState(() => _error = null);
              _load();
            },
            child: Text(t.retry)),
      ]),
    );
  }
}

/// Very small HTML → plain text (the API returns light HTML in message bodies).
String _htmlToText(String html) {
  var s = html
      .replaceAll(RegExp(r'<\s*br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</\s*p\s*>', caseSensitive: false), '\n\n')
      .replaceAll(RegExp(r'<[^>]+>'), '');
  const entities = {
    '&nbsp;': ' ', '&amp;': '&', '&lt;': '<', '&gt;': '>',
    '&quot;': '"', '&#39;': "'",
  };
  entities.forEach((k, v) => s = s.replaceAll(k, v));
  // numeric entities like &#324;
  s = s.replaceAllMapped(RegExp(r'&#(\d+);'),
      (m) => String.fromCharCode(int.parse(m[1]!)));
  return s.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}
