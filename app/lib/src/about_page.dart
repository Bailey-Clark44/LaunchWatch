import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'glossary.dart';
import 'theme.dart';
import 'widgets.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          ContentWidth(
            maxWidth: 640,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('LaunchWatch', style: text.headlineSmall),
              const SizedBox(height: 8),
              Text('What is launching, when, and what changed, in your own timezone. Dates are shown only as precisely as they have been announced.', style: text.bodyLarge),
              const SectionHeader(title: 'Data'),
              Text('Launch times, statuses, and updates come from Launch Library 2 by The Space Devs. LaunchWatch is not the launch provider; for the official word, follow the source links on each launch.', style: text.bodyMedium),
              TextButton.icon(
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4)),
                onPressed: () => launchUrl(Uri.parse('https://thespacedevs.com/llapi'), mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('thespacedevs.com'),
              ),
              const SectionHeader(title: 'Freshness'),
              Text('The catalog refreshes every 30 minutes, and every 10 minutes in the final day before a launch. If data is more than two hours old, the list says so.', style: text.bodyMedium),
              const SectionHeader(title: 'Visibility estimates'),
              Text('"Can I see it?" uses the distance and direction from your chosen city to the launch pad. It is a rule of thumb, not a forecast: weather, trajectory, and the time of day all matter.', style: text.bodyMedium),
              const SectionHeader(title: 'Privacy'),
              Text('Browsing needs no account. If you sign in, LaunchWatch stores your email, the launches you follow, your alert settings, and your launch log, and nothing else. Deleting your account in Account removes all of it.', style: text.bodyMedium),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const GlossaryPage())),
                icon: const Icon(Icons.menu_book_outlined, size: 18),
                label: const Text('Open the glossary'),
              ),
              const SizedBox(height: 24),
              const Text('Version 1.0.0', style: TextStyle(color: launchInkFaint, fontSize: 12)),
            ]),
          ),
        ],
      ),
    );
  }
}
