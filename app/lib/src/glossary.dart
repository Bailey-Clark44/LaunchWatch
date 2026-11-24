import 'package:material_ui/material_ui.dart';

import 'theme.dart';

class GlossaryEntry {
  const GlossaryEntry(this.term, this.definition, {this.aliases = const []});
  final String term;
  final String definition;
  final List<String> aliases;
}

const glossary = <GlossaryEntry>[
  GlossaryEntry('NET', 'No Earlier Than. The earliest a launch could happen. Launches often move later, rarely earlier.'),
  GlossaryEntry('Launch window', 'The span of time in which a launch can happen on a given day. Some are a single instant; others last hours.'),
  GlossaryEntry('T-minus', 'The countdown to liftoff. T−00:10:00 means ten minutes to go; T+ counts time since liftoff.'),
  GlossaryEntry('Scrub', 'A launch attempt called off for the day, often for weather or a technical issue. A new attempt is usually set soon after.'),
  GlossaryEntry('Hold', 'A pause in the countdown. It can be planned, or called to look at an issue. A hold is not a cancellation.'),
  GlossaryEntry('Low Earth Orbit', 'An orbit roughly 160–2,000 km up. The International Space Station and most satellite constellations fly here.', aliases: ['LEO']),
  GlossaryEntry('Geostationary Transfer Orbit', 'A stretched orbit used to carry a satellite out to geostationary altitude, about 35,786 km up.', aliases: ['GTO']),
  GlossaryEntry('Geostationary Orbit', 'An orbit 35,786 km above the equator where a satellite keeps pace with Earth, staying over one spot.', aliases: ['GEO', 'Geosynchronous Orbit', 'GSO']),
  GlossaryEntry('Sun-Synchronous Orbit', 'A near-polar orbit that passes over each place at the same local time every day. Popular for Earth imaging.', aliases: ['SSO']),
  GlossaryEntry('Polar Orbit', 'An orbit that passes over or near both poles, so a satellite eventually sees the whole planet.', aliases: ['PO']),
  GlossaryEntry('Medium Earth Orbit', 'Orbits between low and geostationary altitude. Navigation satellites such as GPS and Galileo fly here.', aliases: ['MEO']),
  GlossaryEntry('Lunar Orbit', 'An orbit around the Moon.', aliases: ['Lunar flyby', 'TLI', 'Trans-Lunar Injection']),
  GlossaryEntry('Heliocentric Orbit', 'An orbit around the Sun, used by deep-space missions.', aliases: ['Heliocentric N/A']),
  GlossaryEntry('Suborbital', 'A flight that goes to space but falls back without completing an orbit. Usually minutes long.', aliases: ['Suborbital flight']),
  GlossaryEntry('Block 5', 'The final, most reusable version of SpaceX\'s Falcon 9 first stage, flying since 2018.'),
  GlossaryEntry('Booster', 'The first stage of a rocket, which provides the initial thrust. Some, like Falcon 9\'s, land to fly again.'),
  GlossaryEntry('Payload', 'What the rocket carries: satellites, a spacecraft, cargo, or crew.'),
  GlossaryEntry('Rideshare', 'One launch carrying many small satellites from different customers.'),
  GlossaryEntry('Static fire', 'A test that fires a rocket\'s engines while it is held down on the pad.'),
  GlossaryEntry('Max-Q', 'The moment of maximum aerodynamic pressure on the rocket during ascent, about a minute after liftoff.'),
  GlossaryEntry('Human Exploration', 'A mission carrying people to space.'),
  GlossaryEntry('Resupply', 'A cargo mission to a space station.'),
];

GlossaryEntry? lookupTerm(String? text) {
  if (text == null) return null;
  final t = text.trim().toLowerCase();
  for (final e in glossary) {
    if (e.term.toLowerCase() == t || e.aliases.any((a) => a.toLowerCase() == t)) return e;
  }
  return null;
}

Future<void> showGlossary(BuildContext context, GlossaryEntry entry) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(entry.term, style: Theme.of(context).textTheme.titleLarge),
          if (entry.aliases.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(entry.aliases.first, style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 10),
          Text(entry.definition, style: Theme.of(context).textTheme.bodyLarge),
        ]),
      ),
    ),
  );
}

/// Text with a dotted underline that explains itself when tapped.
class GlossaryText extends StatelessWidget {
  const GlossaryText(this.text, {super.key, this.style, this.entry});

  final String text;
  final TextStyle? style;
  final GlossaryEntry? entry;

  @override
  Widget build(BuildContext context) {
    final found = entry ?? lookupTerm(text);
    final base = style ?? DefaultTextStyle.of(context).style;
    if (found == null) return Text(text, style: base);
    return Semantics(
      button: true,
      hint: 'Explain ${found.term}',
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () => showGlossary(context, found),
        child: Text(
          text,
          style: base.copyWith(decoration: TextDecoration.underline, decorationStyle: TextDecorationStyle.dotted, decorationColor: launchInkMuted),
        ),
      ),
    );
  }
}

class GlossaryPage extends StatelessWidget {
  const GlossaryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final sorted = [...glossary]..sort((a, b) => a.term.compareTo(b.term));
    return Scaffold(
      appBar: AppBar(title: const Text('Glossary')),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        itemCount: sorted.length,
        separatorBuilder: (_, _) => const Divider(height: 28),
        itemBuilder: (context, i) {
          final e = sorted[i];
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.aliases.isEmpty ? e.term : '${e.term} (${e.aliases.first})', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(e.definition, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: launchInkMuted)),
          ]);
        },
      ),
    );
  }
}
