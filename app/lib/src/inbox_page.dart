import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import 'app_state.dart';
import 'format_net.dart';
import 'theme.dart';
import 'widgets.dart';

/// Every alert the server sent, newest first. Works without push permission.
class InboxPage extends StatelessWidget {
  const InboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    final account = LaunchWatchScope.of(context);
    final messages = account.inbox;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alerts'),
        actions: [
          if (account.unread > 0) TextButton(onPressed: account.markAllRead, child: const Text('Mark all read')),
          if (messages.isNotEmpty)
            PopupMenuButton<String>(
              tooltip: 'More',
              onSelected: (_) => account.clearInbox(),
              itemBuilder: (_) => const [PopupMenuItem(value: 'clear', child: Text('Clear all'))],
            ),
        ],
      ),
      body: messages.isEmpty
          ? const EmptyState(
              icon: Icons.notifications_none,
              title: 'No alerts yet',
              body: 'Follow a launch and changes to it will show up here, even if notifications are off.',
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: messages.length,
              separatorBuilder: (_, _) => const Divider(indent: 56),
              itemBuilder: (context, i) {
                final m = messages[i];
                final icon = switch (m.kind) {
                  'liftoff' => Icons.rocket_launch,
                  'outcome' => Icons.flag_outlined,
                  'slips' => Icons.update,
                  'reminder24h' => Icons.alarm,
                  _ => Icons.info_outline,
                };
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  leading: Stack(clipBehavior: Clip.none, children: [
                    Icon(icon, color: m.read ? launchInkMuted : launchAccent),
                    if (!m.read) const Positioned(right: -3, top: -3, child: CircleAvatar(radius: 4, backgroundColor: launchLive)),
                  ]),
                  title: Text(m.title, style: TextStyle(fontWeight: m.read ? FontWeight.w400 : FontWeight.w600)),
                  subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (m.body.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(m.body)),
                    if (m.createdAt != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('${relativeAge(m.createdAt!)} · ${DateFormat.MMMd().add_jm().format(m.createdAt!.toLocal())}', style: const TextStyle(color: launchInkFaint, fontSize: 12)),
                      ),
                  ]),
                  onTap: () {
                    account.markRead(m);
                    if (m.launchId != null) openLaunch(context, m.launchId!);
                  },
                );
              },
            ),
    );
  }
}
