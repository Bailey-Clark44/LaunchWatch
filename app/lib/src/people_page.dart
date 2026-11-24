import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_state.dart';
import 'space_data.dart';
import 'theme.dart';
import 'widgets.dart';

/// Who is off the planet right now, grouped by where they are.
class PeopleInSpacePage extends StatelessWidget {
  const PeopleInSpacePage({super.key});

  @override
  Widget build(BuildContext context) {
    final space = LaunchWatchScope.spaceOf(context);
    return Scaffold(
      appBar: AppBar(title: const Text('In space right now')),
      body: StreamBuilder<List<Astronaut>>(
        stream: space.peopleInSpace(),
        builder: (context, people) => StreamBuilder<List<Expedition>>(
          stream: space.expeditions(),
          builder: (context, expeditions) {
            final all = people.data;
            if (all == null) return const Center(child: CircularProgressIndicator());
            if (all.isEmpty) return const EmptyState(icon: Icons.person_search_outlined, title: 'Crew data is on its way', body: 'It fills in shortly after the first refresh.');
            final groups = groupByLocation(all, (expeditions.data ?? const <Expedition>[]).where((e) => e.active).toList());
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                ContentWidth(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    _Headline(count: all.length),
                    for (final g in groups) ...[
                      SectionHeader(
                        title: g.place,
                        trailing: g.stationId == null ? null : TextButton(onPressed: () => openStation(context, g.stationId!), child: const Text('Station')),
                      ),
                      if (g.expedition != null)
                        Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(g.expedition!, style: const TextStyle(color: launchInkMuted, fontSize: 13))),
                      for (final p in g.people) Padding(padding: const EdgeInsets.only(bottom: 8), child: AstronautRow(person: p, role: g.roles[p.id])),
                    ],
                  ]),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final days = continuousPresence().inDays;
    return Panel(
      color: launchSelection,
      child: Row(children: [
        Text('$count', style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w800, letterSpacing: -1.5, fontFeatures: tabularFigures)),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            '${count == 1 ? 'person is' : 'people are'} in space right now. Humans have lived in orbit without a break for ${NumberFormat.decimalPattern().format(days)} days.',
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
        ),
      ]),
    );
  }
}

class PlaceGroup {
  PlaceGroup(this.place, {this.stationId, this.expedition});
  final String place;
  final String? stationId;
  final String? expedition;
  final List<Astronaut> people = [];
  final Map<String, String?> roles = {};
}

/// Puts each person with the station their expedition is on; everyone else
/// (free-flying crews) under "Other spacecraft".
List<PlaceGroup> groupByLocation(List<Astronaut> people, List<Expedition> active) {
  final groups = <String, PlaceGroup>{};
  final placed = <String>{};
  for (final e in active) {
    final key = e.stationName ?? e.name;
    final g = groups.putIfAbsent(key, () => PlaceGroup(key, stationId: e.stationId, expedition: e.name));
    for (final c in e.crew) {
      final person = people.where((p) => p.id == c.id).firstOrNull;
      if (person == null || placed.contains(person.id)) continue;
      g.people.add(person);
      g.roles[person.id] = c.role;
      placed.add(person.id);
    }
  }
  final rest = people.where((p) => !placed.contains(p.id)).toList();
  if (rest.isNotEmpty) {
    final g = groups.putIfAbsent('Other spacecraft', () => PlaceGroup('Other spacecraft'));
    g.people.addAll(rest);
  }
  return groups.values.where((g) => g.people.isNotEmpty).toList()..sort((a, b) => b.people.length.compareTo(a.people.length));
}

class AstronautRow extends StatelessWidget {
  const AstronautRow({super.key, required this.person, this.role});

  final Astronaut person;
  final String? role;

  @override
  Widget build(BuildContext context) {
    final days = person.timeInSpace;
    return Panel(
      padding: const EdgeInsets.all(10),
      onTap: () => openAstronaut(context, person.id),
      child: Row(children: [
        Avatar(name: person.name, imageUrl: person.thumbUrl, size: 48),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${person.flag == null ? '' : '${person.flag} '}${person.name}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 2),
            Text(
              [role, person.agencyAbbrev ?? person.agencyName, if (days != null) '${formatSpan(days)} in space'].whereType<String>().join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: launchInkMuted, fontSize: 12.5),
            ),
          ]),
        ),
        const Icon(Icons.chevron_right, color: launchInkMuted),
      ]),
    );
  }
}

class AstronautPage extends StatelessWidget {
  const AstronautPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Astronaut?>(
      stream: LaunchWatchScope.spaceOf(context).astronaut(id),
      builder: (context, snap) {
        final a = snap.data;
        if (snap.connectionState == ConnectionState.waiting && a == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        if (a == null) return Scaffold(appBar: AppBar(), body: const EmptyState(icon: Icons.person_off_outlined, title: 'Profile not available'));
        final text = Theme.of(context).textTheme;
        final born = a.dateOfBirth == null ? null : DateTime.tryParse(a.dateOfBirth!);
        return Scaffold(
          appBar: AppBar(title: const Text('Astronaut')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              ContentWidth(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    Avatar(name: a.name, imageUrl: a.imageUrl ?? a.thumbUrl, size: 96, ring: a.inSpace ? launchAccent : launchLineStrong),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (a.inSpace) ...[
                          const LiveBadge(label: 'IN SPACE NOW'),
                          const SizedBox(height: 8),
                        ],
                        Text(a.name, style: text.headlineSmall),
                        const SizedBox(height: 4),
                        Text([if (a.flag != null) '${a.flag} ${a.nationality ?? ''}'.trim() else a.nationality, a.agencyAbbrev ?? a.agencyName].whereType<String>().join(' · '), style: const TextStyle(color: launchInkMuted, fontSize: 13.5)),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  Row(children: [
                    _Stat(value: a.timeInSpace == null ? '—' : formatSpan(a.timeInSpace!), label: 'In space'),
                    const SizedBox(width: 8),
                    _Stat(value: '${a.flightsCount ?? 0}', label: (a.flightsCount ?? 0) == 1 ? 'Flight' : 'Flights'),
                    const SizedBox(width: 8),
                    _Stat(value: '${a.spacewalksCount ?? 0}', label: 'Spacewalks'),
                  ]),
                  if (a.evaTime != null && a.evaTime! > Duration.zero) ...[
                    const SizedBox(height: 8),
                    Text('${formatSpan(a.evaTime!)} spent spacewalking', style: const TextStyle(color: launchInkMuted, fontSize: 13)),
                  ],
                  if (a.bio != null) ...[
                    const SectionHeader(title: 'Biography'),
                    Text(a.bio!, style: text.bodyLarge?.copyWith(fontSize: 15.5)),
                  ],
                  const SectionHeader(title: 'Details'),
                  Panel(
                    padding: EdgeInsets.zero,
                    child: Column(children: [
                      for (final (label, value) in [
                        ('Status', a.status),
                        ('Role', a.type),
                        ('Agency', a.agencyName),
                        ('Born', born == null ? null : '${DateFormat.yMMMMd().format(born)}${a.age != null ? ' (age ${a.age})' : ''}'),
                        ('First flight', a.firstFlight == null ? null : DateFormat.yMMMd().format(a.firstFlight!.toLocal())),
                        ('Latest flight', a.lastFlight == null ? null : DateFormat.yMMMd().format(a.lastFlight!.toLocal())),
                        ('Landings', a.landingsCount?.toString()),
                      ])
                        if (value != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              SizedBox(width: 110, child: Text(label, style: const TextStyle(color: launchInkMuted, fontSize: 13.5))),
                              Expanded(child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
                            ]),
                          ),
                    ]),
                  ),
                  if (a.wiki != null) ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(onPressed: () => launchUrl(Uri.parse(a.wiki!), mode: LaunchMode.externalApplication), icon: const Icon(Icons.open_in_new, size: 16), label: const Text('Read more on Wikipedia')),
                  ],
                ]),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Panel(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, fontFeatures: tabularFigures))),
          Text(label, style: const TextStyle(color: launchInkMuted, fontSize: 12)),
        ]),
      ),
    );
  }
}
