import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_state.dart';
import 'format_net.dart';
import 'space_data.dart';
import 'theme.dart';
import 'widgets.dart';

Future<void> openArticle(Article a) => launchUrl(Uri.parse(a.url), mode: LaunchMode.externalApplication);

class NewsPage extends StatefulWidget {
  const NewsPage({super.key});

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  Stream<List<Article>>? _stream;
  String? _site;
  String _query = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _stream ??= LaunchWatchScope.spaceOf(context).news();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<List<Article>>(
          stream: _stream,
          builder: (context, snap) {
            final all = snap.data;
            final sites = <String, int>{};
            for (final a in all ?? const <Article>[]) {
              if (a.site != null) sites[a.site!] = (sites[a.site!] ?? 0) + 1;
            }
            final topSites = (sites.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(8).map((e) => e.key).toList();
            final articles = (all ?? const <Article>[])
                .where((a) => _site == null || a.site == _site)
                .where((a) => _query.isEmpty || '${a.title} ${a.summary ?? ''}'.toLowerCase().contains(_query))
                .toList();
            return CustomScrollView(slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Semantics(header: true, child: Text('News', style: Theme.of(context).textTheme.headlineMedium)),
                    const SizedBox(height: 2),
                    const Text('Spaceflight headlines from across the web', style: TextStyle(color: launchInkMuted, fontSize: 13)),
                    const SizedBox(height: 12),
                    SearchField(hint: 'Search headlines', padding: EdgeInsets.zero, onChanged: (v) => setState(() => _query = v.trim().toLowerCase())),
                  ]),
                ),
              ),
              if (topSites.isNotEmpty)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 54,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                      children: [
                        Pill(label: 'All sources', selected: _site == null, onTap: () => setState(() => _site = null)),
                        for (final s in topSites) Pill(label: s, selected: _site == s, onTap: () => setState(() => _site = s)),
                      ],
                    ),
                  ),
                ),
              if (snap.hasError)
                const SliverFillRemaining(hasScrollBody: false, child: EmptyState(icon: Icons.cloud_off, title: "Couldn't load the news"))
              else if (all == null)
                const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator()))
              else if (articles.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(icon: Icons.newspaper, title: all.isEmpty ? 'The newsroom is warming up' : 'No headlines match', body: all.isEmpty ? 'Headlines arrive within half an hour of the first refresh.' : null),
                )
              else ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  sliver: SliverToBoxAdapter(child: ArticleHero(article: articles.first)),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  sliver: SliverList.separated(
                    itemCount: articles.length - 1,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) => ArticleRow(article: articles[i + 1]),
                  ),
                ),
              ],
            ]);
          },
        ),
      ),
    );
  }
}

/// A selectable rounded filter, shared by News, Events, and Explore.
class Pill extends StatelessWidget {
  const Pill({super.key, required this.label, required this.selected, required this.onTap, this.icon});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
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
            onTap: onTap,
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
}

String _byline(Article a) => [a.site, if (a.publishedAt != null) relativeAge(a.publishedAt!)].whereType<String>().join(' · ');

class ArticleHero extends StatelessWidget {
  const ArticleHero({super.key, required this.article});

  final Article article;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: EdgeInsets.zero,
      onTap: () => openArticle(article),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (article.imageUrl != null) SizedBox(height: 190, child: LaunchPoster(imageUrl: article.imageUrl, label: article.title, height: 190)),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_byline(article).toUpperCase(), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: launchAccent)),
            const SizedBox(height: 6),
            Text(article.title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: -0.3, height: 1.25)),
            if (article.summary != null) ...[
              const SizedBox(height: 8),
              Text(article.summary!, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: launchInkMuted, fontSize: 14, height: 1.45)),
            ],
            _Linked(article: article),
          ]),
        ),
      ]),
    );
  }
}

class ArticleRow extends StatelessWidget {
  const ArticleRow({super.key, required this.article});

  final Article article;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.all(12),
      onTap: () => openArticle(article),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_byline(article), style: const TextStyle(color: launchInkFaint, fontSize: 11.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(article.title, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, height: 1.3)),
            _Linked(article: article),
          ]),
        ),
        if (article.imageUrl != null) ...[
          const SizedBox(width: 12),
          ClipRRect(borderRadius: BorderRadius.circular(10), child: SizedBox(width: 84, height: 84, child: LaunchPoster(imageUrl: article.imageUrl, label: article.title, height: 84))),
        ],
      ]),
    );
  }
}

/// "About this launch" chips that jump from a headline to the app's own pages.
class _Linked extends StatelessWidget {
  const _Linked({required this.article});

  final Article article;

  @override
  Widget build(BuildContext context) {
    if (article.launchIds.isEmpty && article.eventIds.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(spacing: 6, runSpacing: 6, children: [
        for (final id in article.launchIds.take(2))
          ActionChip(visualDensity: VisualDensity.compact, avatar: const Icon(Icons.rocket_launch_outlined, size: 14), label: const Text('Launch', style: TextStyle(fontSize: 12)), onPressed: () => openLaunch(context, id)),
        for (final id in article.eventIds.take(2))
          ActionChip(visualDensity: VisualDensity.compact, avatar: const Icon(Icons.event_outlined, size: 14), label: const Text('Event', style: TextStyle(fontSize: 12)), onPressed: () => openEvent(context, id)),
      ]),
    );
  }
}

/// Headlines tagged with a launch or event, for the bottom of their pages.
class RelatedNews extends StatelessWidget {
  const RelatedNews({super.key, this.launchId, this.eventId});

  final String? launchId;
  final String? eventId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Article>>(
      stream: LaunchWatchScope.spaceOf(context).newsFor(launchId: launchId, eventId: eventId),
      builder: (context, snap) {
        final list = snap.data ?? const <Article>[];
        if (list.isEmpty) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SectionHeader(title: 'In the news'),
          for (final a in list.take(5))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Panel(
                padding: const EdgeInsets.all(12),
                onTap: () => openArticle(a),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(a.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 3),
                      Text([a.site, if (a.publishedAt != null) DateFormat.MMMd().format(a.publishedAt!.toLocal())].whereType<String>().join(' · '), style: const TextStyle(color: launchInkMuted, fontSize: 12)),
                    ]),
                  ),
                  const Icon(Icons.open_in_new, size: 16, color: launchInkMuted),
                ]),
              ),
            ),
        ]);
      },
    );
  }
}
