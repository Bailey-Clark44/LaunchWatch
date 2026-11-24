import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import 'account.dart';
import 'app_state.dart';
import 'theme.dart';
import 'widgets.dart';

/// A personal log of launches someone watched, shown as a wall of patches.
class LogPage extends StatelessWidget {
  const LogPage({super.key});

  @override
  Widget build(BuildContext context) {
    final account = LaunchWatchScope.of(context);
    final entries = account.watched.values.toList()..sort((a, b) => (b.net ?? DateTime(0)).compareTo(a.net ?? DateTime(0)));
    final thisYear = entries.where((e) => e.net?.year == DateTime.now().year).length;
    final vehicles = entries.map((e) => e.vehicle).whereType<String>().toSet().length;
    final providers = entries.map((e) => e.provider).whereType<String>().toSet().length;
    return Scaffold(
      appBar: AppBar(title: const Text('Launch log')),
      body: entries.isEmpty
          ? const EmptyState(
              icon: Icons.auto_awesome_outlined,
              title: 'Your log is empty',
              body: 'After a launch, open it and tap "I watched this". Each one earns a patch here.',
            )
          : CustomScrollView(slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(children: [
                    _Stat(value: '${entries.length}', label: 'Watched'),
                    const SizedBox(width: 8),
                    _Stat(value: '$thisYear', label: 'This year'),
                    const SizedBox(width: 8),
                    _Stat(value: '$vehicles', label: 'Rockets'),
                    const SizedBox(width: 8),
                    _Stat(value: '$providers', label: 'Providers'),
                  ]),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 140, mainAxisSpacing: 18, crossAxisSpacing: 12, childAspectRatio: 0.72),
                  itemCount: entries.length,
                  itemBuilder: (context, i) => _Patch(entry: entries[i]),
                ),
              ),
            ]),
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
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(children: [
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, fontFeatures: tabularFigures)),
          Text(label, style: const TextStyle(color: launchInkMuted, fontSize: 11.5)),
        ]),
      ),
    );
  }
}

class _Patch extends StatelessWidget {
  const _Patch({required this.entry});

  final WatchedLaunch entry;

  @override
  Widget build(BuildContext context) {
    final short = entry.name.contains('|') ? entry.name.split('|').last.trim() : entry.name;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => openLaunch(context, entry.launchId),
      child: Column(children: [
        AspectRatio(
          aspectRatio: 1,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(shape: BoxShape.circle, gradient: SweepGradient(colors: [launchAccent, launchCrew, Color(0xFF4ED69A), launchAccent])),
            child: ClipOval(child: LaunchPoster(imageUrl: entry.imageUrl, label: short, height: double.infinity)),
          ),
        ),
        const SizedBox(height: 8),
        Text(short, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.25)),
        if (entry.net != null) Text(DateFormat.yMMMd().format(entry.net!.toLocal()), style: const TextStyle(fontSize: 11, color: launchInkMuted)),
      ]),
    );
  }
}
