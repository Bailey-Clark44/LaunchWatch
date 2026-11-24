import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'install_prompt.dart';

/// "Install LaunchWatch" on the web. Hidden on phones, in browsers that cannot
/// install, and once installed.
class InstallTile extends StatefulWidget {
  const InstallTile({super.key, required this.builder});

  /// Wraps the tile, for example in a section with a header. Not called when
  /// there is nothing to show.
  final Widget Function(BuildContext context, Widget tile) builder;

  @override
  State<InstallTile> createState() => _InstallTileState();
}

class _InstallTileState extends State<InstallTile> {
  StreamSubscription<void>? _sub;
  InstallMode _mode = InstallSupport.mode;

  @override
  void initState() {
    super.initState();
    _sub = InstallSupport.changes.listen((_) => setState(() => _mode = InstallSupport.mode));
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _install() async {
    if (_mode == InstallMode.iosShare) {
      await showModalBottomSheet<void>(context: context, showDragHandle: true, builder: (_) => const _IosSteps());
      return;
    }
    final outcome = await InstallSupport.ask();
    if (!mounted) return;
    setState(() => _mode = InstallSupport.mode);
    if (outcome == 'accepted') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('LaunchWatch is installed. Open it from your home screen or apps list.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_mode == InstallMode.none || _mode == InstallMode.installed) return const SizedBox.shrink();
    final tile = ListTile(
      leading: const Icon(Icons.install_mobile_outlined),
      title: const Text('Install LaunchWatch'),
      subtitle: const Text('Opens like an app, in its own window, and works offline'),
      trailing: const Icon(Icons.chevron_right),
      onTap: _install,
    );
    return widget.builder(context, tile);
  }
}

class _IosSteps extends StatelessWidget {
  const _IosSteps();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget step(int n, IconData icon, String words) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            CircleAvatar(radius: 14, child: Text('$n', style: text.labelLarge)),
            const SizedBox(width: 14),
            Icon(icon, size: 22),
            const SizedBox(width: 10),
            Expanded(child: Text(words, style: text.bodyLarge)),
          ]),
        );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Add to your Home Screen', style: text.titleLarge),
          const SizedBox(height: 6),
          Text('LaunchWatch then opens full screen, like any other app.', style: text.bodyMedium),
          const SizedBox(height: 12),
          step(1, Icons.ios_share, 'Tap Share in Safari\'s toolbar'),
          step(2, Icons.add_box_outlined, 'Choose Add to Home Screen'),
          step(3, Icons.check, 'Tap Add'),
        ]),
      ),
    );
  }
}
