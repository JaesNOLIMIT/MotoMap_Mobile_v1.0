import 'package:flutter/material.dart';

import '../theme/motomap_colors.dart';
import '../widgets/app_ui.dart';
import 'route_detail_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  int selectedFilter = 0;
  final filters = const ['For you', 'Nearby', 'Scenic', 'Twisties'];

  void _openRoute(
    String title,
    String distance,
    String duration,
    String elevation,
    int variant,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RouteDetailScreen(
          title: title,
          distance: distance,
          duration: duration,
          elevation: elevation,
          variant: variant,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Discover', style: MotoMapText.headlineLg),
                  const SizedBox(height: 5),
                  Text(
                    'Find the road—and people—you haven’t met yet.',
                    style: MotoMapText.bodyMd.copyWith(
                      color: MotoMapColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    readOnly: true,
                    onTap: () => showSearch(
                      context: context,
                      delegate: _MotoMapSearchDelegate(),
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Routes, places, riders or clubs',
                      prefixIcon: Icon(Icons.search_rounded),
                      suffixIcon: Icon(Icons.tune_rounded),
                      contentPadding: EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: filters.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) => AppPill(
                        label: filters[index],
                        selected: selectedFilter == index,
                        onTap: () => setState(() => selectedFilter = index),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
            sliver: SliverToBoxAdapter(
              child: _DiscoverHero(
                onTap: () => _openRoute(
                  'Sierra Madre Loop',
                  '145 km',
                  '3h 15m',
                  '1,240 m',
                  1,
                ),
              ),
            ),
          ),
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
            sliver: SliverToBoxAdapter(
              child: SectionHeader(
                'Explore your way',
                subtitle: 'Routes are only one way to discover',
              ),
            ),
          ),
          SliverToBoxAdapter(child: _ExploreTypes()),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
            sliver: SliverToBoxAdapter(
              child: SectionHeader(
                'Trending routes',
                action: 'See all',
                onAction: () => showAppMessage(context, 'Showing all routes.'),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 258,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                children: [
                  _RouteDiscoveryCard(
                    title: 'Kaybiang Coastal Run',
                    location: 'Cavite · Batangas',
                    distance: '132 km',
                    time: '3h 40m',
                    rating: '4.9',
                    variant: 2,
                    onTap: () => _openRoute(
                      'Kaybiang Coastal Run',
                      '132 km',
                      '3h 40m',
                      '860 m',
                      2,
                    ),
                  ),
                  const SizedBox(width: 12),
                  _RouteDiscoveryCard(
                    title: 'Tanay Ridge Escape',
                    location: 'Rizal',
                    distance: '86 km',
                    time: '2h 20m',
                    rating: '4.8',
                    variant: 0,
                    onTap: () => _openRoute(
                      'Tanay Ridge Escape',
                      '86 km',
                      '2h 20m',
                      '1,040 m',
                      0,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(20, 24, 20, 10),
            sliver: SliverToBoxAdapter(
              child: SectionHeader(
                'Happening near you',
                subtitle: 'Meetups and group rides this weekend',
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList.list(
              children: const [
                _EventRow(
                  day: '03',
                  month: 'AUG',
                  title: 'Laguna Loop Social Ride',
                  detail: 'Calamba · 24 riders',
                  color: Color(0xFF4C6B61),
                ),
                SizedBox(height: 10),
                _EventRow(
                  day: '09',
                  month: 'AUG',
                  title: 'Moto Skills: Cornering 101',
                  detail: 'Pasig · 8 spots left',
                  color: Color(0xFF665341),
                ),
              ],
            ),
          ),
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(20, 24, 20, 10),
            sliver: SliverToBoxAdapter(
              child: SectionHeader(
                'Riders to know',
                subtitle: 'Based on your routes and mutual follows',
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            sliver: SliverList.list(
              children: const [
                _SuggestedRider(
                  name: 'Jules Ramirez',
                  initials: 'JR',
                  detail: 'Adventure · 18 mutuals',
                  color: Color(0xFF526B60),
                ),
                SizedBox(height: 10),
                _SuggestedRider(
                  name: 'Celine Uy',
                  initials: 'CU',
                  detail: 'Touring · 9 mutuals',
                  color: Color(0xFF6B4F62),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscoverHero extends StatelessWidget {
  const _DiscoverHero({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          const RouteArtwork(height: 224, variant: 1),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    MotoMapColors.background.withValues(alpha: 0.88),
                  ],
                  stops: const [0.35, 1],
                ),
              ),
            ),
          ),
          Positioned(
            top: 14,
            left: 14,
            child: AppPill(
              label: 'EDITOR’S PICK',
              icon: Icons.auto_awesome_rounded,
              selected: true,
              compact: true,
            ),
          ),
          const Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sierra Madre Loop',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 7),
                Row(
                  children: [
                    TinyStat(icon: Icons.route_rounded, label: '145 km'),
                    SizedBox(width: 14),
                    TinyStat(icon: Icons.schedule_rounded, label: '3h 15m'),
                    SizedBox(width: 14),
                    TinyStat(
                      icon: Icons.star_rounded,
                      label: '4.9',
                      color: MotoMapColors.warning,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExploreTypes extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.route_rounded, 'Routes', 'New roads'),
      (Icons.groups_2_outlined, 'Clubs', 'Your people'),
      (Icons.event_outlined, 'Events', 'Ride together'),
      (Icons.person_search_outlined, 'Riders', 'Follow more'),
    ];
    return SizedBox(
      height: 88,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 9),
        itemBuilder: (context, index) {
          final item = items[index];
          return SurfaceCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            onTap: () => showAppMessage(context, 'Opening ${item.$2}.'),
            radius: 16,
            child: SizedBox(
              width: 105,
              child: Row(
                children: [
                  Icon(item.$1, color: MotoMapColors.primary, size: 21),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.$2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.$3,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 9,
                            color: MotoMapColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RouteDiscoveryCard extends StatefulWidget {
  const _RouteDiscoveryCard({
    required this.title,
    required this.location,
    required this.distance,
    required this.time,
    required this.rating,
    required this.variant,
    required this.onTap,
  });

  final String title;
  final String location;
  final String distance;
  final String time;
  final String rating;
  final int variant;
  final VoidCallback onTap;

  @override
  State<_RouteDiscoveryCard> createState() => _RouteDiscoveryCardState();
}

class _RouteDiscoveryCardState extends State<_RouteDiscoveryCard> {
  bool saved = false;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(8),
      onTap: widget.onTap,
      child: SizedBox(
        width: 242,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                RouteArtwork(height: 142, variant: widget.variant),
                Positioned(
                  right: 8,
                  top: 8,
                  child: IconButton.filled(
                    onPressed: () => setState(() => saved = !saved),
                    icon: Icon(
                      saved ? Icons.bookmark_rounded : Icons.bookmark_border,
                      size: 17,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: MotoMapColors.background.withValues(
                        alpha: 0.85,
                      ),
                      foregroundColor: saved
                          ? MotoMapColors.primary
                          : MotoMapColors.onSurface,
                      minimumSize: const Size(34, 34),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(7, 10, 7, 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    widget.location,
                    style: const TextStyle(
                      color: MotoMapColors.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      Expanded(
                        child: TinyStat(
                          icon: Icons.route_rounded,
                          label: widget.distance,
                        ),
                      ),
                      Expanded(
                        child: TinyStat(
                          icon: Icons.schedule_rounded,
                          label: widget.time,
                        ),
                      ),
                      TinyStat(
                        icon: Icons.star_rounded,
                        label: widget.rating,
                        color: MotoMapColors.warning,
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
}

class _EventRow extends StatelessWidget {
  const _EventRow({
    required this.day,
    required this.month,
    required this.title,
    required this.detail,
    required this.color,
  });

  final String day;
  final String month;
  final String title;
  final String detail;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      onTap: () => showAppMessage(context, '$title added to your interests.'),
      padding: const EdgeInsets.all(12),
      radius: 16,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 52,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  day,
                  style: const TextStyle(
                    fontSize: 18,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(month, style: MotoMapText.labelCaps),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: const TextStyle(
                    color: MotoMapColors.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: MotoMapColors.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _SuggestedRider extends StatefulWidget {
  const _SuggestedRider({
    required this.name,
    required this.initials,
    required this.detail,
    required this.color,
  });

  final String name;
  final String initials;
  final String detail;
  final Color color;

  @override
  State<_SuggestedRider> createState() => _SuggestedRiderState();
}

class _SuggestedRiderState extends State<_SuggestedRider> {
  bool following = false;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(12),
      radius: 16,
      child: Row(
        children: [
          RiderAvatar(
            initials: widget.initials,
            color: widget.color,
            verified: true,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  widget.detail,
                  style: const TextStyle(
                    color: MotoMapColors.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 34,
            child: following
                ? OutlinedButton(
                    onPressed: () => setState(() => following = false),
                    child: const Text('Following'),
                  )
                : FilledButton(
                    onPressed: () => setState(() => following = true),
                    child: const Text('Follow'),
                  ),
          ),
        ],
      ),
    );
  }
}

class _MotoMapSearchDelegate extends SearchDelegate<String> {
  final suggestions = const [
    'Marilaque Highway',
    'Kaybiang Tunnel',
    'Tagaytay coffee routes',
    'Adventure rider clubs',
    'Weekend group rides',
  ];

  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      scaffoldBackgroundColor: MotoMapColors.background,
      appBarTheme: const AppBarTheme(backgroundColor: MotoMapColors.background),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) => [
    IconButton(onPressed: () => query = '', icon: const Icon(Icons.close)),
  ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    onPressed: () => close(context, ''),
    icon: const Icon(Icons.arrow_back),
  );

  @override
  Widget buildResults(BuildContext context) => _results();

  @override
  Widget buildSuggestions(BuildContext context) => _results();

  Widget _results() {
    final results = suggestions
        .where((item) => item.toLowerCase().contains(query.toLowerCase()))
        .toList();
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: results.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) => ListTile(
        leading: const Icon(Icons.north_east_rounded),
        title: Text(results[index]),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => close(context, results[index]),
      ),
    );
  }
}
