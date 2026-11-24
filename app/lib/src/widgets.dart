import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'format_net.dart';
import 'launch_repository.dart';
import 'theme.dart';

/// Status in words with a coloured dot. Colour supports the word, never replaces it.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.rawName, this.dense = false});

  final String rawName;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tone = statusTone(rawName);
    return Semantics(
      label: 'Status: ${tone.label}',
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: dense ? 7 : 9,
          vertical: dense ? 3 : 4,
        ),
        decoration: BoxDecoration(
          color: tone.color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: tone.color.withValues(alpha: 0.28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: tone.color,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: dense ? 5 : 6),
            Text(
              tone.label,
              style: TextStyle(
                color: tone.color,
                fontSize: dense ? 11.5 : 12.5,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small tag used for Crew, Suborbital, Webcast and similar facts.
class TagChip extends StatelessWidget {
  const TagChip({
    super.key,
    required this.label,
    required this.icon,
    this.color = launchInkMuted,
  });

  const TagChip.crew({super.key})
    : label = 'Crew',
      icon = Icons.person_outline,
      color = launchCrew;

  const TagChip.suborbital({super.key})
    : label = 'Suborbital',
      icon = Icons.north_east,
      color = launchInkMuted;

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A pulsing LIVE marker for launches in flight.
class LiveBadge extends StatefulWidget {
  const LiveBadge({super.key, this.label = 'LIVE'});

  final String label;

  @override
  State<LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<LiveBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Live now',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: launchLive,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeTransition(
              opacity: Tween(begin: 0.35, end: 1.0).animate(_pulse),
              child: Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              widget.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ticking T-minus clock. Renders nothing unless the plan's countdown rules allow it.
class Countdown extends StatefulWidget {
  const Countdown({super.key, required this.launch, this.style});

  final LaunchRecord launch;
  final TextStyle? style;

  @override
  State<Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<Countdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final launch = widget.launch;
    if (!countdownAllowed(launch.net, launch.precisionAbbrev, launch.statusId)) {
      return const SizedBox.shrink();
    }
    final until = launch.net!.difference(DateTime.now());
    final text = formatCountdown(until);
    return Semantics(
      liveRegion: false,
      label: until.isNegative
          ? 'Launched ${until.abs().inMinutes} minutes ago'
          : 'Launches in ${until.inHours} hours ${until.inMinutes % 60} minutes',
      excludeSemantics: true,
      child: Text(
        text,
        style:
            (widget.style ??
                    const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: launchInk,
                    ))
                .copyWith(fontFeatures: tabularFigures),
      ),
    );
  }
}

/// A bordered surface. The one card style in the app.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color = launchSurface,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: const BorderSide(color: launchLine),
    );
    return Material(
      color: color,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? Padding(padding: padding, child: child)
          : InkWell(
              onTap: onTap,
              child: Padding(padding: padding, child: child),
            ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(0, 28, 0, 10),
  });

  final String title;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// A full-width notice strip: stale data, offline, verification needed.
class NoticeStrip extends StatelessWidget {
  const NoticeStrip({
    super.key,
    required this.icon,
    required this.text,
    this.color = const Color(0xFFF2B84B),
    this.action,
  });

  final IconData icon;
  final String text;
  final Color color;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13.5,
                color: launchInk,
                height: 1.35,
              ),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.padding = const EdgeInsets.fromLTRB(16, 4, 16, 8),
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: TextField(
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 15, color: launchInk),
        decoration: InputDecoration(
          hintText: hint,
          isDense: true,
          prefixIcon: const Icon(Icons.search, color: launchInkMuted, size: 20),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
        ),
      ),
    );
  }
}

class LaunchPoster extends StatelessWidget {
  const LaunchPoster({
    super.key,
    required this.imageUrl,
    required this.label,
    this.height = 180,
  });

  final String? imageUrl;
  final String label;
  final double height;

  @override
  Widget build(BuildContext context) {
    final fallback = DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF121822), Color(0xFF1D2838)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.rocket_launch_outlined,
          color: launchInkFaint,
          size: height > 100 ? 40 : 22,
        ),
      ),
    );
    final picture = imageUrl == null
        ? fallback
        : Image.network(
            // Fall back to an <img> element on the web when a host blocks CORS.
            webHtmlElementStrategy: WebHtmlElementStrategy.fallback,

            imageUrl!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            semanticLabel: label,
            errorBuilder: (context, error, stackTrace) => fallback,
            // Show the placeholder until the first frame arrives, then the photo.
            frameBuilder: (context, child, frame, sync) =>
                sync || frame != null ? child : fallback,
          );
    if (height == double.infinity) return SizedBox.expand(child: picture);
    return SizedBox(height: height, width: double.infinity, child: picture);
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: launchInkFaint),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (body != null) ...[
              const SizedBox(height: 6),
              Text(
                body!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: launchInkMuted),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

/// Keeps reading width comfortable on large screens.
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child, this.maxWidth = 760});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// A ticking T-minus for any dated thing, under the same rules as launches:
/// an exact time inside 48 hours, or nothing at all.
class TimeUntil extends StatefulWidget {
  const TimeUntil({
    super.key,
    required this.date,
    required this.precision,
    this.style,
  });

  final DateTime? date;
  final String? precision;
  final TextStyle? style;

  @override
  State<TimeUntil> createState() => _TimeUntilState();
}

class _TimeUntilState extends State<TimeUntil> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!countdownAllowed(widget.date, widget.precision, 1)) {
      return const SizedBox.shrink();
    }
    final until = widget.date!.difference(DateTime.now());
    return Text(
      formatCountdown(until),
      style:
          (widget.style ??
                  const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: launchInk,
                  ))
              .copyWith(fontFeatures: tabularFigures),
    );
  }
}

/// A round portrait with initials while it loads or when there is none.
class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 44,
    this.ring,
  });

  final String name;
  final String? imageUrl;
  final double size;
  final Color? ring;

  @override
  Widget build(BuildContext context) {
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    final fallback = Container(
      color: launchSelection,
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: launchAccent,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.34,
        ),
      ),
    );
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(ring == null ? 0 : 2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ring ?? Colors.transparent,
      ),
      child: ClipOval(
        child: imageUrl == null
            ? fallback
            : Image.network(
                imageUrl!,
                // Fall back to an <img> element on the web when a host blocks CORS.
                webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                semanticLabel: name,
                // Initials until the portrait arrives, and if it never does.
                frameBuilder: (_, child, frame, sync) =>
                    sync || frame != null ? child : fallback,
                errorBuilder: (_, _, _) => fallback,
              ),
      ),
    );
  }
}

/// Horizontal scrolling row of cards with a titled header and optional "See all".
class Shelf extends StatelessWidget {
  const Shelf({
    super.key,
    required this.title,
    required this.children,
    this.onSeeAll,
    this.height = 190,
    this.itemWidth = 240,
  });

  final String title;
  final List<Widget> children;
  final VoidCallback? onSeeAll;
  final double height;
  final double itemWidth;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SectionHeader(
            title: title,
            trailing: onSeeAll == null
                ? null
                : TextButton(onPressed: onSeeAll, child: const Text('See all')),
          ),
        ),
        SizedBox(
          height: height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: children.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) =>
                SizedBox(width: itemWidth, child: children[i]),
          ),
        ),
      ],
    );
  }
}

String plural(int count, String one, [String? many]) =>
    '$count ${count == 1 ? one : (many ?? '${one}s')}';
