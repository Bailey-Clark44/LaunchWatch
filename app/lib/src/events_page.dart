import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_state.dart';
import 'format_net.dart';
import 'launch_list_page.dart' show LaunchRow;
import 'launch_repository.dart';
import 'news_page.dart';
import 'space_data.dart';
import 'theme.dart';
import 'widgets.dart';

IconData eventIcon(String? type) {
  final t = (type ?? '').toLowerCase();
  if (t.contains('eva') || t.contains('spacewalk')) return Icons.accessibility_new;
  if (t.contains('dock') || t.contains('berth')) return Icons.link;
  if (t.contains('undock') || t.contains('unberth')) return Icons.link_off;
  if (t.contains('land') || t.contains('splash')) return Icons.flight_land;
  if (t.contains('flyby')) return Icons.travel_explore;
  if (t.contains('insertion') || t.contains('orbit')) return Icons.public;
  if (t.contains('test') || t.contains('fire')) return Icons.local_fire_department_outlined;
  if (t.contains('press') || t.contains('conference') || t.contains('briefing')) return Icons.mic_none;
  if (t.contains('celestial') || t.contains('eclipse')) return Icons.dark_mode_outlined;
  return Icons.event_outlined;
}

class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  Stream<List<SpaceEvent>>? _stream;
  bool _upcoming = true;
  String? _type;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _stream ??= LaunchWatchScope.spaceOf(context).events();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<List<SpaceEvent>>(
          stream: _stream,
          builder: (context, snap) {
            final all = snap.data;
            final inList = (all ?? const <SpaceEvent>[]).where((e) => e.list == (_upcoming ? 'upcoming' : 'recent')).toList();
            if (!_upcoming) inList.sort((a, b) => (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0)));
            final types = inList.map((e) => e.type).whereType<String>().toSet().toList()..sort();
            final events = inList.where((e) => _type == null || e.type == _type).toList();
            final dated = events.where((e) => e.isDated).toList();
            final undated = events.where((e) => !e.isDated).toList();
            return CustomScrollView(slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Semantics(header: true, child: Text('Events', style: Theme.of(context).textTheme.headlineMedium)),
                    const SizedBox(height: 2),
                    const Text('Spacewalks, dockings, landings, flybys, and tests', style: TextStyle(color: launchInkMuted, fontSize: 13)),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<bool>(
                        showSelectedIcon: false,
                        style: SegmentedButton.styleFrom(
                          backgroundColor: launchSurface,
                          selectedBackgroundColor: launchSurfaceRaised,
                          foregroundColor: launchInkMuted,
                          selectedForegroundColor: launchInk,
                          side: const BorderSide(color: launchLine),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        segments: const [ButtonSegment(value: true, label: Text('Upcoming')), ButtonSegment(value: false, label: Text('Recent'))],
                        selected: {_upcoming},
                        onSelectionChanged: (s) => setState(() {
                          _upcoming = s.first;
                          _type = null;
                        }),
                      ),
                    ),
                  ]),
                ),
              ),
              if (types.length > 1)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 54,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                      children: [
                        Pill(label: 'All', selected: _type == null, onTap: () => setState(() => _type = null)),
                        for (final t in types) Pill(label: t, icon: eventIcon(t), selected: _type == t, onTap: () => setState(() => _type = t)),
                      ],
                    ),
                  ),
                ),
              if (snap.hasError)
                const SliverFillRemaining(hasScrollBody: false, child: EmptyState(icon: Icons.cloud_off, title: "Couldn't load events"))
              else if (all == null)
                const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator()))
              else if (events.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.event_busy_outlined,
                    title: all.isEmpty ? 'Events are on their way' : 'Nothing here right now',
                    body: all.isEmpty ? 'The event calendar fills in shortly after the first refresh.' : null,
                  ),
                )
              else ...[
                if (_upcoming && dated.isNotEmpty)
                  SliverPadding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), sliver: SliverToBoxAdapter(child: _FeaturedEvent(event: dated.first))),
                for (final group in _group(_upcoming ? dated.skip(1).toList() : dated, upcoming: _upcoming)) ...[
                  SliverPadding(padding: const EdgeInsets.symmetric(horizontal: 16), sliver: SliverToBoxAdapter(child: SectionHeader(title: group.$1))),
                  _rows(group.$2),
                ],
                if (undated.isNotEmpty) ...[
                  const SliverPadding(padding: EdgeInsets.symmetric(horizontal: 16), sliver: SliverToBoxAdapter(child: SectionHeader(title: 'Date not yet fixed'))),
                  _rows(undated),
                ],
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ]);
          },
        ),
      ),
    );
  }

  Widget _rows(List<SpaceEvent> list) => SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList.separated(itemCount: list.length, separatorBuilder: (_, _) => const SizedBox(height: 8), itemBuilder: (_, i) => EventRow(event: list[i])),
      );
}

List<(String, List<SpaceEvent>)> _group(List<SpaceEvent> events, {required bool upcoming}) {
  final today = DateUtils.dateOnly(DateTime.now());
  final groups = <String, List<SpaceEvent>>{};
  for (final e in events) {
    final day = DateUtils.dateOnly(e.date!.toLocal());
    final diff = upcoming ? day.difference(today).inDays : today.difference(day).inDays;
    final key = diff <= 0
        ? 'Today'
        : diff == 1
            ? (upcoming ? 'Tomorrow' : 'Yesterday')
            : diff < 7
                ? (upcoming ? 'This week' : 'Earlier this week')
                : DateFormat.yMMMM().format(day);
    groups.putIfAbsent(key, () => []).add(e);
  }
  return groups.entries.map((e) => (e.key, e.value)).toList();
}

class _FeaturedEvent extends StatelessWidget {
  const _FeaturedEvent({required this.event});

  final SpaceEvent event;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: launchSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: launchLine)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openEvent(context, event.id),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            height: 170,
            child: Stack(fit: StackFit.expand, children: [
              LaunchPoster(imageUrl: event.imageUrl, label: event.name, height: 170),
              const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x22000000), Color(0xF20A0D12)]))),
              Positioned(
                left: 16,
                top: 14,
                child: event.webcastLive ? const LiveBadge() : _TypeTag(type: event.type, dark: true),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 14,
                child: Text(event.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.3, height: 1.15)),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  TimeUntil(date: event.date, precision: event.precision, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: launchInk)),
                  Text(event.when, style: TextStyle(fontSize: countdownAllowed(event.date, event.precision, 1) ? 12.5 : 17, fontWeight: countdownAllowed(event.date, event.precision, 1) ? FontWeight.w400 : FontWeight.w700, color: countdownAllowed(event.date, event.precision, 1) ? launchInkMuted : launchInk)),
                  if (event.location != null) Text(event.location!, style: const TextStyle(color: launchInkMuted, fontSize: 12.5)),
                ]),
              ),
              const Icon(Icons.arrow_forward, color: launchInkMuted, size: 20),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _TypeTag extends StatelessWidget {
  const _TypeTag({required this.type, this.dark = false});

  final String? type;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    if (type == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: dark ? const Color(0xB30A0D12) : launchSelection,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: dark ? const Color(0x33FFFFFF) : launchAccent.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(eventIcon(type), size: 13, color: dark ? Colors.white : launchAccent),
        const SizedBox(width: 5),
        Text(type!, style: TextStyle(color: dark ? Colors.white : launchAccent, fontSize: 11.5, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class EventRow extends StatelessWidget {
  const EventRow({super.key, required this.event});

  final SpaceEvent event;

  @override
  Widget build(BuildContext context) {
    final (top, bottom) = formatNetBadge(event.date, event.precision);
    final clock = formatRowClock(event.date, event.precision);
    return Panel(
      padding: const EdgeInsets.all(12),
      onTap: () => openEvent(context, event.id),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 56,
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(color: event.isDated ? launchSurfaceRaised : Colors.transparent, borderRadius: BorderRadius.circular(10), border: event.isDated ? null : Border.all(color: launchLineStrong)),
          child: Column(children: [
            Text(top, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: event.isDated ? launchAccent : launchInkMuted)),
            Text(bottom, style: TextStyle(fontSize: event.isDated ? 19 : 14, fontWeight: FontWeight.w700, color: event.isDated ? launchInk : launchInkMuted, fontFeatures: tabularFigures)),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(event.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.3)),
            if (event.location != null) ...[
              const SizedBox(height: 2),
              Text(event.location!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: launchInkMuted, fontSize: 13)),
            ],
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              if (event.webcastLive) const LiveBadge() else _TypeTag(type: event.type),
              if (event.webcasts.isNotEmpty && !event.webcastLive) const TagChip(label: 'Webcast', icon: Icons.play_circle_outline),
              if (countdownAllowed(event.date, event.precision, 1))
                TimeUntil(date: event.date, precision: event.precision, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: launchInk))
              else if (clock != null)
                Text(clock, style: const TextStyle(fontSize: 12.5, color: launchInkMuted)),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class EventPage extends StatelessWidget {
  const EventPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    final space = LaunchWatchScope.spaceOf(context);
    return StreamBuilder<SpaceEvent?>(
      stream: space.event(id),
      builder: (context, snap) {
        final event = snap.data;
        if (snap.connectionState == ConnectionState.waiting && event == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        if (event == null) {
          return Scaffold(appBar: AppBar(), body: const EmptyState(icon: Icons.event_busy_outlined, title: 'This event is no longer listed'));
        }
        final text = Theme.of(context).textTheme;
        final clock = precisionHasClock(event.precision);
        final calendarable = !isCoarse(event.precision) && event.list == 'upcoming';
        return Scaffold(
          body: CustomScrollView(slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 230,
              title: const Text('Event'),
              actions: [
                IconButton(
                  tooltip: 'Copy link',
                  icon: const Icon(Icons.link),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: '$siteOrigin/event/${event.id}'));
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied')));
                  },
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(fit: StackFit.expand, children: [
                  LaunchPoster(imageUrl: event.imageUrl, label: event.name, height: double.infinity),
                  const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x99000000), Color(0x00000000), Color(0xFF0A0D12)], stops: [0, 0.4, 1]))),
                ]),
              ),
            ),
            SliverToBoxAdapter(
              child: ContentWidth(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Wrap(spacing: 6, children: [if (event.webcastLive) const LiveBadge() else _TypeTag(type: event.type)]),
                    const SizedBox(height: 10),
                    Text(event.name, style: text.headlineMedium),
                    if (event.location != null) ...[
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(Icons.place_outlined, size: 15, color: launchInkMuted),
                        const SizedBox(width: 4),
                        Expanded(child: Text(event.location!, style: const TextStyle(color: launchInkMuted))),
                      ]),
                    ],
                    const SizedBox(height: 16),
                    Panel(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(precisionLabel(event.precision).toUpperCase(), style: text.labelSmall),
                        const SizedBox(height: 6),
                        TimeUntil(date: event.date, precision: event.precision, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: launchInk)),
                        Text(event.when, style: TextStyle(fontSize: countdownAllowed(event.date, event.precision, 1) ? 15 : 22, fontWeight: FontWeight.w700)),
                        if (clock && event.date != null) ...[
                          const SizedBox(height: 6),
                          Text(formatUtcClock(event.date!), style: const TextStyle(color: launchInkMuted, fontSize: 13)),
                        ],
                      ]),
                    ),
                    const SizedBox(height: 12),
                    if (event.webcasts.isNotEmpty)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          style: event.webcastLive ? FilledButton.styleFrom(backgroundColor: launchLive, foregroundColor: Colors.white) : null,
                          onPressed: () => launchUrl(Uri.parse(event.webcasts.first.url), mode: LaunchMode.externalApplication),
                          icon: const Icon(Icons.play_circle_fill),
                          label: Text(event.webcastLive ? 'Watch live' : 'Watch the webcast'),
                        ),
                      ),
                    if (calendarable) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => launchUrl(Uri.parse('$siteOrigin/cal/event/${event.id}.ics'), mode: LaunchMode.externalApplication),
                        icon: const Icon(Icons.event_outlined, size: 18),
                        label: const Text('Add to calendar'),
                      ),
                    ],
                    if (event.description != null) ...[
                      const SectionHeader(title: 'About'),
                      Text(event.description!, style: text.bodyLarge?.copyWith(fontSize: 15.5)),
                    ],
                    if (event.agencies.isNotEmpty) ...[
                      const SectionHeader(title: 'Agencies'),
                      Wrap(spacing: 6, runSpacing: 6, children: [for (final a in event.agencies) Chip(label: Text(a, style: const TextStyle(fontSize: 12.5)))]),
                    ],
                    if (event.launchIds.isNotEmpty) _RelatedLaunches(ids: event.launchIds),
                    if (event.stationIds.isNotEmpty || event.astronautIds.isNotEmpty) _RelatedPeoplePlaces(event: event),
                    if (event.updates.isNotEmpty) ...[
                      const SectionHeader(title: 'Updates'),
                      for (final u in event.updates.take(5))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Panel(
                            padding: const EdgeInsets.all(12),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              if (u.createdOn != null) Text(DateFormat.yMMMd().add_jm().format(u.createdOn!.toLocal()), style: const TextStyle(color: launchInkFaint, fontSize: 12)),
                              Text(u.comment ?? 'Update posted.', style: const TextStyle(fontSize: 14, height: 1.4)),
                            ]),
                          ),
                        ),
                    ],
                    RelatedNews(eventId: event.id),
                    if (event.sources.isNotEmpty) ...[
                      const SectionHeader(title: 'Sources'),
                      for (final s in event.sources)
                        TextButton.icon(
                          style: TextButton.styleFrom(alignment: Alignment.centerLeft, padding: const EdgeInsets.symmetric(horizontal: 4)),
                          onPressed: () => launchUrl(Uri.parse(s.url), mode: LaunchMode.externalApplication),
                          icon: const Icon(Icons.open_in_new, size: 16),
                          label: Text(s.title ?? Uri.tryParse(s.url)?.host ?? s.url, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                  ]),
                ),
              ),
            ),
          ]),
        );
      },
    );
  }
}

class _RelatedLaunches extends StatelessWidget {
  const _RelatedLaunches({required this.ids});

  final List<String> ids;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<LaunchRecord>>(
      stream: LaunchWatchScope.repositoryOf(context).everything(),
      builder: (context, snap) {
        final launches = (snap.data ?? const <LaunchRecord>[]).where((l) => ids.contains(l.id)).toList();
        if (launches.isEmpty) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SectionHeader(title: 'Related launch'),
          for (final l in launches) Padding(padding: const EdgeInsets.only(bottom: 8), child: LaunchRow(launch: l)),
        ]);
      },
    );
  }
}

class _RelatedPeoplePlaces extends StatelessWidget {
  const _RelatedPeoplePlaces({required this.event});

  final SpaceEvent event;

  @override
  Widget build(BuildContext context) {
    final space = LaunchWatchScope.spaceOf(context);
    return StreamBuilder<List<Station>>(
      stream: space.stations(),
      builder: (context, snap) {
        final stations = (snap.data ?? const <Station>[]).where((s) => event.stationIds.contains(s.id)).toList();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (stations.isNotEmpty) ...[
            const SectionHeader(title: 'Where'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final s in stations)
                ActionChip(avatar: const Icon(Icons.satellite_alt_outlined, size: 16), label: Text(s.name), onPressed: () => openStation(context, s.id)),
            ]),
          ],
          if (event.astronautIds.isNotEmpty) ...[
            const SectionHeader(title: 'Who'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final id in event.astronautIds)
                StreamBuilder<Astronaut?>(
                  stream: space.astronaut(id),
                  builder: (context, a) => a.data == null
                      ? const SizedBox.shrink()
                      : ActionChip(avatar: Avatar(name: a.data!.name, imageUrl: a.data!.thumbUrl, size: 24), label: Text(a.data!.name), onPressed: () => openAstronaut(context, id)),
                ),
            ]),
          ],
        ]);
      },
    );
  }
}
