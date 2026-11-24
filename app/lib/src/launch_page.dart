import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'account.dart';
import 'app_state.dart';
import 'catalog.dart';
import 'catalog_profile_pages.dart';
import 'format_net.dart';
import 'glossary.dart';
import 'launch_list_page.dart' show pickHomeCity;
import 'launch_repository.dart';
import 'news_page.dart' show RelatedNews;
import 'sign_in_page.dart';
import 'theme.dart';
import 'visibility.dart';
import 'widgets.dart';

/// Full-screen launch page, reached at /launch/{id}.
class LaunchPage extends StatelessWidget {
  const LaunchPage({super.key, required this.id, required this.repository});

  final String id;
  final LaunchRepository repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Navigator.of(context).canPop() ? null : IconButton(tooltip: 'All launches', icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).pushReplacementNamed('/')),
        title: const Text('Mission brief'),
        actions: [IconButton(tooltip: 'Copy link', icon: const Icon(Icons.link), onPressed: () => copyLaunchLink(context, id))],
      ),
      body: LaunchDetailView(id: id, repository: repository),
    );
  }
}

Future<void> copyLaunchLink(BuildContext context, String id) async {
  await Clipboard.setData(ClipboardData(text: launchLink(id)));
  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied')));
}

/// The launch page body. Used full-screen on phones and as the right pane on wide screens.
class LaunchDetailView extends StatefulWidget {
  const LaunchDetailView({super.key, required this.id, required this.repository, this.embedded = false});

  final String id;
  final LaunchRepository repository;
  final bool embedded;

  @override
  State<LaunchDetailView> createState() => _LaunchDetailViewState();
}

class _LaunchDetailViewState extends State<LaunchDetailView> {
  late Stream<LaunchRecord?> _stream = widget.repository.one(widget.id);
  bool _busy = false;

  @override
  void didUpdateWidget(LaunchDetailView old) {
    super.didUpdateWidget(old);
    if (old.id != widget.id) _stream = widget.repository.one(widget.id);
  }

  @override
  Widget build(BuildContext context) {
    final account = LaunchWatchScope.of(context);
    return StreamBuilder<LaunchRecord?>(
      key: ValueKey(widget.id),
      stream: _stream,
      builder: (context, snapshot) {
        final launch = snapshot.data;
        if (snapshot.hasError) return const EmptyState(icon: Icons.cloud_off, title: "Couldn't load this launch");
        if (snapshot.connectionState == ConnectionState.waiting && launch == null) return const Center(child: CircularProgressIndicator());
        if (launch == null) {
          return EmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'This launch is no longer in the catalog',
            body: 'It may have been removed or merged into another entry.',
            action: widget.embedded ? null : OutlinedButton(onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false), child: const Text('Back to launches')),
          );
        }
        return Column(children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                ContentWidth(child: _body(context, launch, account)),
              ],
            ),
          ),
          _ActionBar(launch: launch, busy: _busy, onFollow: () => _follow(launch)),
        ]);
      },
    );
  }

  Widget _body(BuildContext context, LaunchRecord launch, AccountController account) {
    final text = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 6, runSpacing: 6, children: [
        if (launch.isLive) const LiveBadge(label: 'LIVE NOW') else StatusChip(rawName: launch.status),
        if (launch.crewed) const TagChip.crew(),
        if (launch.suborbital) const TagChip.suborbital(),
      ]),
      const SizedBox(height: 12),
      Semantics(header: true, child: Text(launch.shortName, style: text.headlineMedium)),
      const SizedBox(height: 4),
      Text([launch.vehicle, launch.provider].whereType<String>().join(' · '), style: text.bodyMedium?.copyWith(color: launchInkMuted)),
      const SizedBox(height: 18),
      _TimeBlock(launch: launch),
      if (launch.webcasts.isNotEmpty) ...[
        const SizedBox(height: 12),
        _Webcasts(launch: launch),
      ],
      const SizedBox(height: 12),
      _QuickActions(launch: launch),
      const SizedBox(height: 20),
      ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: 200,
          child: Stack(fit: StackFit.expand, children: [
            LaunchPoster(imageUrl: launch.imageUrl, label: launch.vehicle ?? launch.name, height: 200),
            const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xD90A0D12)]))),
            if (launch.pad != null || launch.location != null)
              Positioned(
                left: 14,
                bottom: 12,
                right: 14,
                child: Row(children: [
                  const Icon(Icons.place_outlined, size: 16, color: Colors.white),
                  const SizedBox(width: 6),
                  Expanded(child: Text([launch.pad, launch.location].whereType<String>().join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13))),
                ]),
              ),
          ]),
        ),
      ),
      if (launch.padLatitude != null && launch.padLongitude != null && launch.list != 'recent') _VisibilityCard(launch: launch, city: account.homeCity),
      if (launch.history.length > 1) _History(launch: launch),
      if (launch.updates.isNotEmpty) _Updates(launch: launch),
      if (launch.description != null && launch.description!.trim().isNotEmpty) ...[
        const SectionHeader(title: 'Mission overview'),
        Text(launch.description!, style: text.bodyLarge?.copyWith(fontSize: 15.5)),
      ],
      const SectionHeader(title: 'Mission data'),
      Panel(
        padding: EdgeInsets.zero,
        child: Column(children: _divided([
          _Fact(label: 'Operator', value: launch.provider, onTap: launch.provider == null ? null : () => _openOrganisation(context, launch)),
          _Fact(label: 'Vehicle', value: launch.vehicle, onTap: launch.vehicle == null ? null : () => _openVehicle(context, launch), trailing: _Reliability(launch: launch, repository: widget.repository)),
          _Fact(label: 'Orbit', value: launch.orbit, glossary: true),
          _Fact(label: 'Mission type', value: launch.missionType, glossary: true),
          _Fact(label: 'Launch pad', value: launch.pad),
          _Fact(label: 'Location', value: [launch.location, launch.country].whereType<String>().where((v) => v.isNotEmpty).join(' · ')),
          if (launch.suborbital) const _Fact(label: 'Profile', value: 'Suborbital', glossary: true),
        ])),
      ),
      RelatedNews(launchId: launch.id),
      if (launch.sources.isNotEmpty) ...[
        const SectionHeader(title: 'Sources'),
        for (final s in launch.sources)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: TextButton.icon(
              style: TextButton.styleFrom(alignment: Alignment.centerLeft, padding: const EdgeInsets.symmetric(horizontal: 4)),
              onPressed: () => launchUrl(Uri.parse(s.url), mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: Text(s.title ?? Uri.tryParse(s.url)?.host ?? s.url, overflow: TextOverflow.ellipsis),
            ),
          ),
      ],
      const SizedBox(height: 24),
      Text('Data from Launch Library 2 by The Space Devs. Times shown in ${DateTime.now().timeZoneName}.', style: text.bodySmall?.copyWith(color: launchInkFaint)),
    ]);
  }

  List<Widget> _divided(List<Widget> rows) {
    final visible = rows.where((w) => w is! _Fact || w.visible).toList();
    return [
      for (var i = 0; i < visible.length; i++) ...[
        if (i > 0) const Divider(indent: 14, endIndent: 14),
        visible[i],
      ],
    ];
  }

  Future<void> _follow(LaunchRecord launch) async {
    final account = LaunchWatchScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (!account.signedIn) {
      final ok = await Navigator.of(context).push<bool>(MaterialPageRoute<bool>(fullscreenDialog: true, builder: (_) => const SignInPage(reason: SignInReason.follow)));
      if (ok != true || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      final nowFollowing = await account.toggleFollow(launch);
      if (!mounted) return;
      if (!nowFollowing) {
        messenger.showSnackBar(SnackBar(content: Text('Unfollowed ${launch.shortName}')));
        return;
      }
      final pushOn = await _offerNotifications(account);
      messenger.showSnackBar(SnackBar(
        content: Text(pushOn ? "Following. We'll alert you if ${launch.shortName} moves." : "Following. Changes will appear in your alerts inbox."),
      ));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(authErrorMessage(error))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Explains alerts before the system prompt, once per device.
  Future<bool> _offerNotifications(AccountController account) async {
    if (await account.notifications.permissionGranted()) return account.enableNotifications();
    final prefs = account.prefs;
    if (prefs?.getBool('askedPush') == true) return false;
    if (!mounted) return false;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.notifications_active_outlined, color: launchAccent),
        title: const Text('Get alerts for this launch?'),
        content: const Text('LaunchWatch will tell you when it slips, changes status, lifts off, and how it went. You can fine-tune or turn alerts off any time in Account.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not now')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Turn on alerts')),
        ],
      ),
    );
    await prefs?.setBool('askedPush', true);
    if (yes != true) return false;
    return account.enableNotifications();
  }

  Future<void> _openOrganisation(BuildContext context, LaunchRecord launch) async {
    final all = widget.repository.latest ?? await widget.repository.everything().first;
    final key = launch.providerId?.toString() ?? launch.provider;
    for (final group in groupOrganisations(all)) {
      if (group.key != key) continue;
      if (!context.mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => OrganisationProfilePage(group: group, repository: widget.repository)));
      return;
    }
  }

  Future<void> _openVehicle(BuildContext context, LaunchRecord launch) async {
    final all = widget.repository.latest ?? await widget.repository.everything().first;
    final key = launch.vehicleId?.toString() ?? launch.vehicle;
    for (final group in groupVehicles(all)) {
      if (group.key != key) continue;
      if (!context.mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => VehicleProfilePage(group: group, repository: widget.repository)));
      return;
    }
  }
}

class _TimeBlock extends StatelessWidget {
  const _TimeBlock({required this.launch});

  final LaunchRecord launch;

  @override
  Widget build(BuildContext context) {
    final showCountdown = countdownAllowed(launch.net, launch.precisionAbbrev, launch.statusId);
    final clock = precisionHasClock(launch.precisionAbbrev);
    final window = _window();
    return Panel(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          GlossaryText('NET', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(width: 8),
          Expanded(child: Text(precisionLabel(launch.precisionAbbrev).toUpperCase(), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: launchInkFaint))),
        ]),
        const SizedBox(height: 8),
        if (showCountdown) ...[
          Countdown(launch: launch, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -0.8, color: launchInk)),
          const SizedBox(height: 2),
          Text(launch.when, style: const TextStyle(fontSize: 15, color: launchInk, fontWeight: FontWeight.w500)),
        ] else
          Text(launch.when, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.4, color: launchInk)),
        if (!launch.isDated && launch.list == 'upcoming') ...[
          const SizedBox(height: 6),
          const Text('Only this period has been announced. There is no countdown until a date is set.', style: TextStyle(color: launchInkMuted, fontSize: 13, height: 1.4)),
        ],
        if (clock && launch.net != null) ...[
          const SizedBox(height: 10),
          const Divider(),
          const SizedBox(height: 10),
          Wrap(spacing: 24, runSpacing: 8, children: [
            _mini('UTC', formatUtcClock(launch.net!)),
            if (window != null) _mini('Window', window),
          ]),
        ],
      ]),
    );
  }

  Widget _mini(String label, String value) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(), style: const TextStyle(color: launchInkFaint, fontSize: 10.5, fontWeight: FontWeight.w600, letterSpacing: 0.9)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: launchInk, fontSize: 13.5, fontFeatures: tabularFigures)),
      ]);

  String? _window() {
    final start = launch.windowStart;
    final end = launch.windowEnd;
    if (start == null || end == null || start == end) return precisionHasClock(launch.precisionAbbrev) && start == end && start != null ? 'Instantaneous' : null;
    final clock = DateFormat.jm();
    return '${clock.format(start.toLocal())} – ${clock.format(end.toLocal())}';
  }
}

class _Webcasts extends StatelessWidget {
  const _Webcasts({required this.launch});

  final LaunchRecord launch;

  @override
  Widget build(BuildContext context) {
    final first = launch.webcasts.first;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      FilledButton.icon(
        style: launch.isLive ? FilledButton.styleFrom(backgroundColor: launchLive, foregroundColor: Colors.white) : null,
        onPressed: () => launchUrl(Uri.parse(first.url), mode: LaunchMode.externalApplication),
        icon: const Icon(Icons.play_circle_fill),
        label: Text(launch.isLive ? 'Watch live' : 'Watch the webcast'),
      ),
      if (launch.webcasts.length > 1)
        Wrap(spacing: 4, children: [
          for (final w in launch.webcasts.skip(1).take(3))
            TextButton(onPressed: () => launchUrl(Uri.parse(w.url), mode: LaunchMode.externalApplication), child: Text(w.title ?? Uri.tryParse(w.url)?.host ?? 'Other stream', overflow: TextOverflow.ellipsis)),
        ]),
    ]);
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.launch});

  final LaunchRecord launch;

  bool get _calendarable => const {'SEC', 'MIN', 'HR', 'AM', 'PM', 'DAY'}.contains(launch.precisionAbbrev) && launch.list == 'upcoming';
  bool get _watchable => launch.list == 'recent' || launch.isLive || (launch.net != null && launch.net!.isBefore(DateTime.now()));

  @override
  Widget build(BuildContext context) {
    final account = LaunchWatchScope.of(context);
    final watched = account.hasWatched(launch.id);
    return Wrap(spacing: 8, runSpacing: 8, children: [
      if (_calendarable)
        OutlinedButton.icon(
          onPressed: () => launchUrl(Uri.parse('$siteOrigin/cal/launch/${launch.id}.ics'), mode: LaunchMode.externalApplication),
          icon: const Icon(Icons.event_outlined, size: 18),
          label: const Text('Add to calendar'),
        ),
      OutlinedButton.icon(onPressed: () => copyLaunchLink(context, launch.id), icon: const Icon(Icons.ios_share, size: 18), label: const Text('Share')),
      if (_watchable)
        OutlinedButton.icon(
          style: watched ? OutlinedButton.styleFrom(foregroundColor: launchAccent, side: const BorderSide(color: launchAccent)) : null,
          onPressed: () async {
            if (!account.signedIn) {
              final ok = await Navigator.of(context).push<bool>(MaterialPageRoute<bool>(fullscreenDialog: true, builder: (_) => const SignInPage(reason: SignInReason.log)));
              if (ok != true) return;
            }
            try {
              await account.toggleWatched(launch);
            } catch (e) {
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(authErrorMessage(e))));
            }
          },
          icon: Icon(watched ? Icons.check_circle : Icons.visibility_outlined, size: 18),
          label: Text(watched ? 'In your log' : 'I watched this'),
        ),
    ]);
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.launch, required this.busy, required this.onFollow});

  final LaunchRecord launch;
  final bool busy;
  final VoidCallback onFollow;

  @override
  Widget build(BuildContext context) {
    final account = LaunchWatchScope.of(context);
    final following = account.following(launch.id);
    if (launch.list == 'recent' && !following) return const SizedBox.shrink();
    return DecoratedBox(
      decoration: const BoxDecoration(color: launchBackground, border: Border(top: BorderSide(color: launchLine))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: ContentWidth(
            child: SizedBox(
              width: double.infinity,
              child: following
                  ? OutlinedButton.icon(
                      onPressed: busy ? null : onFollow,
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      icon: const Icon(Icons.bookmark, color: launchAccent),
                      label: const Text('Following · tap to unfollow'),
                    )
                  : FilledButton.icon(
                      onPressed: busy ? null : onFollow,
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      icon: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: launchActionInk)) : const Icon(Icons.bookmark_add_outlined),
                      label: const Text('Follow this launch'),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VisibilityCard extends StatelessWidget {
  const _VisibilityCard({required this.launch, required this.city});

  final LaunchRecord launch;
  final City? city;

  @override
  Widget build(BuildContext context) {
    final estimate = city == null
        ? null
        : estimateVisibility(city: city!, padLatitude: launch.padLatitude!, padLongitude: launch.padLongitude!, suborbital: launch.suborbital, net: launch.net);
    final color = switch (estimate?.tier) {
      VisibilityTier.atSite || VisibilityTier.clear => const Color(0xFF4ED69A),
      VisibilityTier.possible => const Color(0xFFF2B84B),
      _ => launchInkMuted,
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionHeader(title: 'Can I see it from here?'),
      Panel(
        child: estimate == null
            ? Row(children: [
                const Icon(Icons.visibility_outlined, color: launchInkMuted),
                const SizedBox(width: 12),
                const Expanded(child: Text('Use your location or choose a city to see whether this launch could be visible where you are.', style: TextStyle(fontSize: 14, height: 1.4))),
                TextButton(onPressed: () => pickHomeCity(context), child: const Text('Choose')),
              ])
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.visibility_outlined, color: color, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(estimate.headline, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 15.5))),
                  _CompassDial(direction: estimate.direction),
                ]),
                const SizedBox(height: 8),
                Text(estimate.detail, style: const TextStyle(fontSize: 14, height: 1.45)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: Text('From ${city!.label} · an estimate, not a forecast', style: const TextStyle(color: launchInkFaint, fontSize: 12))),
                  TextButton(onPressed: () => pickHomeCity(context), child: const Text('Change')),
                ]),
              ]),
      ),
    ]);
  }
}

class _CompassDial extends StatelessWidget {
  const _CompassDial({required this.direction});

  final String direction;

  static const _angles = {'north': 0, 'northeast': 45, 'east': 90, 'southeast': 135, 'south': 180, 'southwest': 225, 'west': 270, 'northwest': 315};

  @override
  Widget build(BuildContext context) {
    final turns = (_angles[direction] ?? 0) / 360;
    return Tooltip(
      message: 'Look $direction',
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: launchLineStrong)),
        child: RotationTransition(turns: AlwaysStoppedAnimation(turns), child: const Icon(Icons.navigation, size: 16, color: launchAccent)),
      ),
    );
  }
}

class _History extends StatelessWidget {
  const _History({required this.launch});

  final LaunchRecord launch;

  @override
  Widget build(BuildContext context) {
    final entries = launch.history.reversed.toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionHeader(title: 'Schedule history', trailing: Text(plural(entries.length - 1, 'change'), style: const TextStyle(color: launchInkFaint, fontSize: 12))),
      Panel(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
        child: Column(children: [
          for (var i = 0; i < entries.length; i++) _HistoryRow(entry: entries[i], previous: i + 1 < entries.length ? entries[i + 1] : null, latest: i == 0, last: i == entries.length - 1),
        ]),
      ),
    ]);
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry, required this.previous, required this.latest, required this.last});

  final NetChange entry;
  final NetChange? previous;
  final bool latest;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final when = entry.net == null ? 'Time unknown' : formatNet(entry.net!, entry.precision);
    String? change;
    if (previous != null && previous!.net != null && entry.net != null) {
      final diff = entry.net!.difference(previous!.net!);
      if (diff.inMinutes.abs() >= 1) {
        final amount = diff.inDays.abs() >= 1 ? plural(diff.inDays.abs(), 'day') : diff.inHours.abs() >= 1 ? plural(diff.inHours.abs(), 'hour') : plural(diff.inMinutes.abs(), 'minute');
        change = diff.isNegative ? 'Moved earlier by $amount' : 'Slipped $amount';
      } else if (entry.precision != previous!.precision) {
        change = 'Date firmed up';
      } else if (entry.statusId != previous!.statusId) {
        change = 'Status changed';
      }
    }
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 18,
          child: Column(children: [
            const SizedBox(height: 4),
            Container(width: 9, height: 9, decoration: BoxDecoration(shape: BoxShape.circle, color: latest ? launchAccent : launchLineStrong)),
            if (!last) Expanded(child: Container(width: 1.5, color: launchLine)),
          ]),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(when, style: TextStyle(fontWeight: latest ? FontWeight.w600 : FontWeight.w400, color: latest ? launchInk : launchInkMuted, decoration: latest ? null : TextDecoration.lineThrough, decorationColor: launchInkFaint)),
              const SizedBox(height: 2),
              Text(
                [?change, if (entry.recordedAt != null) 'seen ${DateFormat.MMMd().format(entry.recordedAt!.toLocal())}', if (previous == null) 'first listed'].join(' · '),
                style: const TextStyle(color: launchInkFaint, fontSize: 12),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Updates extends StatelessWidget {
  const _Updates({required this.launch});

  final LaunchRecord launch;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionHeader(title: 'Latest updates'),
      Panel(
        padding: EdgeInsets.zero,
        child: Column(children: [
          for (var i = 0; i < launch.updates.length && i < 5; i++) ...[
            if (i > 0) const Divider(indent: 14, endIndent: 14),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (launch.updates[i].createdOn != null)
                  Text(DateFormat.yMMMd().add_jm().format(launch.updates[i].createdOn!.toLocal()), style: const TextStyle(color: launchInkFaint, fontSize: 12)),
                const SizedBox(height: 3),
                Text(launch.updates[i].comment ?? 'Update posted.', style: const TextStyle(fontSize: 14, height: 1.45)),
                if (launch.updates[i].infoUrl != null)
                  TextButton(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
                    onPressed: () => launchUrl(Uri.parse(launch.updates[i].infoUrl!), mode: LaunchMode.externalApplication),
                    child: const Text('Source'),
                  ),
              ]),
            ),
          ],
        ]),
      ),
    ]);
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value, this.onTap, this.glossary = false, this.trailing});

  final String label;
  final String? value;
  final VoidCallback? onTap;
  final bool glossary;
  final Widget? trailing;

  bool get visible => value != null && value!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    final valueStyle = const TextStyle(color: launchInk, fontSize: 14, fontWeight: FontWeight.w500, height: 1.35);
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 108, child: Text(label, style: const TextStyle(color: launchInkMuted, fontSize: 13.5))),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            glossary ? GlossaryText(value!, style: valueStyle) : Text(value!, style: valueStyle),
            ?trailing,
          ]),
        ),
        if (onTap != null) const Icon(Icons.chevron_right, size: 18, color: launchInkMuted),
      ]),
    );
    return onTap == null ? row : InkWell(onTap: onTap, child: row);
  }
}

/// "98% success over 412 flights", from cached LL2 vehicle totals.
class _Reliability extends StatelessWidget {
  const _Reliability({required this.launch, required this.repository});

  final LaunchRecord launch;
  final LaunchRepository repository;

  @override
  Widget build(BuildContext context) {
    final key = launch.vehicleId?.toString();
    if (key == null) return const SizedBox.shrink();
    return StreamBuilder<HistoricalLaunchCount?>(
      stream: repository.historicalCount('vehicle', key),
      builder: (context, snap) {
        final stats = snap.data;
        if (stats == null) return const SizedBox.shrink();
        final rate = stats.successRate;
        final flights = (stats.successfulLaunches ?? 0) + (stats.failedLaunches ?? 0);
        final text = rate == null
            ? (stats.pastLaunches == 0 ? 'First flight' : plural(stats.pastLaunches, 'flight'))
            : '${(rate * 100).toStringAsFixed(rate > 0.995 && rate < 1 ? 1 : 0)}% success over ${plural(flights, 'flight')}';
        final color = rate == null ? launchInkMuted : rate >= 0.95 ? const Color(0xFF4ED69A) : rate >= 0.8 ? const Color(0xFFF2B84B) : const Color(0xFFFF9B54);
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(children: [
            Icon(Icons.verified_outlined, size: 14, color: color),
            const SizedBox(width: 5),
            Flexible(child: Text(text, style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w500))),
          ]),
        );
      },
    );
  }
}
