import 'package:flutter/material.dart';

import '../models/ride_data.dart';
import '../services/ride_repository.dart';
import '../theme/motomap_colors.dart';
import '../widgets/app_ui.dart';
import '../widgets/motomap_map.dart';
import 'ride_mode_screen.dart';

class RouteDetailScreen extends StatefulWidget {
  const RouteDetailScreen({
    this.plan,
    this.title,
    this.distance,
    this.duration,
    this.elevation,
    this.variant,
    super.key,
  });

  final RoutePlan? plan;

  // Kept temporarily so untouched community-preview pages still compile. A
  // preview without a real RoutePlan cannot start navigation or save a ride.
  final String? title;
  final String? distance;
  final String? duration;
  final String? elevation;
  final int? variant;

  @override
  State<RouteDetailScreen> createState() => _RouteDetailScreenState();
}

class _RouteDetailScreenState extends State<RouteDetailScreen> {
  bool _archiving = false;

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    return Scaffold(
      appBar: AppBar(
        title: Text(plan?.title ?? widget.title ?? 'Route preview'),
        actions: [
          if (plan != null)
            IconButton(
              tooltip: 'Archive route',
              onPressed: _archiving ? null : () => _archive(plan),
              icon: const Icon(Icons.archive_outlined),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: plan == null ? _unavailablePreview() : _realRoute(plan),
        ),
      ),
    );
  }

  Widget _realRoute(RoutePlan plan) {
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
          children: [
            SizedBox(height: 300, child: MotoMapView(route: plan.coordinates)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AppPill(
                  label: plan.preference.label.toUpperCase(),
                  icon: Icons.alt_route_rounded,
                  selected: true,
                  compact: true,
                ),
                AppPill(
                  label: plan.isLoop ? 'LOOP' : 'DESTINATION',
                  icon: plan.isLoop
                      ? Icons.loop_rounded
                      : Icons.location_on_outlined,
                  compact: true,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(plan.title, style: MotoMapText.headlineLg),
            const SizedBox(height: 6),
            Text(
              '${plan.originName} → ${plan.destinationName}',
              style: MotoMapText.bodyMd.copyWith(
                color: MotoMapColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _RouteMetric(
                    label: 'DISTANCE',
                    value: '${plan.distanceKm.toStringAsFixed(1)} km',
                    icon: Icons.route_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _RouteMetric(
                    label: 'EST. RIDE TIME',
                    value: _duration(plan.duration),
                    icon: Icons.schedule_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _RouteMetric(
                    label: 'DIRECTIONS',
                    value: '${plan.maneuvers.length}',
                    icon: Icons.turn_right_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const SurfaceCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: MotoMapColors.primary,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Directions use current OpenStreetMap road data. Always follow road signs, closures, and local traffic laws.',
                      style: TextStyle(
                        fontSize: 10,
                        height: 1.45,
                        color: MotoMapColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const SectionHeader(
              'Turn-by-turn directions',
              subtitle: 'Voice guidance will announce these while riding',
            ),
            const SizedBox(height: 10),
            if (plan.maneuvers.isEmpty)
              const _EmptyState(
                icon: Icons.directions_off_outlined,
                title: 'No maneuver list available',
                message:
                    'The highlighted road can still be followed on the map.',
              )
            else
              for (var index = 0; index < plan.maneuvers.length; index++) ...[
                _ManeuverRow(index: index + 1, maneuver: plan.maneuvers[index]),
                if (index != plan.maneuvers.length - 1)
                  const SizedBox(height: 8),
              ],
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
                color: MotoMapColors.surface.withValues(alpha: 0.97),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: MotoMapColors.outlineVariant),
                boxShadow: const [
                  BoxShadow(color: Colors.black45, blurRadius: 24),
                ],
              ),
              child: PrimaryButton(
                label: 'Open ride mode',
                icon: Icons.navigation_rounded,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => RideModeScreen(plan: plan)),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _unavailablePreview() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 80),
        _EmptyState(
          icon: Icons.map_outlined,
          title: widget.title ?? 'Preview route',
          message:
              'This community preview does not contain real road geometry yet. Open Plan to search a destination or generate a GPS-ready loop.',
        ),
      ],
    );
  }

  Future<void> _archive(RoutePlan plan) async {
    setState(() => _archiving = true);
    try {
      await RideRepository.instance.archiveRoute(plan.id);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() => _archiving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not archive route: $error')),
      );
    }
  }

  static String _duration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return hours == 0 ? '${minutes}m' : '${hours}h ${minutes}m';
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
      radius: 15,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: MotoMapColors.primary),
          const SizedBox(height: 9),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 3),
          Text(label, style: MotoMapText.labelCaps.copyWith(fontSize: 7)),
        ],
      ),
    );
  }
}

class _ManeuverRow extends StatelessWidget {
  const _ManeuverRow({required this.index, required this.maneuver});

  final int index;
  final RouteManeuver maneuver;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(12),
      radius: 14,
      child: Row(
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: MotoMapColors.primary.withValues(alpha: 0.14),
            foregroundColor: MotoMapColors.primary,
            child: Text(
              '$index',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  maneuver.instruction,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${maneuver.distanceKm.toStringAsFixed(1)} km · '
                  '${RouteDetailScreenStateDuration.format(maneuver.durationSeconds)}',
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
    );
  }
}

class RouteDetailScreenStateDuration {
  const RouteDetailScreenStateDuration._();

  static String format(int seconds) {
    final duration = Duration(seconds: seconds);
    if (duration.inMinutes < 1) return '${duration.inSeconds}s';
    return '${duration.inMinutes}m';
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        children: [
          Icon(icon, size: 38, color: MotoMapColors.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              height: 1.45,
              color: MotoMapColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
