import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import 'catalog.dart';
import 'launch_list_page.dart' show LaunchRow;
import 'launch_repository.dart';
import 'theme.dart';
import 'widgets.dart';

class VehicleProfilePage extends StatelessWidget {
  const VehicleProfilePage({super.key, required this.group, required this.repository});

  final VehicleGroup group;
  final LaunchRepository repository;

  @override
  Widget build(BuildContext context) {
    final operators = group.operators;
    return Scaffold(
      body: CustomScrollView(slivers: [
        _HeroAppBar(title: group.name, eyebrow: 'LAUNCH VEHICLE', imageUrl: group.imageUrl),
        SliverToBoxAdapter(
          child: ContentWidth(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                StreamBuilder<HistoricalLaunchCount?>(
                  stream: repository.historicalCount('vehicle', group.key),
                  builder: (context, snap) {
                    final s = snap.data;
                    final rate = s?.successRate;
                    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _Metrics(items: [
                        if (s != null) ('Flights to date', '${s.pastLaunches}'),
                        if (rate != null) ('Success rate', '${(rate * 100).toStringAsFixed(rate > 0.995 && rate < 1 ? 1 : 0)}%'),
                        ('Upcoming', '${group.upcoming}'),
                        if (s == null) ('Operators', '${operators.length}'),
                      ]),
                      if (s != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            [
                              if (s.successfulLaunches != null) '${s.successfulLaunches} successful',
                              if (s.failedLaunches != null && s.failedLaunches! > 0) '${s.failedLaunches} failed',
                              if (s.maidenFlight != null) 'first flew ${_date(s.maidenFlight!)}',
                              if (s.active != null) s.active! ? 'in service' : 'retired',
                            ].join(' · '),
                            style: const TextStyle(color: launchInkMuted, fontSize: 13),
                          ),
                        ),
                    ]);
                  },
                ),
                if (operators.isNotEmpty) ...[
                  const SectionHeader(title: 'Operated by'),
                  for (final op in operators)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _RelatedRow(
                        icon: Icons.apartment,
                        title: op.name,
                        subtitle: _counts(op.upcoming, op.recent),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => OrganisationProfilePage(group: op, repository: repository))),
                      ),
                    ),
                ],
                _LaunchFeed(launches: group.launches),
                const SizedBox(height: 16),
                const Text('Totals from Launch Library 2, refreshed weekly. Lists show the upcoming catalog and the last 20 launches.', style: TextStyle(color: launchInkFaint, fontSize: 12)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class OrganisationProfilePage extends StatelessWidget {
  const OrganisationProfilePage({super.key, required this.group, required this.repository});

  final OrganisationGroup group;
  final LaunchRepository repository;

  @override
  Widget build(BuildContext context) {
    final vehicles = group.vehicles;
    return Scaffold(
      body: CustomScrollView(slivers: [
        _HeroAppBar(title: group.name, eyebrow: 'LAUNCH PROVIDER', imageUrl: vehicles.isEmpty ? null : vehicles.first.imageUrl),
        SliverToBoxAdapter(
          child: ContentWidth(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                StreamBuilder<HistoricalLaunchCount?>(
                  stream: repository.historicalCount('organisation', group.key),
                  builder: (context, snap) => _Metrics(items: [
                    if (snap.data != null) ('Launches to date', '${snap.data!.pastLaunches}'),
                    ('Upcoming', '${group.upcoming}'),
                    ('Vehicles', '${vehicles.length}'),
                  ]),
                ),
                if (vehicles.isNotEmpty) ...[
                  const SectionHeader(title: 'Vehicles'),
                  for (final v in vehicles)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _RelatedRow(
                        icon: Icons.rocket_launch_outlined,
                        imageUrl: v.imageUrl,
                        title: v.name,
                        subtitle: _counts(v.upcoming, v.recent),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => VehicleProfilePage(group: v, repository: repository))),
                      ),
                    ),
                ],
                _LaunchFeed(launches: group.launches),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

String _counts(int upcoming, int recent) {
  final parts = [
    if (upcoming > 0) '$upcoming upcoming',
    if (recent > 0) '$recent recent',
  ];
  return parts.isEmpty ? 'No flights in the current catalog' : parts.join(' · ');
}

String _date(String iso) {
  final d = DateTime.tryParse(iso);
  return d == null ? iso : DateFormat.yMMMd().format(d);
}

class _HeroAppBar extends StatelessWidget {
  const _HeroAppBar({required this.title, required this.eyebrow, required this.imageUrl});

  final String title;
  final String eyebrow;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 220,
      backgroundColor: launchBackground,
      title: Text(title),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        titlePadding: EdgeInsets.zero,
        title: const SizedBox.shrink(),
        background: Stack(fit: StackFit.expand, children: [
          LaunchPoster(imageUrl: imageUrl, label: title, height: double.infinity),
          const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x99000000), Color(0x00000000), Color(0xFF0A0D12)], stops: [0, 0.4, 1]))),
          Positioned(
            left: 16,
            right: 16,
            bottom: 14,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(eyebrow, style: const TextStyle(color: launchAccent, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1.3)),
              const SizedBox(height: 4),
              Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.5, height: 1.1)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Metrics extends StatelessWidget {
  const _Metrics({required this.items});

  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      for (var i = 0; i < items.length; i++) ...[
        if (i > 0) const SizedBox(width: 8),
        Expanded(
          child: Panel(
            padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(items[i].$2, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.4, fontFeatures: tabularFigures)),
              const SizedBox(height: 2),
              Text(items[i].$1, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: launchInkMuted, fontSize: 12)),
            ]),
          ),
        ),
      ],
    ]);
  }
}

class _RelatedRow extends StatelessWidget {
  const _RelatedRow({required this.icon, required this.title, required this.subtitle, required this.onTap, this.imageUrl});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.all(10),
      onTap: onTap,
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: SizedBox(
            width: 40,
            height: 40,
            child: imageUrl == null ? ColoredBox(color: launchSurfaceRaised, child: Icon(icon, size: 19, color: launchAccent)) : LaunchPoster(imageUrl: imageUrl, label: title, height: 40),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(color: launchInkMuted, fontSize: 12.5)),
          ]),
        ),
        const Icon(Icons.chevron_right, color: launchInkMuted),
      ]),
    );
  }
}

class _LaunchFeed extends StatefulWidget {
  const _LaunchFeed({required this.launches});

  final List<LaunchRecord> launches;

  @override
  State<_LaunchFeed> createState() => _LaunchFeedState();
}

class _LaunchFeedState extends State<_LaunchFeed> {
  bool _upcoming = true;

  @override
  Widget build(BuildContext context) {
    final flights = widget.launches.where((l) => l.list == (_upcoming ? 'upcoming' : 'recent')).toList()
      ..sort((a, b) => _upcoming ? (a.net ?? DateTime.utc(9999)).compareTo(b.net ?? DateTime.utc(9999)) : (b.net ?? DateTime.utc(0)).compareTo(a.net ?? DateTime.utc(0)));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionHeader(
        title: 'Flights',
        trailing: SegmentedButton<bool>(
          showSelectedIcon: false,
          style: SegmentedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            selectedBackgroundColor: launchSurfaceRaised,
            selectedForegroundColor: launchInk,
            foregroundColor: launchInkMuted,
            side: const BorderSide(color: launchLine),
          ),
          segments: const [ButtonSegment(value: true, label: Text('Upcoming')), ButtonSegment(value: false, label: Text('Recent'))],
          selected: {_upcoming},
          onSelectionChanged: (s) => setState(() => _upcoming = s.first),
        ),
      ),
      if (flights.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(_upcoming ? 'Nothing scheduled in the catalog.' : 'No flights among the 20 most recent launches.', style: const TextStyle(color: launchInkMuted)),
        )
      else
        for (final l in flights) Padding(padding: const EdgeInsets.only(bottom: 8), child: LaunchRow(launch: l)),
    ]);
  }
}
