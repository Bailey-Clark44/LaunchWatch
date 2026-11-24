import 'package:material_ui/material_ui.dart';

import 'catalog.dart';
import 'catalog_profile_pages.dart';
import 'launch_repository.dart';
import 'theme.dart';
import 'widgets.dart';

class OrganisationsPage extends StatefulWidget {
  const OrganisationsPage({super.key, required this.repository});

  final LaunchRepository repository;

  @override
  State<OrganisationsPage> createState() => _OrganisationsPageState();
}

class _OrganisationsPageState extends State<OrganisationsPage> {
  late final _stream = widget.repository.everything();
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 2),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Semantics(header: true, child: Text('Providers', style: Theme.of(context).textTheme.headlineMedium)),
              const SizedBox(height: 2),
              const Text('The agencies and companies flying them', style: TextStyle(color: launchInkMuted, fontSize: 13)),
            ]),
          ),
          SearchField(hint: 'Search providers or rockets', padding: const EdgeInsets.fromLTRB(16, 12, 16, 8), onChanged: (v) => setState(() => _query = v.trim().toLowerCase())),
          Expanded(
            child: StreamBuilder<List<LaunchRecord>>(
              stream: _stream,
              builder: (context, snapshot) {
                if (snapshot.hasError) return const EmptyState(icon: Icons.cloud_off, title: 'Could not load providers');
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final groups = groupOrganisations(snapshot.data!).where((g) {
                  final vehicles = g.vehicles.map((v) => v.name).join(' ');
                  return '${g.name} $vehicles'.toLowerCase().contains(_query);
                }).toList();
                if (groups.isEmpty) return const EmptyState(icon: Icons.search_off, title: 'No providers match that search');
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: groups.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final g = groups[index];
                    final vehicles = g.vehicles;
                    return Panel(
                      padding: const EdgeInsets.all(12),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => OrganisationProfilePage(group: g, repository: widget.repository))),
                      child: Row(children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(color: launchSurfaceRaised, borderRadius: BorderRadius.circular(10), border: Border.all(color: launchLine)),
                          child: Center(child: Text(_initials(g.name), style: const TextStyle(color: launchAccent, fontSize: 15, fontWeight: FontWeight.w700))),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(g.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(
                              [
                                vehicles.map((v) => v.name).take(3).join(', '),
                              ].where((s) => s.isNotEmpty).join(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: launchInkMuted, fontSize: 12.5),
                            ),
                          ]),
                        ),
                        const SizedBox(width: 8),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text('${g.upcoming}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, fontFeatures: tabularFigures)),
                          const Text('upcoming', style: TextStyle(color: launchInkFaint, fontSize: 11)),
                        ]),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right, color: launchInkMuted),
                      ]),
                    );
                  },
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

String _initials(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty && w[0].toUpperCase() != w[0].toLowerCase()).toList();
  if (words.isEmpty) return '?';
  return words.take(2).map((w) => w[0].toUpperCase()).join();
}
