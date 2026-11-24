import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import 'app_state.dart';
import 'format_net.dart';
import 'inbox_page.dart';
import 'launch_repository.dart';
import 'locate.dart';
import 'since_last.dart';
import 'theme.dart';
import 'visibility.dart';
import 'widgets.dart';

enum LaunchFilter { all, crewed, firm, nearMe, following }

class LaunchesPage extends StatefulWidget {
  const LaunchesPage({super.key, required this.repository});

  final LaunchRepository repository;

  @override
  State<LaunchesPage> createState() => _LaunchesPageState();
}

class _LaunchesPageState extends State<LaunchesPage> {
  late final Stream<List<LaunchRecord>> _launches = widget.repository.everything();
  late final Stream<DateTime?> _updatedAt = widget.repository.catalogUpdatedAt();
  String _query = '';
  bool _upcoming = true;
  LaunchFilter _filter = LaunchFilter.all;
  Future<SinceLastLook?>? _sinceLast;
  bool _sinceDismissed = false;

  bool _matches(LaunchRecord launch) {
    if (_query.isNotEmpty &&
        ![launch.name, launch.provider, launch.vehicle, launch.pad, launch.location, launch.missionType]
            .whereType<String>()
            .join(' ')
            .toLowerCase()
            .contains(_query)) {
      return false;
    }
    final account = LaunchWatchScope.of(context);
    return switch (_filter) {
      LaunchFilter.all => true,
      LaunchFilter.crewed => launch.crewed,
      LaunchFilter.firm => precisionHasClock(launch.precisionAbbrev),
      LaunchFilter.following => account.following(launch.id),
      LaunchFilter.nearMe => _nearMe(launch, account.homeCity),
    };
  }

  bool _nearMe(LaunchRecord launch, City? city) {
    if (city == null || launch.padLatitude == null || launch.padLongitude == null) return false;
    final estimate = estimateVisibility(city: city, padLatitude: launch.padLatitude!, padLongitude: launch.padLongitude!, suborbital: launch.suborbital);
    return estimate.tier.index <= VisibilityTier.possible.index;
  }

  @override
  Widget build(BuildContext context) {
    final account = LaunchWatchScope.of(context);
    final selected = SplitSelection.maybeOf(context)?.value;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<List<LaunchRecord>>(
          stream: _launches,
          builder: (context, snapshot) {
            final all = snapshot.data;
            if (all != null && _sinceLast == null && account.prefs != null) {
              _sinceLast = compareWithLastLook(all, prefs: account.prefs);
            }
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _Header(updatedAt: _updatedAt, unread: account.signedIn ? account.unread : null)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Column(children: [
                      SearchField(hint: 'Search missions, rockets, providers, pads', padding: EdgeInsets.zero, onChanged: (v) => setState(() => _query = v.trim().toLowerCase())),
                      const SizedBox(height: 12),
                      _Segment(upcoming: _upcoming, onChanged: (v) => setState(() => _upcoming = v)),
                    ]),
                  ),
                ),
                if (_upcoming)
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 58,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        children: [
                          _filterChip('All', LaunchFilter.all),
                          _filterChip('Crewed', LaunchFilter.crewed, icon: Icons.person_outline),
                          _filterChip('Exact time', LaunchFilter.firm, icon: Icons.schedule),
                          _filterChip(account.homeCity == null ? 'Visible near me' : 'Visible from ${account.homeCity!.name}', LaunchFilter.nearMe, icon: Icons.visibility_outlined),
                          if (account.signedIn) _filterChip('Following', LaunchFilter.following, icon: Icons.bookmark_outline),
                        ],
                      ),
                    ),
                  ),
                if (snapshot.hasError)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(icon: Icons.cloud_off, title: "Couldn't load launches", body: 'Check your connection. The list will appear as soon as it can be reached.'),
                  )
                else if (all == null)
                  const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator()))
                else
                  ..._content(all, selected),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _filterChip(String label, LaunchFilter filter, {IconData? icon}) {
    final selected = _filter == filter;
    final color = selected ? launchInk : launchInkMuted;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: selected ? launchSelection : launchSurface,
          shape: StadiumBorder(side: BorderSide(color: selected ? launchAccent.withValues(alpha: 0.5) : launchLine)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: () async {
              if (filter == LaunchFilter.nearMe && LaunchWatchScope.of(context).homeCity == null) {
                final city = await pickHomeCity(context);
                if (city == null || !mounted) return;
              }
              setState(() => _filter = filter);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (icon != null) ...[Icon(icon, size: 15, color: color), const SizedBox(width: 6)],
                Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _content(List<LaunchRecord> all, String? selected) {
    final listName = _upcoming ? 'upcoming' : 'recent';
    final launches = all.where((l) => l.list == listName && _matches(l)).toList();
    if (!_upcoming) launches.sort((a, b) => (b.net ?? DateTime.utc(0)).compareTo(a.net ?? DateTime.utc(0)));

    final slivers = <Widget>[];
    if (_upcoming && _query.isEmpty && _filter == LaunchFilter.all && !_sinceDismissed) {
      slivers.add(SliverToBoxAdapter(
        child: FutureBuilder<SinceLastLook?>(
          future: _sinceLast,
          builder: (context, snap) {
            final since = snap.data;
            if (since == null || since.isEmpty) return const SizedBox.shrink();
            return Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: _SinceStrip(since: since, onClose: () => setState(() => _sinceDismissed = true)));
          },
        ),
      ));
    }

    if (launches.isEmpty) {
      slivers.add(SliverFillRemaining(
        hasScrollBody: false,
        child: EmptyState(
          icon: _filter == LaunchFilter.following ? Icons.bookmark_outline : Icons.search_off,
          title: switch (_filter) {
            LaunchFilter.following => 'You are not following any upcoming launches',
            LaunchFilter.nearMe => 'Nothing visible from ${LaunchWatchScope.of(context).homeCity?.name ?? 'your area'} soon',
            _ => _query.isEmpty ? 'No launches in this list' : 'No launches match "$_query"',
          },
          body: _filter == LaunchFilter.following ? 'Open a launch and tap Follow to get alerts when it moves.' : null,
        ),
      ));
      return slivers;
    }

    if (!_upcoming) {
      for (final group in _groupRecent(launches)) {
        slivers.add(_sectionSliver(group.$1, null));
        slivers.add(_rowsSliver(group.$2, selected));
      }
      return slivers;
    }

    final dated = launches.where((l) => l.isDated).toList();
    final undated = launches.where((l) => !l.isDated).toList();
    final showFeature = _query.isEmpty && dated.isNotEmpty;
    if (showFeature) {
      final featured = dated.firstWhere((l) => l.isLive, orElse: () => dated.first);
      dated.remove(featured);
      slivers.add(SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 0), child: _FeaturedLaunch(launch: featured, selected: selected == featured.id))));
    }
    for (final group in _groupUpcoming(dated)) {
      slivers.add(_sectionSliver(group.$1, plural(group.$2.length, 'launch', 'launches')));
      slivers.add(_rowsSliver(group.$2, selected));
    }
    if (undated.isNotEmpty) {
      slivers.add(_sectionSliver('Not yet scheduled', plural(undated.length, 'launch', 'launches')));
      slivers.add(const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Text('Providers have only named a month, quarter, or year for these. They move up the list once a date is set.', style: TextStyle(color: launchInkMuted, fontSize: 13, height: 1.4)),
        ),
      ));
      slivers.add(_rowsSliver(undated, selected));
    }
    return slivers;
  }

  Widget _sectionSliver(String title, String? trailing) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SectionHeader(title: title, trailing: trailing == null ? null : Text(trailing, style: const TextStyle(color: launchInkFaint, fontSize: 12))),
      ),
    );
  }

  Widget _rowsSliver(List<LaunchRecord> launches, String? selected) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList.separated(
        itemCount: launches.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, i) => LaunchRow(launch: launches[i], selected: launches[i].id == selected),
      ),
    );
  }
}

/// Groups dated launches into Today, Tomorrow, This week, then by month.
List<(String, List<LaunchRecord>)> _groupUpcoming(List<LaunchRecord> launches, {DateTime? now}) {
  final today = DateUtils.dateOnly(now ?? DateTime.now());
  final groups = <String, List<LaunchRecord>>{};
  for (final l in launches) {
    final day = DateUtils.dateOnly(l.net!.toLocal());
    final diff = day.difference(today).inDays;
    final key = diff <= 0
        ? 'Today'
        : diff == 1
            ? 'Tomorrow'
            : diff < 7
                ? 'This week'
                : DateFormat.yMMMM().format(day);
    groups.putIfAbsent(key, () => []).add(l);
  }
  return groups.entries.map((e) => (e.key, e.value)).toList();
}

List<(String, List<LaunchRecord>)> _groupRecent(List<LaunchRecord> launches) {
  final today = DateUtils.dateOnly(DateTime.now());
  final groups = <String, List<LaunchRecord>>{};
  for (final l in launches) {
    final diff = l.net == null ? 99 : today.difference(DateUtils.dateOnly(l.net!.toLocal())).inDays;
    final key = diff <= 0 ? 'Today' : diff == 1 ? 'Yesterday' : diff < 7 ? 'Earlier this week' : 'Earlier';
    groups.putIfAbsent(key, () => []).add(l);
  }
  return groups.entries.map((e) => (e.key, e.value)).toList();
}

class _Header extends StatelessWidget {
  const _Header({required this.updatedAt, required this.unread});

  final Stream<DateTime?> updatedAt;
  final int? unread;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
      child: StreamBuilder<DateTime?>(
        stream: updatedAt,
        builder: (context, snap) {
          final at = snap.data;
          final stale = at != null && DateTime.now().difference(at) > const Duration(hours: 2);
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Semantics(header: true, child: Text('Launches', style: Theme.of(context).textTheme.headlineMedium)),
                  const SizedBox(height: 2),
                  Text(
                    at == null ? 'Launch Library 2 · times in your timezone' : 'Updated ${relativeAge(at)} · times in your timezone',
                    style: const TextStyle(color: launchInkMuted, fontSize: 13),
                  ),
                ]),
              ),
              if (unread != null)
                IconButton(
                  tooltip: 'Alerts',
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const InboxPage())),
                  icon: Badge(isLabelVisible: unread! > 0, label: Text('$unread'), backgroundColor: launchLive, child: const Icon(Icons.notifications_none)),
                ),
            ]),
            if (stale) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: NoticeStrip(icon: Icons.history, text: 'Last updated ${DateFormat.jm().format(at.toLocal())}, ${relativeAge(at)}. Times may have changed since; the list is still usable.'),
              ),
            ],
          ]);
        },
      ),
    );
  }
}

class _SinceStrip extends StatelessWidget {
  const _SinceStrip({required this.since, required this.onClose});

  final SinceLastLook since;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final names = [...since.slipped, ...since.movedUp, ...since.succeeded, ...since.failed].take(3).map((l) => l.shortName).join(', ');
    return Panel(
      padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
      color: launchSelection,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Icons.update, size: 18, color: launchAccent)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Since you last looked: ${since.summary()}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 3),
            Text(names, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: launchInkMuted, fontSize: 13)),
          ]),
        ),
        IconButton(tooltip: 'Dismiss', visualDensity: VisualDensity.compact, onPressed: onClose, icon: const Icon(Icons.close, size: 18, color: launchInkMuted)),
      ]),
    );
  }
}

class _FeaturedLaunch extends StatelessWidget {
  const _FeaturedLaunch({required this.launch, required this.selected});

  final LaunchRecord launch;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final account = LaunchWatchScope.of(context);
    final showCountdown = countdownAllowed(launch.net, launch.precisionAbbrev, launch.statusId);
    return Material(
      color: launchSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: selected ? launchAccent : launchLine)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openLaunch(context, launch.id),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            height: 210,
            child: Stack(fit: StackFit.expand, children: [
              LaunchPoster(imageUrl: launch.imageUrl, label: launch.vehicle ?? launch.name, height: 210),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x33000000), Color(0x00000000), Color(0xF20A0D12)], stops: [0, 0.35, 1]),
                ),
              ),
              Positioned(
                left: 16,
                top: 14,
                child: launch.isLive
                    ? const LiveBadge(label: 'LIVE NOW')
                    : Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xB30A0D12), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0x33FFFFFF))),
                        child: const Text('NEXT LAUNCH', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                      ),
              ),
              if (account.following(launch.id))
                const Positioned(right: 14, top: 12, child: Icon(Icons.bookmark, color: Colors.white, size: 20)),
              Positioned(
                left: 16,
                right: 16,
                bottom: 14,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(launch.shortName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.4, height: 1.15)),
                  const SizedBox(height: 4),
                  Text([launch.vehicle, launch.provider].whereType<String>().join('  ·  '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFC9D2DF), fontSize: 13)),
                ]),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (showCountdown)
                    Countdown(launch: launch, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: launchInk))
                  else
                    Text(launch.when, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: launchInk)),
                  const SizedBox(height: 3),
                  Text(showCountdown ? launch.when : precisionLabel(launch.precisionAbbrev), style: const TextStyle(fontSize: 12.5, color: launchInkMuted)),
                ]),
              ),
              Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.end, children: [
                if (launch.crewed) const TagChip.crew(),
                StatusChip(rawName: launch.status),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// One launch in a list: date badge, mission, vehicle and provider, status.
class LaunchRow extends StatelessWidget {
  const LaunchRow({super.key, required this.launch, this.selected = false});

  final LaunchRecord launch;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final account = LaunchWatchScope.of(context);
    final (top, bottom) = formatNetBadge(launch.net, launch.precisionAbbrev);
    final clock = formatRowClock(launch.net, launch.precisionAbbrev);
    final details = [launch.vehicle, launch.provider].whereType<String>().where((v) => v.isNotEmpty).join(' · ');
    final dated = launch.isDated;
    return Semantics(
      button: true,
      label: '${launch.name}. ${launch.when}. Status ${statusLabel(launch.status)}.${launch.crewed ? ' Crewed.' : ''}',
      excludeSemantics: true,
      child: Material(
        color: selected ? launchSelection : launchSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: selected ? launchAccent.withValues(alpha: 0.6) : launchLine)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openLaunch(context, launch.id),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 56,
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(color: dated ? launchSurfaceRaised : Colors.transparent, borderRadius: BorderRadius.circular(10), border: dated ? null : Border.all(color: launchLineStrong)),
                child: Column(children: [
                  Text(top, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: dated ? launchAccent : launchInkMuted)),
                  const SizedBox(height: 1),
                  Text(bottom, style: TextStyle(fontSize: dated ? 19 : 14, fontWeight: FontWeight.w700, color: dated ? launchInk : launchInkMuted, fontFeatures: tabularFigures)),
                ]),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: Text(launch.shortName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: launchInk, fontSize: 15, fontWeight: FontWeight.w600, height: 1.3))),
                    if (account.following(launch.id)) const Padding(padding: EdgeInsets.only(left: 6, top: 2), child: Icon(Icons.bookmark, size: 16, color: launchAccent)),
                  ]),
                  if (details.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(details, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: launchInkMuted, fontSize: 13)),
                  ],
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    if (launch.isLive) const LiveBadge() else StatusChip(rawName: launch.status, dense: true),
                    if (launch.crewed) const TagChip.crew(),
                    if (launch.suborbital) const TagChip.suborbital(),
                    if (countdownAllowed(launch.net, launch.precisionAbbrev, launch.statusId))
                      Countdown(launch: launch, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: launchInk))
                    else if (clock != null)
                      Text(clock, style: const TextStyle(fontSize: 12.5, color: launchInkMuted, fontFeatures: tabularFigures)),
                  ]),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.upcoming, required this.onChanged});

  final bool upcoming;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
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
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        segments: const [
          ButtonSegment(value: true, label: Text('Upcoming')),
          ButtonSegment(value: false, label: Text('Recent')),
        ],
        selected: {upcoming},
        onSelectionChanged: (s) => onChanged(s.first),
      ),
    );
  }
}

/// Lets someone choose where they watch from. Returns the city, or null.
Future<City?> pickHomeCity(BuildContext context) async {
  final account = LaunchWatchScope.of(context);
  final city = await showModalBottomSheet<City>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _CityPicker(),
  );
  if (city != null) await account.setHomeCity(city);
  return city;
}

class _CityPicker extends StatefulWidget {
  const _CityPicker();

  @override
  State<_CityPicker> createState() => _CityPickerState();
}

class _CityPickerState extends State<_CityPicker> {
  String _q = '';
  bool _locating = false;
  LocationProblem? _problem;

  Future<void> _useMyLocation() async {
    setState(() {
      _locating = true;
      _problem = null;
    });
    try {
      final here = await locateMe();
      if (mounted) Navigator.of(context).pop(here);
    } on LocationProblem catch (problem) {
      if (mounted) setState(() => _problem = problem);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final matches = cities.where((c) => c.label.toLowerCase().contains(_q)).toList()..sort((a, b) => a.name.compareTo(b.name));
    final current = LaunchWatchScope.of(context).homeCity;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Where do you watch from?', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            const Text(
              'LaunchWatch uses this to estimate which launches you could see. Your location is only read when you tap below, rounded to about 1 km, and never shared.',
              style: TextStyle(color: launchInkMuted, fontSize: 13.5, height: 1.4),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Material(
            color: launchSurfaceRaised,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: launchLine)),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: _locating
                  ? const SizedBox(width: 24, height: 24, child: Padding(padding: EdgeInsets.all(2), child: CircularProgressIndicator(strokeWidth: 2.4)))
                  : const Icon(Icons.my_location, color: launchAccent),
              title: Text(_locating ? 'Finding your location…' : 'Use my current location'),
              subtitle: Text(
                current != null && current.isCurrentLocation ? 'Now: ${current.region} · tap to update' : 'Approximate, from GPS, Wi-Fi or your network',
              ),
              enabled: !_locating,
              onTap: _useMyLocation,
            ),
          ),
        ),
        if (_problem != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: NoticeStrip(
              icon: Icons.location_off_outlined,
              text: _problem!.message,
              action: _problem!.canOpenSettings ? TextButton(onPressed: openLocationSettings, child: const Text('Settings')) : null,
            ),
          ),
        SearchField(hint: 'Or search cities', onChanged: (v) => setState(() => _q = v.trim().toLowerCase())),
        Expanded(
          child: ListView.builder(
            itemCount: matches.length,
            itemBuilder: (context, i) => ListTile(
              title: Text(matches[i].name),
              subtitle: Text(matches[i].region),
              selected: current?.id == matches[i].id,
              onTap: () => Navigator.of(context).pop(matches[i]),
            ),
          ),
        ),
      ]),
    );
  }
}
