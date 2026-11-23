import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../state/app_state.dart';
import 'message_detail_screen.dart';
import 'widgets.dart';

class MessagesTab extends StatelessWidget {
  const MessagesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final t = s.text;
    final df = DateFormat('d MMM, HH:mm');
    return ResourceView<List<MessageHeader>>(
      resource: s.messages,
      isEmpty: (v) => v.isEmpty,
      onRefresh: s.refreshMessages,
      emptyText: t.noMessages,
      builder: (context, msgs) => ListView.separated(
        itemCount: msgs.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final m = msgs[i];
          return ListTile(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => MessageDetailScreen(header: m))),
            leading: Icon(
              m.przeczytana ? Icons.drafts_outlined : Icons.mark_email_unread,
              color: m.przeczytana
                  ? Theme.of(context).disabledColor
                  : Theme.of(context).colorScheme.primary,
            ),
            title: Text(
              m.temat.isEmpty ? t.noSubject : m.temat,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontWeight: m.przeczytana ? FontWeight.normal : FontWeight.bold),
            ),
            subtitle: Text(m.osoba, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: m.data == null
                ? null
                : Text(df.format(m.data!),
                    style: Theme.of(context).textTheme.bodySmall),
          );
        },
      ),
    );
  }
}
