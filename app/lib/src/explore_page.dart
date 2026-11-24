import 'dart:async';

import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_state.dart';
import 'glossary.dart';
import 'launch_repository.dart';
import 'organisations_page.dart';
import 'people_page.dart';
import 'space_data.dart';
import 'station_page.dart';
import 'theme.dart';
import 'vehicles_page.dart';
import 'widgets.dart';

/// The hub for everything beyond the launch schedule.
class ExplorePage extends StatelessWidget {
  const ExplorePage({super.key, required this.repository});

  final LaunchRepository repository;

  @override
  Widget build(BuildContext context) {
    final space = LaunchWatchScope.spaceOf(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      'Explore',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'People, stations, programs, and the machines that get them there',
                    style: TextStyle(color: launchInkMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: InSpaceNow(),
            ),
            StreamBuilder<List<Station>>(
              stream: space.stations(),
              builder: (context, snap) {
                final active = (snap.data ?? const <Station>[])
                    .where((s) => s.active)
                    .toList();
                if (active.isEmpty) return const SizedBox.shrink();
                return Shelf(
                  title: 'Space stations',
                  height: 172,
                  itemWidth: 260,
                  onSeeAll: () => _push(context, const StationsPage()),
                  children: [
                    for (final s in active)
                      StationCard(station: s, compact: true),
                  ],
                );
              },
            ),
            StreamBuilder<List<Spacewalk>>(
              stream: space.spacewalks(),
              builder: (context, snap) {
                final walks = snap.data ?? const <Spacewalk>[];
                if (walks.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SectionHeader(
                        title: 'Latest spacewalks',
                        trailing: TextButton(
                          onPressed: () =>
                              _push(context, const SpacewalksPage()),
                          child: const Text('See all'),
                        ),
                      ),
                      for (final w in walks.take(2))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: SpacewalkTile(walk: w),
                        ),
                    ],
                  ),
                );
              },
            ),
            StreamBuilder<List<Program>>(
              stream: space.programs(),
              builder: (context, snap) {
                final programs = (snap.data ?? const <Program>[])
                    .where((p) => p.imageUrl != null)
                    .toList();
                if (programs.isEmpty) return const SizedBox.shrink();
                final ongoing = programs.where((p) => p.ongoing).toList();
                return Shelf(
                  title: 'Programs',
                  height: 150,
                  itemWidth: 200,
                  onSeeAll: () => _push(context, const ProgramsPage()),
                  children: [
                    for (final p in (ongoing.isEmpty ? programs : ongoing).take(
                      10,
                    ))
                      _ProgramCard(program: p),
                  ],
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionHeader(title: 'Directory'),
                  _DirectoryGrid(
                    entries: [
                      (
                        Icons.rocket_outlined,
                        'Rockets',
                        'Every vehicle on the schedule',
                        () => _push(
                          context,
                          VehiclesPage(repository: repository),
                          bare: true,
                        ),
                      ),
                      (
                        Icons.apartment_outlined,
                        'Providers',
                        'Agencies and launch companies',
                        () => _push(
                          context,
                          OrganisationsPage(repository: repository),
                          bare: true,
                        ),
                      ),
                      (
                        Icons.satellite_alt_outlined,
                        'Stations',
                        'From Salyut to Tiangong',
                        () => _push(context, const StationsPage()),
                      ),
                      (
                        Icons.accessibility_new,
                        'Spacewalks',
                        'Recent EVAs and their crews',
                        () => _push(context, const SpacewalksPage()),
                      ),
                      (
                        Icons.flag_outlined,
                        'Programs',
                        'Artemis, Starship, and more',
                        () => _push(context, const ProgramsPage()),
                      ),
                      (
                        Icons.menu_book_outlined,
                        'Glossary',
                        'NET, LEO, Max-Q, and friends',
                        () => _push(context, const GlossaryPage()),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _push(BuildContext context, Widget page, {bool bare = false}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => bare ? Scaffold(appBar: AppBar(), body: page) : page,
      ),
    );
  }
}

/// The headline number: everyone currently off the planet, with faces.
class InSpaceNow extends StatefulWidget {
  const InSpaceNow({super.key});

  @override
  State<InSpaceNow> createState() => _InSpaceNowState();
}

class _InSpaceNowState extends State<InSpaceNow> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final space = LaunchWatchScope.spaceOf(context);
    final presence = continuousPresence();
    String two(int n) => n.toString().padLeft(2, '0');
    final ticker =
        '${NumberFormat.decimalPattern().format(presence.inDays)}d ${two(presence.inHours % 24)}:${two(presence.inMinutes % 60)}:${two(presence.inSeconds % 60)}';
    return StreamBuilder<List<Astronaut>>(
      stream: space.peopleInSpace(),
      builder: (context, snap) {
        final people = snap.data ?? const <Astronaut>[];
        return Material(
          color: launchSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: launchLine),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const PeopleInSpacePage(),
              ),
            ),
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.9, -1.2),
                  radius: 1.4,
                  colors: [Color(0xFF1A2A48), Color(0x0011151C)],
                ),
              ),
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'IN SPACE RIGHT NOW',
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: launchAccent),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        people.isEmpty ? '—' : '${people.length}',
                        style: const TextStyle(
                          fontSize: 52,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -2,
                          height: 1,
                          fontFeatures: tabularFigures,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          people.length == 1 ? 'person' : 'people',
                          style: const TextStyle(
                            fontSize: 16,
                            color: launchInkMuted,
                          ),
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.arrow_forward, color: launchInkMuted),
                    ],
                  ),
                  if (people.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 36,
                      child: Stack(
                        children: [
                          for (var i = 0; i < people.length && i < 10; i++)
                            Positioned(
                              left: i * 26.0,
                              child: Avatar(
                                name: people[i].name,
                                imageUrl: people[i].thumbUrl,
                                size: 36,
                                ring: launchSurface,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  const Divider(),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.all_inclusive,
                        size: 16,
                        color: launchInkMuted,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Continuous human presence in orbit',
                          style: TextStyle(
                            color: launchInkMuted,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                      Text(
                        ticker,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontFeatures: tabularFigures,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DirectoryGrid extends StatelessWidget {
  const _DirectoryGrid({required this.entries});

  final List<(IconData, String, String, VoidCallback)> entries;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth > 600 ? 3 : 2;
        final w = (c.maxWidth - (cols - 1) * 8) / cols;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (icon, title, subtitle, onTap) in entries)
              SizedBox(
                width: w,
                child: Panel(
                  padding: const EdgeInsets.all(14),
                  onTap: onTap,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, color: launchAccent, size: 22),
                      const SizedBox(height: 10),
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: launchInkMuted,
                          fontSize: 12.5,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class SpacewalksPage extends StatelessWidget {
  const SpacewalksPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Spacewalks')),
      body: StreamBuilder<List<Spacewalk>>(
        stream: LaunchWatchScope.spaceOf(context).spacewalks(),
        builder: (context, snap) {
          final walks = snap.data;
          if (walks == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (walks.isEmpty) {
            return const EmptyState(
              icon: Icons.accessibility_new,
              title: 'Spacewalk records are on their way',
            );
          }
          final total = walks.fold<Duration>(
            Duration.zero,
            (sum, w) => sum + (w.duration ?? Duration.zero),
          );
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              ContentWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${walks.length} recent spacewalks · ${formatSpan(total)} outside in total',
                      style: const TextStyle(color: launchInkMuted),
                    ),
                    const SizedBox(height: 12),
                    for (final w in walks)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SpacewalkTile(walk: w),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class ProgramsPage extends StatelessWidget {
  const ProgramsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Programs')),
      body: StreamBuilder<List<Program>>(
        stream: LaunchWatchScope.spaceOf(context).programs(),
        builder: (context, snap) {
          final list = snap.data;
          if (list == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.flag_outlined,
              title: 'Programs are on their way',
            );
          }
          final ongoing = list.where((p) => p.ongoing).toList();
          final past = list.where((p) => !p.ongoing).toList();
          Widget grid(List<Program> items) => GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 260,
              mainAxisExtent: 150,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
            ),
            itemCount: items.length,
            itemBuilder: (_, i) => _ProgramCard(program: items[i]),
          );
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              if (ongoing.isNotEmpty) ...[
                const SectionHeader(title: 'Ongoing'),
                grid(ongoing),
              ],
              if (past.isNotEmpty) ...[
                const SectionHeader(title: 'Completed'),
                grid(past),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ProgramCard extends StatelessWidget {
  const _ProgramCard({required this.program});

  final Program program;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: launchSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: launchLine),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ProgramPage(program: program),
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            LaunchPoster(
              imageUrl: program.imageUrl,
              label: program.name,
              height: double.infinity,
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xF00A0D12)],
                  stops: [0.3, 1],
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    program.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    [
                      program.start?.year.toString(),
                      program.ongoing
                          ? 'present'
                          : program.end?.year.toString(),
                    ].whereType<String>().join('–'),
                    style: const TextStyle(
                      color: Color(0xFFC9D2DF),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProgramPage extends StatelessWidget {
  const ProgramPage({super.key, required this.program});

  final Program program;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 220,
            title: Text(program.name),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  LaunchPoster(
                    imageUrl: program.imageUrl,
                    label: program.name,
                    height: double.infinity,
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x99000000),
                          Color(0x00000000),
                          Color(0xFF0A0D12),
                        ],
                        stops: [0, 0.4, 1],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: ContentWidth(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      children: [
                        if (program.type != null)
                          TagChip(
                            label: program.type!,
                            icon: Icons.flag_outlined,
                          ),
                        TagChip(
                          label: program.ongoing ? 'Ongoing' : 'Completed',
                          icon: program.ongoing
                              ? Icons.play_arrow
                              : Icons.check,
                          color: program.ongoing
                              ? const Color(0xFF4ED69A)
                              : launchInkMuted,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(program.name, style: text.headlineMedium),
                    Text(
                      [
                        if (program.start != null)
                          'Began ${DateFormat.yMMMM().format(program.start!.toLocal())}',
                        if (program.end != null && !program.ongoing)
                          'ended ${DateFormat.yMMMM().format(program.end!.toLocal())}',
                      ].join(', '),
                      style: const TextStyle(color: launchInkMuted),
                    ),
                    if (program.description != null) ...[
                      const SectionHeader(title: 'About'),
                      Text(
                        program.description!,
                        style: text.bodyLarge?.copyWith(fontSize: 15.5),
                      ),
                    ],
                    if (program.agencies.isNotEmpty) ...[
                      const SectionHeader(title: 'Agencies'),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final a in program.agencies)
                            Chip(
                              label: Text(
                                a,
                                style: const TextStyle(fontSize: 12.5),
                              ),
                            ),
                        ],
                      ),
                    ],
                    if (program.patches.isNotEmpty) ...[
                      const SectionHeader(title: 'Mission patches'),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final p in program.patches)
                            SizedBox(
                              width: 72,
                              height: 72,
                              child: Image.network(
                                // Fall back to an <img> element on the web when a host blocks CORS.
                                webHtmlElementStrategy:
                                    WebHtmlElementStrategy.fallback,
                                p,
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) =>
                                    const SizedBox.shrink(),
                              ),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (program.infoUrl != null)
                          OutlinedButton.icon(
                            onPressed: () => launchUrl(
                              Uri.parse(program.infoUrl!),
                              mode: LaunchMode.externalApplication,
                            ),
                            icon: const Icon(Icons.open_in_new, size: 16),
                            label: const Text('Official site'),
                          ),
                        if (program.wikiUrl != null)
                          OutlinedButton.icon(
                            onPressed: () => launchUrl(
                              Uri.parse(program.wikiUrl!),
                              mode: LaunchMode.externalApplication,
                            ),
                            icon: const Icon(Icons.open_in_new, size: 16),
                            label: const Text('Wikipedia'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
