import 'package:flutter/material.dart';

import '../theme/motomap_colors.dart';
import '../widgets/app_ui.dart';
import 'route_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({required this.onOpenDiscover, super.key});

  final VoidCallback onOpenDiscover;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
            sliver: SliverToBoxAdapter(child: _HomeHeader()),
          ),
          SliverToBoxAdapter(child: _RideStories()),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            sliver: SliverToBoxAdapter(
              child: SectionHeader(
                'Following',
                subtitle: 'Fresh rides from your people',
                action: 'Discover riders',
                onAction: onOpenDiscover,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList.list(
              children: [
                _FeedPost(
                  rider: 'Mika Santos',
                  initials: 'MS',
                  meta: '2h · Antipolo, Rizal',
                  caption:
                      'Early climb, cool air, and almost no traffic. The view at Cloud 9 was worth the 5 AM alarm.',
                  routeName: 'Marilaque Sunrise Loop',
                  distance: '68 km',
                  duration: '2h 14m',
                  elevation: '920 m',
                  likes: 128,
                  comments: 18,
                  variant: 0,
                  color: const Color(0xFF386C61),
                ),
                const SizedBox(height: 14),
                _MeetupCard(),
                const SizedBox(height: 14),
                _FeedPost(
                  rider: 'Paolo Reyes',
                  initials: 'PR',
                  meta: 'Yesterday · Tagaytay',
                  caption:
                      'Tested the backroads through Amadeo today. Smooth sweepers, coffee stop included.',
                  routeName: 'Amadeo Coffee Run',
                  distance: '92 km',
                  duration: '3h 06m',
                  elevation: '740 m',
                  likes: 84,
                  comments: 11,
                  variant: 2,
                  color: const Color(0xFF475D7D),
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: MotoMapLogo()),
        _HeaderButton(
          icon: Icons.notifications_none_rounded,
          hasDot: true,
          onTap: () => showAppMessage(context, 'You are all caught up.'),
        ),
        const SizedBox(width: 10),
        const RiderAvatar(
          initials: 'AR',
          size: 38,
          color: Color(0xFF53483F),
          verified: true,
        ),
      ],
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.onTap,
    this.hasDot = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool hasDot;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        children: [
          IconButton.filledTonal(
            onPressed: onTap,
            icon: Icon(icon, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: MotoMapColors.surfaceContainer,
              foregroundColor: MotoMapColors.onSurface,
            ),
          ),
          if (hasDot)
            Positioned(
              right: 7,
              top: 7,
              child: Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: MotoMapColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RideStories extends StatelessWidget {
  static const stories = [
    ('Your ride', 'AR', Color(0xFF59483D), true),
    ('Mika', 'MS', Color(0xFF386C61), false),
    ('Paolo', 'PR', Color(0xFF475D7D), false),
    ('Nadine', 'NC', Color(0xFF765368), false),
    ('Berto', 'BL', Color(0xFF6E613C), false),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: stories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 17),
        itemBuilder: (context, index) {
          final item = stories[index];
          return GestureDetector(
            onTap: () => showAppMessage(
              context,
              item.$4 ? 'Start a ride from Plan.' : '${item.$1} rode today.',
            ),
            child: SizedBox(
              width: 58,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: item.$4
                            ? MotoMapColors.outline
                            : MotoMapColors.primary,
                        width: 2,
                      ),
                    ),
                    child: RiderAvatar(
                      initials: item.$2,
                      color: item.$3,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.$1,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: MotoMapColors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
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

class _FeedPost extends StatefulWidget {
  const _FeedPost({
    required this.rider,
    required this.initials,
    required this.meta,
    required this.caption,
    required this.routeName,
    required this.distance,
    required this.duration,
    required this.elevation,
    required this.likes,
    required this.comments,
    required this.variant,
    required this.color,
  });

  final String rider;
  final String initials;
  final String meta;
  final String caption;
  final String routeName;
  final String distance;
  final String duration;
  final String elevation;
  final int likes;
  final int comments;
  final int variant;
  final Color color;

  @override
  State<_FeedPost> createState() => _FeedPostState();
}

class _FeedPostState extends State<_FeedPost> {
  bool liked = false;
  bool saved = false;

  void _openRoute() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RouteDetailScreen(
          title: widget.routeName,
          distance: widget.distance,
          duration: widget.duration,
          elevation: widget.elevation,
          variant: widget.variant,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 8, 12),
            child: Row(
              children: [
                RiderAvatar(
                  initials: widget.initials,
                  size: 40,
                  color: widget.color,
                  verified: true,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.rider,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.meta,
                        style: const TextStyle(
                          color: MotoMapColors.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => showAppMessage(context, 'Post options'),
                  icon: const Icon(Icons.more_horiz_rounded, size: 20),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _openRoute,
            child: Stack(
              children: [
                RouteArtwork(height: 188, variant: widget.variant),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: MotoMapColors.background.withValues(alpha: 0.90),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.routeName,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 7),
                              Wrap(
                                spacing: 12,
                                children: [
                                  TinyStat(
                                    icon: Icons.route_rounded,
                                    label: widget.distance,
                                  ),
                                  TinyStat(
                                    icon: Icons.schedule_rounded,
                                    label: widget.duration,
                                  ),
                                  TinyStat(
                                    icon: Icons.landscape_outlined,
                                    label: widget.elevation,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: MotoMapColors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Text(widget.caption, style: MotoMapText.bodyMd),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(7, 0, 7, 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => setState(() => liked = !liked),
                  icon: Icon(
                    liked ? Icons.favorite_rounded : Icons.favorite_border,
                    color: liked
                        ? MotoMapColors.primary
                        : MotoMapColors.onSurfaceVariant,
                  ),
                ),
                Text(
                  '${widget.likes + (liked ? 1 : 0)}',
                  style: const TextStyle(fontSize: 11),
                ),
                const SizedBox(width: 6),
                IconButton(
                  onPressed: () => showAppMessage(
                    context,
                    '${widget.comments} rider comments',
                  ),
                  icon: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: MotoMapColors.onSurfaceVariant,
                  ),
                ),
                Text(
                  '${widget.comments}',
                  style: const TextStyle(fontSize: 11),
                ),
                IconButton(
                  onPressed: () =>
                      showAppMessage(context, 'Ride shared to your link.'),
                  icon: const Icon(
                    Icons.ios_share_rounded,
                    color: MotoMapColors.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => setState(() => saved = !saved),
                  icon: Icon(
                    saved ? Icons.bookmark_rounded : Icons.bookmark_border,
                    color: saved
                        ? MotoMapColors.primary
                        : MotoMapColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MeetupCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      color: const Color(0xFF151B18),
      borderColor: MotoMapColors.primary.withValues(alpha: 0.30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppPill(
                label: 'UP NEXT',
                icon: Icons.groups_2_outlined,
                selected: true,
                compact: true,
              ),
              const Spacer(),
              Text(
                'SAT · 5:30 AM',
                style: MotoMapText.labelCaps.copyWith(
                  color: MotoMapColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Breakfast ride to Kaybiang', style: MotoMapText.title),
          const SizedBox(height: 5),
          Text(
            'Cavite Weekend Riders · 12 riders joined',
            style: MotoMapText.bodyMd.copyWith(
              color: MotoMapColors.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              const SizedBox(
                width: 90,
                height: 30,
                child: Stack(
                  children: [
                    RiderAvatar(initials: 'JR', size: 30),
                    Positioned(
                      left: 22,
                      child: RiderAvatar(
                        initials: 'MS',
                        size: 30,
                        color: Color(0xFF386C61),
                      ),
                    ),
                    Positioned(
                      left: 44,
                      child: RiderAvatar(
                        initials: 'PR',
                        size: 30,
                        color: Color(0xFF475D7D),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () =>
                    showAppMessage(context, 'You joined the breakfast ride.'),
                child: const Text('View meetup →'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
