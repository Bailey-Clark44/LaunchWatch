import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import 'app_state.dart';
import 'space_data.dart';
import 'theme.dart';
import 'widgets.dart';

String _years(String? from, String? to) {
  final a = from == null ? null : DateTime.tryParse(from);
  final b = to == null ? null : DateTime.tryParse(to);
  if (a == null) return '';
  return b == null ? 'Since ${a.year}' : '${a.year}–${b.year}';
}

/// Every station LL2 knows: the ones crewed today first, then history.
class StationsPage extends StatelessWidget {
  const StationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Space stations')),
      body: StreamBuilder<List<Station>>(
        stream: LaunchWatchScope.spaceOf(context).stations(),
        builder: (context, snap) {
          final all = snap.data;
          if (all == null) return const Center(child: CircularProgressIndicator());
          if (all.isEmpty) return const EmptyState(icon: Icons.satellite_alt_outlined, title: 'Station data is on its way');
          final active = all.where((s) => s.active).toList();
          final past = all.where((s) => !s.active).toList();
          return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
            ContentWidth(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (active.isNotEmpty) const SectionHeader(title: 'In orbit and crewed', padding: EdgeInsets.fromLTRB(0, 8, 0, 10)),
                for (final s in active) Padding(padding: const EdgeInsets.only(bottom: 10), child: StationCard(station: s)),
                if (past.isNotEmpty) const SectionHeader(title: 'Past and other stations'),
                for (final s in past)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Panel(
                      padding: const EdgeInsets.all(10),
                      onTap: () => openStation(context, s.id),
                      child: Row(children: [
                        ClipRRect(borderRadius: BorderRadius.circular(8), child: SizedBox(width: 56, height: 56, child: LaunchPoster(imageUrl: s.thumbUrl, label: s.name, height: 56))),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text([s.status, _years(s.founded, s.deorbited), s.owners.take(2).join(', ')].where((x) => x != null && x.isNotEmpty).join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: launchInkMuted, fontSize: 12.5)),
                          ]),
                        ),
                        const Icon(Icons.chevron_right, color: launchInkMuted),
                      ]),
                    ),
                  ),
              ]),
            ),
          ]);
        },
      ),
    );
  }
}

class StationCard extends StatelessWidget {
  const StationCard({super.key, required this.station, this.compact = false});

  final Station station;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final h = compact ? 110.0 : 150.0;
    return Material(
      color: launchSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: launchLine)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openStation(context, station.id),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            height: h,
            child: Stack(fit: StackFit.expand, children: [
              LaunchPoster(imageUrl: compact ? (station.thumbUrl ?? station.imageUrl) : station.imageUrl, label: station.name, height: h),
              const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xE60A0D12)]))),
              Positioned(left: 12, right: 12, bottom: 10, child: Text(station.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16))),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Row(children: [
              const Icon(Icons.person_outline, size: 16, color: launchCrew),
              const SizedBox(width: 4),
              Text('${station.onboardCrew ?? 0} aboard', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(width: 14),
              const Icon(Icons.link, size: 16, color: launchAccent),
              const SizedBox(width: 4),
              Text('${station.dockedVehicles ?? station.occupied.length} docked', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class StationPage extends StatelessWidget {
  const StationPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    final space = LaunchWatchScope.spaceOf(context);
    return StreamBuilder<Station?>(
      stream: space.station(id),
      builder: (context, snap) {
        final s = snap.data;
        if (snap.connectionState == ConnectionState.waiting && s == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        if (s == null) return Scaffold(appBar: AppBar(), body: const EmptyState(icon: Icons.satellite_alt_outlined, title: 'Station not found'));
        final text = Theme.of(context).textTheme;
        final founded = s.foundedDate;
        return Scaffold(
          body: CustomScrollView(slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 240,
              title: Text(s.name),
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(fit: StackFit.expand, children: [
                  LaunchPoster(imageUrl: s.imageUrl, label: s.name, height: double.infinity),
                  const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x99000000), Color(0x00000000), Color(0xFF0A0D12)], stops: [0, 0.4, 1]))),
                ]),
              ),
            ),
            SliverToBoxAdapter(
              child: ContentWidth(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Wrap(spacing: 6, children: [
                      if (s.active) const StatusChip(rawName: 'Active') else if (s.status != null) StatusChip(rawName: s.status!),
                      if (s.type != null) TagChip(label: s.type!, icon: Icons.satellite_alt_outlined),
                    ]),
                    const SizedBox(height: 10),
                    Text(s.name, style: text.headlineMedium),
                    Text([s.orbit, s.owners.join(', ')].whereType<String>().where((x) => x.isNotEmpty).join(' · '), style: const TextStyle(color: launchInkMuted)),
                    const SizedBox(height: 16),
                    Row(children: [
                      _Metric(value: '${s.onboardCrew ?? 0}', label: 'Crew aboard'),
                      const SizedBox(width: 8),
                      _Metric(value: '${s.dockedVehicles ?? s.occupied.length}', label: 'Docked'),
                      const SizedBox(width: 8),
                      _Metric(
                        value: founded == null ? '—' : (s.active ? '${(DateTime.now().difference(founded).inDays / 365.25).floor()} yrs' : '${founded.year}'),
                        label: s.active ? 'In orbit' : 'Launched',
                      ),
                    ]),
                    if (s.activeExpeditionIds.isNotEmpty) _Crew(station: s),
                    if (s.occupied.isNotEmpty) ...[
                      const SectionHeader(title: 'Docked right now'),
                      Panel(
                        padding: EdgeInsets.zero,
                        child: Column(children: [
                          for (var i = 0; i < s.occupied.length; i++) ...[
                            if (i > 0) const Divider(indent: 64),
                            ListTile(
                              leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: SizedBox(width: 40, height: 40, child: LaunchPoster(imageUrl: s.occupied[i].thumbUrl, label: s.occupied[i].spacecraft!, height: 40))),
                              title: Text(s.occupied[i].spacecraft!),
                              subtitle: Text([s.occupied[i].port, if (s.occupied[i].since != null) 'since ${DateFormat.yMMMd().format(s.occupied[i].since!.toLocal())}'].join(' · ')),
                              trailing: s.occupied[i].launchId == null ? null : const Icon(Icons.chevron_right),
                              onTap: s.occupied[i].launchId == null ? null : () => openLaunch(context, s.occupied[i].launchId!),
                            ),
                          ],
                        ]),
                      ),
                    ],
                    _Traffic(station: s),
                    if (s.description != null) ...[
                      const SectionHeader(title: 'About'),
                      Text(s.description!, style: text.bodyLarge?.copyWith(fontSize: 15.5)),
                    ],
                    const SectionHeader(title: 'Specifications'),
                    Panel(
                      padding: EdgeInsets.zero,
                      child: Column(children: [
                        for (final (label, value) in [
                          ('Launched', founded == null ? null : DateFormat.yMMMMd().format(founded)),
                          ('Deorbited', s.deorbited),
                          ('Mass', s.mass == null ? null : '${NumberFormat.decimalPattern().format(s.mass)} t'),
                          ('Pressurised volume', s.volume == null ? null : '${NumberFormat.decimalPattern().format(s.volume)} m³'),
                          ('Length', s.height == null ? null : '${s.height} m'),
                          ('Width', s.width == null ? null : '${s.width} m'),
                          ('Docking ports', s.ports.isEmpty ? null : '${s.ports.length}'),
                        ])
                          if (value != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                              child: Row(children: [
                                SizedBox(width: 150, child: Text(label, style: const TextStyle(color: launchInkMuted, fontSize: 13.5))),
                                Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
                              ]),
                            ),
                      ]),
                    ),
                    _Walks(station: s),
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

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Panel(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, fontFeatures: tabularFigures)),
            Text(label, style: const TextStyle(color: launchInkMuted, fontSize: 12)),
          ]),
        ),
      );
}

class _Crew extends StatelessWidget {
  const _Crew({required this.station});

  final Station station;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Expedition>>(
      stream: LaunchWatchScope.spaceOf(context).expeditions(),
      builder: (context, snap) {
        final expeditions = (snap.data ?? const <Expedition>[]).where((e) => station.activeExpeditionIds.contains(e.id) || (e.active && e.stationId == station.id)).toList();
        if (expeditions.isEmpty) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final e in expeditions) ...[
            SectionHeader(title: 'Crew · ${e.name}', trailing: e.start == null ? null : Text('since ${DateFormat.yMMMd().format(e.start!.toLocal())}', style: const TextStyle(color: launchInkFaint, fontSize: 12))),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: MediaQuery.sizeOf(context).width > 600 ? 4 : 3,
              mainAxisSpacing: 14,
              crossAxisSpacing: 10,
              childAspectRatio: 0.78,
              children: [
                for (final c in e.crew)
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => openAstronaut(context, c.id),
                    child: Column(children: [
                      Avatar(name: c.name, imageUrl: c.thumbUrl, size: 64, ring: launchLineStrong),
                      const SizedBox(height: 6),
                      Text(c.name, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.2)),
                      Text([c.role, c.agency].whereType<String>().join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: launchInkMuted)),
                    ]),
                  ),
              ],
            ),
          ],
        ]);
      },
    );
  }
}

/// Recent and upcoming arrivals and departures at this station.
class _Traffic extends StatelessWidget {
  const _Traffic({required this.station});

  final Station station;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Docking>>(
      stream: LaunchWatchScope.spaceOf(context).dockings(),
      builder: (context, snap) {
        final list = (snap.data ?? const <Docking>[]).where((d) => d.stationId == station.id).take(6).toList();
        if (list.isEmpty) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SectionHeader(title: 'Arrivals'),
          for (final d in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Icon(d.upcoming ? Icons.schedule : (d.departure == null ? Icons.link : Icons.link_off), size: 16, color: d.upcoming ? launchAccent : launchInkMuted),
                const SizedBox(width: 10),
                Expanded(child: Text(d.spacecraft, style: const TextStyle(fontWeight: FontWeight.w500))),
                Text(
                  d.docking == null ? '' : (d.upcoming ? 'due ${relativeDay(d.docking!)}' : DateFormat.yMMMd().format(d.docking!.toLocal())),
                  style: const TextStyle(color: launchInkMuted, fontSize: 12.5),
                ),
              ]),
            ),
        ]);
      },
    );
  }
}

String relativeDay(DateTime t) {
  final days = DateUtils.dateOnly(t.toLocal()).difference(DateUtils.dateOnly(DateTime.now())).inDays;
  if (days == 0) return 'today';
  if (days == 1) return 'tomorrow';
  return DateFormat.MMMd().format(t.toLocal());
}

class _Walks extends StatelessWidget {
  const _Walks({required this.station});

  final Station station;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Spacewalk>>(
      stream: LaunchWatchScope.spaceOf(context).spacewalks(),
      builder: (context, snap) {
        final list = (snap.data ?? const <Spacewalk>[]).where((w) => w.stationId == station.id).take(4).toList();
        if (list.isEmpty) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SectionHeader(title: 'Recent spacewalks'),
          for (final w in list) Padding(padding: const EdgeInsets.only(bottom: 8), child: SpacewalkTile(walk: w)),
        ]);
      },
    );
  }
}

class SpacewalkTile extends StatelessWidget {
  const SpacewalkTile({super.key, required this.walk});

  final Spacewalk walk;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.all(12),
      onTap: walk.eventId == null ? null : () => openEvent(context, walk.eventId!),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.accessibility_new, size: 18, color: launchAccent),
          const SizedBox(width: 8),
          Expanded(child: Text(walk.name, style: const TextStyle(fontWeight: FontWeight.w600))),
          if (walk.duration != null) Text(formatSpan(walk.duration!), style: const TextStyle(fontWeight: FontWeight.w600, fontFeatures: tabularFigures)),
        ]),
        const SizedBox(height: 4),
        Text([if (walk.start != null) DateFormat.yMMMd().format(walk.start!.toLocal()), walk.location].whereType<String>().join(' · '), style: const TextStyle(color: launchInkMuted, fontSize: 12.5)),
        if (walk.crew.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final c in walk.crew)
              ActionChip(
                visualDensity: VisualDensity.compact,
                avatar: Avatar(name: c.name, imageUrl: c.thumbUrl, size: 22),
                label: Text(c.name, style: const TextStyle(fontSize: 12.5)),
                onPressed: () => openAstronaut(context, c.id),
              ),
          ]),
        ],
      ]),
    );
  }
}
