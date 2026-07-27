import 'package:flutter/material.dart';

import '../theme/motomap_colors.dart';
import '../widgets/app_ui.dart';
import 'ride_mode_screen.dart';

class RouteDetailScreen extends StatefulWidget {
  const RouteDetailScreen({
    required this.title,
    required this.distance,
    required this.duration,
    required this.elevation,
    required this.variant,
    super.key,
  });

  final String title;
  final String distance;
  final String duration;
  final String elevation;
  final int variant;

  @override
  State<RouteDetailScreen> createState() => _RouteDetailScreenState();
}

class _RouteDetailScreenState extends State<RouteDetailScreen> {
  bool saved = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Stack(
            children: [
              CustomScrollView(
                slivers: [
                  SliverAppBar(
                    expandedHeight: 288,
                    pinned: true,
                    backgroundColor: MotoMapColors.background,
                    leading: _RoundAppBarButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: () => Navigator.pop(context),
                    ),
                    actions: [
                      _RoundAppBarButton(
                        icon: saved
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        color: saved
                            ? MotoMapColors.primary
                            : MotoMapColors.onSurface,
                        onTap: () => setState(() => saved = !saved),
                      ),
                      const SizedBox(width: 8),
                      _RoundAppBarButton(
                        icon: Icons.ios_share_rounded,
                        onTap: () =>
                            showAppMessage(context, 'Route link copied.'),
                      ),
                      const SizedBox(width: 14),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                          RouteArtwork(height: 288, variant: widget.variant),
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  MotoMapColors.background,
                                ],
                                stops: [0.55, 1],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 118),
                    sliver: SliverList.list(
                      children: [
                        const Row(
                          children: [
                            AppPill(
                              label: 'SCENIC',
                              icon: Icons.landscape_outlined,
                              selected: true,
                              compact: true,
                            ),
                            SizedBox(width: 8),
                            AppPill(
                              label: 'INTERMEDIATE',
                              icon: Icons.speed_rounded,
                              compact: true,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(widget.title, style: MotoMapText.headlineLg),
                        const SizedBox(height: 7),
                        Text(
                          'A flowing ride through ridge roads, cool forest sections, and small towns with reliable stops.',
                          style: MotoMapText.bodyMd.copyWith(
                            color: MotoMapColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 22),
                        Row(
                          children: [
                            Expanded(
                              child: _RouteMetric(
                                label: 'DISTANCE',
                                value: widget.distance,
                                icon: Icons.route_rounded,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _RouteMetric(
                                label: 'RIDE TIME',
                                value: widget.duration,
                                icon: Icons.schedule_rounded,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _RouteMetric(
                                label: 'ELEVATION',
                                value: widget.elevation,
                                icon: Icons.landscape_outlined,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const SectionHeader(
                          'Route character',
                          subtitle: 'What riders say about this road',
                        ),
                        const SizedBox(height: 12),
                        const Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            AppPill(label: 'Flowing corners', compact: true),
                            AppPill(label: 'Great views', compact: true),
                            AppPill(label: 'Light traffic', compact: true),
                            AppPill(label: 'Good pavement', compact: true),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const SectionHeader('Route notes'),
                        const SizedBox(height: 12),
                        const _NoteRow(
                          icon: Icons.local_gas_station_outlined,
                          title: 'Fuel at KM 42',
                          detail: 'Last reliable station before the ridge.',
                        ),
                        const SizedBox(height: 8),
                        const _NoteRow(
                          icon: Icons.coffee_outlined,
                          title: 'Cafe Katerina',
                          detail: 'Popular breakfast stop with safe parking.',
                        ),
                        const SizedBox(height: 8),
                        const _NoteRow(
                          icon: Icons.warning_amber_rounded,
                          title: 'Watch the weather',
                          detail: 'Fog can reduce visibility after 4 PM.',
                          warning: true,
                        ),
                        const SizedBox(height: 24),
                        SectionHeader(
                          'Ridden by 1,284 riders',
                          action: 'Reviews',
                          onAction: () =>
                              showAppMessage(context, '4.9 from 326 reviews.'),
                        ),
                        const SizedBox(height: 10),
                        const SurfaceCard(
                          child: Row(
                            children: [
                              SizedBox(
                                width: 82,
                                height: 36,
                                child: Stack(
                                  children: [
                                    RiderAvatar(initials: 'MS', size: 36),
                                    Positioned(
                                      left: 24,
                                      child: RiderAvatar(
                                        initials: 'JR',
                                        size: 36,
                                        color: Color(0xFF475D7D),
                                      ),
                                    ),
                                    Positioned(
                                      left: 48,
                                      child: RiderAvatar(
                                        initials: 'CU',
                                        size: 36,
                                        color: Color(0xFF6B4F62),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Mika, Jules, and 14 people you follow rode this.',
                                  style: TextStyle(fontSize: 12, height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: MotoMapColors.surface.withValues(alpha: 0.96),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: MotoMapColors.outlineVariant),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 24,
                        ),
                      ],
                    ),
                    child: PrimaryButton(
                      label: 'Start this ride',
                      icon: Icons.navigation_rounded,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RideModeScreen(
                            routeName: widget.title,
                            distance: widget.distance,
                            variant: widget.variant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundAppBarButton extends StatelessWidget {
  const _RoundAppBarButton({
    required this.icon,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      style: IconButton.styleFrom(
        backgroundColor: MotoMapColors.background.withValues(alpha: 0.82),
        foregroundColor: color ?? MotoMapColors.onSurface,
      ),
    );
  }
}

class _RouteMetric extends StatelessWidget {
  const _RouteMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 13),
      radius: 15,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: MotoMapColors.primary),
          const SizedBox(height: 11),
          Text(
            value,
            maxLines: 1,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 3),
          Text(label, style: MotoMapText.labelCaps.copyWith(fontSize: 8)),
        ],
      ),
    );
  }
}

class _NoteRow extends StatelessWidget {
  const _NoteRow({
    required this.icon,
    required this.title,
    required this.detail,
    this.warning = false,
  });

  final IconData icon;
  final String title;
  final String detail;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(13),
      radius: 15,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (warning ? MotoMapColors.warning : MotoMapColors.primary)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 19,
              color: warning ? MotoMapColors.warning : MotoMapColors.primary,
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
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
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
        ],
      ),
    );
  }
}
