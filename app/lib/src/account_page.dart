import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'about_page.dart';
import 'account.dart';
import 'app_state.dart';
import 'glossary.dart';
import 'inbox_page.dart';
import 'install/install_tile.dart';
import 'launch_list_page.dart' show pickHomeCity;
import 'log_page.dart';
import 'sign_in_page.dart';
import 'theme.dart';
import 'widgets.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final account = LaunchWatchScope.of(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            ContentWidth(
              maxWidth: 640,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Semantics(header: true, child: Text('Account', style: Theme.of(context).textTheme.headlineMedium)),
                const SizedBox(height: 16),
                if (!account.ready)
                  const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
                else if (account.signedIn)
                  ..._signedIn(context, account)
                else
                  const _SignedOutCard(),
                InstallTile(
                  builder: (context, tile) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const SectionHeader(title: 'App'),
                    _Group(children: [tile]),
                  ]),
                ),
                const SectionHeader(title: 'Preferences'),
                _Group(children: [
                  ListTile(
                    leading: const Icon(Icons.location_city_outlined),
                    title: const Text('Where you watch from'),
                    subtitle: Text(account.homeCity?.label ?? 'Not set · used to estimate visibility'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => pickHomeCity(context),
                  ),
                  ListTile(
                    leading: const Icon(Icons.schedule_outlined),
                    title: const Text('Time zone'),
                    subtitle: Text('${account.timeZone} · follows this device'),
                  ),
                ]),
                const SectionHeader(title: 'Learn'),
                _Group(children: [
                  ListTile(
                    leading: const Icon(Icons.menu_book_outlined),
                    title: const Text('Glossary'),
                    subtitle: const Text('NET, LEO, scrubs, and other launch terms'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const GlossaryPage())),
                  ),
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('About LaunchWatch'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AboutPage())),
                  ),
                ]),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _signedIn(BuildContext context, AccountController account) {
    final name = account.displayName;
    final email = account.email ?? '';
    return [
      Panel(
        child: Row(children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: launchSelection,
            backgroundImage: account.user?.photoURL == null ? null : NetworkImage(account.user!.photoURL!),
            child: account.user?.photoURL == null ? Text(_initials(name ?? email), style: const TextStyle(color: launchAccent, fontWeight: FontWeight.w700)) : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name?.isNotEmpty == true ? name! : email, style: Theme.of(context).textTheme.titleMedium, overflow: TextOverflow.ellipsis),
              if (name?.isNotEmpty == true) Text(email, style: const TextStyle(color: launchInkMuted, fontSize: 13), overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Row(children: [
                Icon(account.emailVerified ? Icons.verified : Icons.mark_email_unread_outlined, size: 14, color: account.emailVerified ? const Color(0xFF4ED69A) : const Color(0xFFF2B84B)),
                const SizedBox(width: 4),
                Text(account.emailVerified ? 'Verified' : 'Email not verified', style: TextStyle(fontSize: 12, color: account.emailVerified ? const Color(0xFF4ED69A) : const Color(0xFFF2B84B))),
              ]),
            ]),
          ),
          IconButton(tooltip: 'Edit name', onPressed: () => _editName(context, account), icon: const Icon(Icons.edit_outlined, size: 20)),
        ]),
      ),
      if (!account.emailVerified) ...[
        const SizedBox(height: 10),
        NoticeStrip(
          icon: Icons.mark_email_unread_outlined,
          text: 'Confirm $email to secure your account and recover it if you forget your password.',
          action: PopupMenuButton<String>(
            tooltip: 'Verification options',
            icon: const Icon(Icons.more_vert, size: 18),
            onSelected: (v) async {
              final messenger = ScaffoldMessenger.of(context);
              if (v == 'resend') {
                await account.resendVerification();
                messenger.showSnackBar(SnackBar(content: Text('Verification email sent to $email')));
              } else {
                await account.refreshUser();
                messenger.showSnackBar(SnackBar(content: Text(account.emailVerified ? 'Email verified. Thank you!' : 'Not verified yet. Open the link in the email, then try again.')));
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'resend', child: Text('Resend email')),
              PopupMenuItem(value: 'check', child: Text("I've verified it")),
            ],
          ),
        ),
      ],
      const SectionHeader(title: 'Your launches'),
      _Group(children: [
        ListTile(
          leading: const Icon(Icons.notifications_none),
          title: const Text('Alerts inbox'),
          subtitle: Text(account.unread == 0 ? 'No new alerts' : plural(account.unread, 'new alert')),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            if (account.unread > 0) Badge(label: Text('${account.unread}'), backgroundColor: launchLive),
            const Icon(Icons.chevron_right),
          ]),
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const InboxPage())),
        ),
        ListTile(
          leading: const Icon(Icons.auto_awesome_outlined),
          title: const Text('Launch log'),
          subtitle: Text(account.watched.isEmpty ? 'Mark launches you watched to build your log' : '${plural(account.watched.length, 'launch', 'launches')} watched'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const LogPage())),
        ),
      ]),
      const SizedBox(height: 10),
      _Group(children: [
        if (account.follows.isEmpty)
          const ListTile(leading: Icon(Icons.bookmark_outline), title: Text('Not following any launches'), subtitle: Text('Open a launch and tap Follow.'))
        else
          for (final f in account.follows.values)
            ListTile(
              leading: const Icon(Icons.bookmark, color: launchAccent),
              title: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => openLaunch(context, f.launchId),
              trailing: TextButton(onPressed: () => account.unfollow(f.launchId), child: const Text('Unfollow')),
            ),
      ]),
      const SectionHeader(title: 'Alerts'),
      _PushStatus(account: account),
      const SizedBox(height: 10),
      _Group(children: [
        _switch('Schedule changes', 'When a followed launch slips or moves earlier', account.alerts.slips, (v) => account.setAlerts(account.alerts.copyWith(slips: v))),
        _switch('Status changes', 'Go, hold, scrubbed, to be confirmed', account.alerts.status, (v) => account.setAlerts(account.alerts.copyWith(status: v))),
        _switch('Liftoff', 'The moment it launches', account.alerts.liftoff, (v) => account.setAlerts(account.alerts.copyWith(liftoff: v))),
        _switch('Outcome', 'Success, failure, or payload deployed', account.alerts.outcome, (v) => account.setAlerts(account.alerts.copyWith(outcome: v))),
        _switch('Day-before reminder', 'For launches with an exact time', account.alerts.reminder24h, (v) => account.setAlerts(account.alerts.copyWith(reminder24h: v))),
      ]),
      const SizedBox(height: 10),
      _Group(children: [
        _switch('Weekly digest', 'Monday morning: what is launching this week', account.digest, account.setDigest),
      ]),
      const SectionHeader(title: 'Calendar'),
      _CalendarFeed(account: account),
      const SectionHeader(title: 'Sign-in and security'),
      _Group(children: [
        if (account.usesPassword) ...[
          ListTile(leading: const Icon(Icons.alternate_email), title: const Text('Change email'), trailing: const Icon(Icons.chevron_right), onTap: () => _changeEmail(context, account)),
          ListTile(leading: const Icon(Icons.password), title: const Text('Change password'), trailing: const Icon(Icons.chevron_right), onTap: () => _changePassword(context, account)),
        ] else
          ListTile(
            leading: const Icon(Icons.verified_user_outlined),
            title: const Text('Signed in with Google'),
            subtitle: Text(email),
          ),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Sign out'),
          onTap: () async {
            await account.signOut();
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signed out')));
          },
        ),
        ListTile(
          leading: const Icon(Icons.delete_outline, color: Color(0xFFFF6B6B)),
          title: const Text('Delete account', style: TextStyle(color: Color(0xFFFF6B6B))),
          subtitle: const Text('Removes your follows, alerts, log, and sign-in'),
          onTap: () => _delete(context, account),
        ),
      ]),
    ];
  }

  Widget _switch(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(title: Text(title), subtitle: Text(subtitle), value: value, onChanged: onChanged);
  }

  Future<void> _editName(BuildContext context, AccountController account) async {
    final controller = TextEditingController(text: account.displayName ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your name'),
        content: TextField(controller: controller, autofocus: true, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (saved == true) await account.updateDisplayName(controller.text);
  }

  Future<void> _changePassword(BuildContext context, AccountController account) {
    return showDialog<void>(context: context, builder: (_) => _PasswordDialog(account: account));
  }

  Future<void> _changeEmail(BuildContext context, AccountController account) {
    return showDialog<void>(context: context, builder: (_) => _EmailDialog(account: account));
  }

  Future<void> _delete(BuildContext context, AccountController account) {
    return showDialog<void>(context: context, builder: (_) => _DeleteDialog(account: account));
  }
}

String _initials(String text) {
  final words = text.split(RegExp(r'[\s@._-]+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return '?';
  return words.take(2).map((w) => w[0].toUpperCase()).join();
}

class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const Divider(indent: 56),
          children[i],
        ],
      ]),
    );
  }
}

class _SignedOutCard extends StatelessWidget {
  const _SignedOutCard();

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Never miss a launch', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        const Text('Browsing is free and needs no account. Sign in to:', style: TextStyle(color: launchInkMuted, fontSize: 14)),
        const SizedBox(height: 14),
        for (final (icon, text) in const [
          (Icons.bookmark_outline, 'Follow launches and get alerted when they slip, lift off, or land'),
          (Icons.calendar_month_outlined, 'Sync followed launches to your calendar, kept up to date'),
          (Icons.auto_awesome_outlined, 'Keep a log of every launch you have watched'),
          (Icons.devices_outlined, 'Pick up where you left off on any device'),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, size: 18, color: launchAccent),
              const SizedBox(width: 10),
              Expanded(child: Text(text, style: const TextStyle(fontSize: 14, height: 1.4))),
            ]),
          ),
        const SizedBox(height: 8),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<bool>(fullscreenDialog: true, builder: (_) => const SignInPage())),
          child: const Text('Sign in or create account'),
        ),
      ]),
    );
  }
}

class _PushStatus extends StatefulWidget {
  const _PushStatus({required this.account});

  final AccountController account;

  @override
  State<_PushStatus> createState() => _PushStatusState();
}

class _PushStatusState extends State<_PushStatus> {
  late Future<bool> _granted = widget.account.notifications.permissionGranted();

  @override
  Widget build(BuildContext context) {
    final service = widget.account.notifications;
    if (!service.webPushConfigured) {
      return const NoticeStrip(
        icon: Icons.inbox_outlined,
        color: launchAccent,
        text: 'In the browser, alerts arrive in your inbox here. Install the LaunchWatch app to get them as notifications.',
      );
    }
    return FutureBuilder<bool>(
      future: _granted,
      builder: (context, snap) {
        if (snap.data == true) {
          return const NoticeStrip(icon: Icons.notifications_active_outlined, color: Color(0xFF4ED69A), text: 'Notifications are on for this device.');
        }
        return NoticeStrip(
          icon: Icons.notifications_off_outlined,
          text: 'Notifications are off on this device. Alerts still appear in your inbox.',
          action: TextButton(
            onPressed: () async {
              final ok = await widget.account.enableNotifications();
              if (!context.mounted) return;
              setState(() => _granted = Future.value(ok));
              if (!ok) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notifications are blocked. Allow them for LaunchWatch in your device or browser settings.')));
              }
            },
            child: const Text('Turn on'),
          ),
        );
      },
    );
  }
}

class _CalendarFeed extends StatelessWidget {
  const _CalendarFeed({required this.account});

  final AccountController account;

  @override
  Widget build(BuildContext context) {
    final token = account.calendarToken;
    final url = token == null ? null : '$siteOrigin/cal/user/$token.ics';
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.calendar_month_outlined, color: launchAccent, size: 20),
          SizedBox(width: 10),
          Expanded(child: Text('Followed launches in your calendar', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
        ]),
        const SizedBox(height: 6),
        const Text('Subscribe once in Google Calendar, Apple Calendar, or Outlook. When a launch slips, the event moves by itself.', style: TextStyle(color: launchInkMuted, fontSize: 13.5, height: 1.4)),
        const SizedBox(height: 12),
        if (url == null)
          OutlinedButton.icon(onPressed: account.ensureCalendarToken, icon: const Icon(Icons.add_link, size: 18), label: const Text('Create my calendar link'))
        else ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: launchField, borderRadius: BorderRadius.circular(10), border: Border.all(color: launchLine)),
            child: SelectableText(url, style: const TextStyle(fontSize: 12.5, color: launchInkMuted, fontFamily: 'monospace')),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.icon(
              onPressed: () => launchUrl(Uri.parse(url.replaceFirst('https://', 'webcal://')), mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.event_available, size: 18),
              label: const Text('Subscribe'),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: url));
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Calendar link copied. Keep it private: anyone with it can see your followed launches.')));
              },
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Copy link'),
            ),
          ]),
        ],
      ]),
    );
  }
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog({required this.account});
  final AccountController account;

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change password'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: _current, obscureText: true, autofillHints: const [AutofillHints.password], decoration: const InputDecoration(labelText: 'Current password')),
        const SizedBox(height: 12),
        TextField(controller: _next, obscureText: true, autofillHints: const [AutofillHints.newPassword], decoration: const InputDecoration(labelText: 'New password', helperText: '8+ characters, letters and numbers')),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 13))),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _busy
              ? null
              : () async {
                  setState(() => _busy = true);
                  try {
                    await widget.account.changePassword(current: _current.text, next: _next.text);
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password changed')));
                  } catch (e) {
                    setState(() => _error = authErrorMessage(e));
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                },
          child: const Text('Change'),
        ),
      ],
    );
  }
}

class _EmailDialog extends StatefulWidget {
  const _EmailDialog({required this.account});
  final AccountController account;

  @override
  State<_EmailDialog> createState() => _EmailDialogState();
}

class _EmailDialogState extends State<_EmailDialog> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change email'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text("We'll send a confirmation link to the new address. Your email changes once you open it."),
        const SizedBox(height: 14),
        TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'New email')),
        const SizedBox(height: 12),
        TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'Current password')),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 13))),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _busy
              ? null
              : () async {
                  setState(() => _busy = true);
                  try {
                    await widget.account.changeEmail(password: _password.text, newEmail: _email.text);
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Check ${_email.text.trim()} for a confirmation link')));
                  } catch (e) {
                    setState(() => _error = authErrorMessage(e));
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                },
          child: const Text('Send link'),
        ),
      ],
    );
  }
}

class _DeleteDialog extends StatefulWidget {
  const _DeleteDialog({required this.account});
  final AccountController account;

  @override
  State<_DeleteDialog> createState() => _DeleteDialogState();
}

class _DeleteDialogState extends State<_DeleteDialog> {
  final _password = TextEditingController();
  bool _confirmed = false;
  bool _busy = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final account = widget.account;
    return AlertDialog(
      icon: const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF6B6B)),
      title: const Text('Delete your account?'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('This permanently removes ${account.email ?? 'your account'}, ${plural(account.follows.length, 'followed launch', 'followed launches')}, your alerts, your calendar link, and your launch log. It cannot be undone.'),
        const SizedBox(height: 14),
        if (account.usesPassword) ...[
          TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'Confirm your password')),
          const SizedBox(height: 8),
        ],
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _confirmed,
          onChanged: (v) => setState(() => _confirmed = v ?? false),
          title: const Text('I understand this is permanent', style: TextStyle(fontSize: 14)),
        ),
        if (_error != null) Text(_error!, style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 13)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Keep account')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF6B6B), foregroundColor: Colors.white),
          onPressed: !_confirmed || _busy
              ? null
              : () async {
                  setState(() => _busy = true);
                  try {
                    await account.deleteAccount(password: _password.text);
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Your account and its data have been deleted')));
                  } catch (e) {
                    setState(() => _error = authErrorMessage(e));
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                },
          child: const Text('Delete forever'),
        ),
      ],
    );
  }
}
