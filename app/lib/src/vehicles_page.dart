import 'package:material_ui/material_ui.dart';

import 'catalog.dart';
import 'catalog_profile_pages.dart';
import 'launch_repository.dart';
import 'theme.dart';
import 'widgets.dart';

class VehiclesPage extends StatefulWidget {
  const VehiclesPage({super.key, required this.repository});

  final LaunchRepository repository;

  @override
  State<VehiclesPage> createState() => _VehiclesPageState();
}

class _VehiclesPageState extends State<VehiclesPage> {
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
              Semantics(header: true, child: Text('Vehicles', style: Theme.of(context).textTheme.headlineMedium)),
              const SizedBox(height: 2),
              const Text('Every rocket in the current schedule', style: TextStyle(color: launchInkMuted, fontSize: 13)),
            ]),
          ),
          SearchField(hint: 'Search rockets or operators', padding: const EdgeInsets.fromLTRB(16, 12, 16, 8), onChanged: (v) => setState(() => _query = v.trim().toLowerCase())),
          Expanded(
            child: StreamBuilder<List<LaunchRecord>>(
              stream: _stream,
              builder: (context, snapshot) {
                if (snapshot.hasError) return const EmptyState(icon: Icons.cloud_off, title: 'Could not load vehicles');
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final vehicles = groupVehicles(snapshot.data!).where((v) {
                  final operators = v.operators.map((o) => o.name).join(' ');
                  return '${v.name} $operators'.toLowerCase().contains(_query);
                }).toList();
                if (vehicles.isEmpty) return const EmptyState(icon: Icons.search_off, title: 'No vehicles match that search');
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 240, mainAxisSpacing: 12, crossAxisSpacing: 12, mainAxisExtent: 232),
                  itemCount: vehicles.length,
                  itemBuilder: (context, index) {
                    final v = vehicles[index];
                    return Panel(
                      padding: EdgeInsets.zero,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => VehicleProfilePage(group: v, repository: widget.repository))),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        SizedBox(height: 140, child: LaunchPoster(imageUrl: v.imageUrl, label: v.name, height: 140)),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(v.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(v.operators.map((o) => o.name).take(2).join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: launchInkMuted, fontSize: 12.5)),
                            const SizedBox(height: 8),
                            Text(v.upcoming > 0 ? '${v.upcoming} upcoming' : '${v.recent} recent', style: const TextStyle(color: launchAccent, fontSize: 12, fontWeight: FontWeight.w600)),
                          ]),
                        ),
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
