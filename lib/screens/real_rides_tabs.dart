import 'package:flutter/material.dart';

import '../models/ride_data.dart';
import '../services/ride_repository.dart';
import '../theme/motomap_colors.dart';
import '../widgets/app_ui.dart';
import '../widgets/motomap_map.dart';
import 'route_detail_screen.dart';

class PlannedRidesTab extends StatefulWidget {
  const PlannedRidesTab({super.key});

  @override
  State<PlannedRidesTab> createState() => _PlannedRidesTabState();
}

class _PlannedRidesTabState extends State<PlannedRidesTab> {
  late Future<List<RoutePlan>> _plans;
  bool _showArchived = false;

  @override
  void initState() {
    super.initState();
    _plans = _loadRoutes();
    RideRepository.instance.changes.addListener(_refresh);
  }

  @override
  void dispose() {
    RideRepository.instance.changes.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() => _plans = _loadRoutes());
    }
  }

  Future<List<RoutePlan>> _loadRoutes() => _showArchived
      ? RideRepository.instance.fetchArchivedRoutes()
      : RideRepository.instance.fetchPlannedRoutes();

  void _showStatus(bool archived) {
    if (_showArchived == archived) return;
    setState(() {
      _showArchived = archived;
      _plans = _loadRoutes();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Row(
            children: [
              AppPill(
                label: 'PLANNED',
                selected: !_showArchived,
                onTap: () => _showStatus(false),
              ),
              const SizedBox(width: 8),
              AppPill(
                label: 'ARCHIVED',
                icon: Icons.archive_outlined,
                selected: _showArchived,
                onTap: () => _showStatus(true),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _showArchived
                      ? 'Swipe right to restore'
                      : 'Right archive · Left delete',
                  maxLines: 2,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 8,
                    color: MotoMapColors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<RoutePlan>>(
            future: _plans,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _DataState(
                  icon: Icons.cloud_off_outlined,
                  title: 'Plans unavailable',
                  message: _friendlyError(snapshot.error!),
                  action: 'Retry',
                  onAction: _refresh,
                );
              }
              final plans = snapshot.data ?? const [];
              if (plans.isEmpty) {
                return _DataState(
                  icon: Icons.route_outlined,
                  title: _showArchived
                      ? 'No archived rides'
                      : 'No planned rides yet',
                  message: _showArchived
                      ? 'Swipe right on a planned ride to archive it.'
                      : 'Use Plan to search a destination or generate a loop. Saved routes will appear here.',
                );
              }
              return RefreshIndicator(
                onRefresh: () async => _refresh(),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  itemCount: plans.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final plan = plans[index];
                    return Dismissible(
                      key: ValueKey(plan.id),
                      background: _SwipeActionBackground(
                        alignment: Alignment.centerLeft,
                        color: MotoMapColors.warning,
                        icon: _showArchived
                            ? Icons.unarchive_outlined
                            : Icons.archive_outlined,
                        label: _showArchived ? 'RESTORE' : 'ARCHIVE',
                      ),
                      secondaryBackground: const _SwipeActionBackground(
                        alignment: Alignment.centerRight,
                        color: MotoMapColors.error,
                        icon: Icons.delete_forever_outlined,
                        label: 'DELETE',
                      ),
                      confirmDismiss: (direction) =>
                          _confirmRouteAction(plan, direction),
                      onDismissed: (_) =>
                          RideRepository.instance.notifyRefresh(),
                      child: SurfaceCard(
                        onTap: () => Navigator.of(context)
                            .push(
                              MaterialPageRoute(
                                builder: (_) => RouteDetailScreen(plan: plan),
                              ),
                            )
                            .then((_) => _refresh()),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: MotoMapColors.primary.withValues(
                                  alpha: 0.13,
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                plan.isLoop
                                    ? Icons.loop_rounded
                                    : Icons.location_on_outlined,
                                color: MotoMapColors.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    plan.title,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${plan.distanceKm.toStringAsFixed(1)} km · '
                                    '${_formatDuration(plan.duration)} · '
                                    '${plan.preference.label}',
                                    style: const TextStyle(
                                      fontSize: 9,
                                      color: MotoMapColors.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    plan.destinationName,
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
                            const Icon(Icons.chevron_right_rounded),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<bool> _confirmRouteAction(
    RoutePlan plan,
    DismissDirection direction,
  ) async {
    final deleting = direction == DismissDirection.endToStart;
    final restoring = _showArchived && !deleting;
    if (deleting) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete saved ride?'),
          content: Text(
            '“${plan.title}” will be permanently removed. Completed ride '
            'history will not be deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: MotoMapColors.error,
              ),
              child: const Text('Delete permanently'),
            ),
          ],
        ),
      );
      if (confirmed != true) return false;
    }
    try {
      if (deleting) {
        await RideRepository.instance.deleteRoute(plan.id, notify: false);
      } else if (restoring) {
        await RideRepository.instance.restoreRoute(plan.id, notify: false);
      } else {
        await RideRepository.instance.archiveRoute(plan.id, notify: false);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              deleting
                  ? 'Saved ride deleted.'
                  : restoring
                  ? 'Saved ride restored.'
                  : 'Saved ride archived.',
            ),
          ),
        );
      }
      return true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not ${deleting
                  ? 'delete'
                  : restoring
                  ? 'restore'
                  : 'archive'} saved ride: $error',
            ),
          ),
        );
      }
      return false;
    }
  }
}

class _SwipeActionBackground extends StatelessWidget {
  const _SwipeActionBackground({
    required this.alignment,
    required this.color,
    required this.icon,
    required this.label,
  });

  final Alignment alignment;
  final Color color;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    alignment: alignment,
    padding: const EdgeInsets.symmetric(horizontal: 22),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.5)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 7),
        Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w900),
        ),
      ],
    ),
  );
}

class CompletedRidesTab extends StatefulWidget {
  const CompletedRidesTab({super.key});

  @override
  State<CompletedRidesTab> createState() => _CompletedRidesTabState();
}

class _CompletedRidesTabState extends State<CompletedRidesTab> {
  late Future<List<RideRecord>> _rides;

  @override
  void initState() {
    super.initState();
    _rides = RideRepository.instance.fetchCompletedRides();
    RideRepository.instance.changes.addListener(_refresh);
  }

  @override
  void dispose() {
    RideRepository.instance.changes.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() => _rides = RideRepository.instance.fetchCompletedRides());
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<RideRecord>>(
      future: _rides,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _DataState(
            icon: Icons.cloud_off_outlined,
            title: 'Ride history unavailable',
            message: _friendlyError(snapshot.error!),
            action: 'Retry',
            onAction: _refresh,
          );
        }
        final rides = snapshot.data ?? const [];
        if (rides.isEmpty) {
          return const _DataState(
            icon: Icons.two_wheeler_outlined,
            title: 'No completed rides yet',
            message:
                'Finish a real GPS ride and its route, timing, fuel result, and scores will appear here.',
          );
        }
        final now = DateTime.now();
        final month = rides.where(
          (ride) =>
              ride.startedAt.year == now.year &&
              ride.startedAt.month == now.month,
        );
        final monthRides = month.toList(growable: false);
        final monthDistance = monthRides.fold<double>(
          0,
          (total, ride) => total + ride.distanceKm,
        );
        final monthSeconds = monthRides.fold<int>(
          0,
          (total, ride) => total + ride.elapsedDuration.inSeconds,
        );
        return RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _SummaryMetric(
                      label: 'THIS MONTH',
                      value: '${monthDistance.toStringAsFixed(1)} km',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SummaryMetric(
                      label: 'ELAPSED',
                      value: _formatDuration(Duration(seconds: monthSeconds)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SummaryMetric(
                      label: 'RIDES',
                      value: '${monthRides.length}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const SectionHeader('Recorded rides'),
              const SizedBox(height: 10),
              for (final ride in rides) ...[
                _CompletedRideCard(ride: ride),
                const SizedBox(height: 10),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _CompletedRideCard extends StatelessWidget {
  const _CompletedRideCard({required this.ride});

  final RideRecord ride;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => RideSummaryScreen(ride: ride))),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: MotoMapColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.check_rounded,
              color: MotoMapColors.success,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ride.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_date(ride.startedAt)} · ${ride.distanceKm.toStringAsFixed(1)} km · '
                  '${_formatDuration(ride.elapsedDuration)}',
                  style: const TextStyle(
                    fontSize: 9,
                    color: MotoMapColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Ride ${ride.ridingScore?.toString() ?? 'N/A'} · '
                  'Bike ${ride.motorcycleHealthScore?.toString() ?? 'N/A'}'
                  '${ride.fuelIsEstimated ? ' · Fuel estimated' : ''}',
                  style: const TextStyle(
                    fontSize: 9,
                    color: MotoMapColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

class RideSummaryScreen extends StatelessWidget {
  const RideSummaryScreen({required this.ride, super.key});

  final RideRecord ride;

  @override
  Widget build(BuildContext context) {
    final explanations =
        (ride.scoreDetails['explanation'] as List<dynamic>? ?? const [])
            .map((item) => item.toString())
            .toList(growable: false);
    return Scaffold(
      appBar: AppBar(title: const Text('Ride results')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              if (ride.routeCoordinates.length >= 2)
                SizedBox(
                  height: 300,
                  child: MotoMapView(
                    route: const [],
                    traveled: ride.routeCoordinates,
                  ),
                )
              else
                const _DataState(
                  icon: Icons.location_off_outlined,
                  title: 'Route unavailable',
                  message:
                      'This ride did not save enough valid GPS points to draw a map.',
                ),
              const SizedBox(height: 16),
              Text(ride.title, style: MotoMapText.headlineLg),
              const SizedBox(height: 5),
              Text(
                '${_date(ride.startedAt)} · ${ride.reachedDestination ? 'Destination reached' : 'Ended manually'}',
                style: const TextStyle(color: MotoMapColors.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _DetailPill(
                    label: 'Distance',
                    value: '${ride.distanceKm.toStringAsFixed(1)} km',
                  ),
                  _DetailPill(
                    label: 'Elapsed',
                    value: _formatDuration(ride.elapsedDuration),
                  ),
                  _DetailPill(
                    label: 'Moving',
                    value: ride.movingDurationSeconds == null
                        ? 'N/A'
                        : _formatDuration(
                            Duration(seconds: ride.movingDurationSeconds!),
                          ),
                  ),
                  _DetailPill(
                    label: 'Paused',
                    value: _formatDuration(
                      Duration(seconds: ride.pausedDurationSeconds),
                    ),
                  ),
                  _DetailPill(
                    label: 'Average speed',
                    value: ride.averageSpeedKph == null
                        ? 'N/A'
                        : '${ride.averageSpeedKph!.toStringAsFixed(1)} km/h',
                  ),
                  _DetailPill(
                    label: 'Maximum speed',
                    value: ride.maximumSpeedKph == null
                        ? 'N/A'
                        : '${ride.maximumSpeedKph!.toStringAsFixed(1)} km/h',
                  ),
                  _DetailPill(
                    label: ride.fuelIsEstimated
                        ? 'Fuel estimate'
                        : 'Fuel consumed',
                    value: ride.fuelConsumedLiters == null
                        ? 'N/A'
                        : '${ride.fuelConsumedLiters!.toStringAsFixed(2)} L',
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _ScoreCard(
                      label: 'Riding score',
                      score: ride.ridingScore,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ScoreCard(
                      label: 'Motorcycle health',
                      score: ride.motorcycleHealthScore,
                    ),
                  ),
                ],
              ),
              if (ride.fuelIsEstimated) ...[
                const SizedBox(height: 12),
                const SurfaceCard(
                  borderColor: MotoMapColors.warning,
                  child: Text(
                    'Estimated fuel: the ECU did not provide real PID 5E fuel-rate data. MotoMap used GPS distance and a motorcycle-size estimate.',
                    style: TextStyle(fontSize: 10, height: 1.45),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              const SectionHeader('Why this score'),
              const SizedBox(height: 10),
              if (explanations.isEmpty)
                const Text('No scoring explanation was recorded.')
              else
                for (final explanation in explanations)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          size: 17,
                          color: MotoMapColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(explanation)),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SurfaceCard(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
    radius: 15,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: MotoMapText.labelCaps.copyWith(fontSize: 7)),
        const SizedBox(height: 7),
        Text(
          value,
          maxLines: 1,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
        ),
      ],
    ),
  );
}

class _DetailPill extends StatelessWidget {
  const _DetailPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: MotoMapColors.surfaceContainer,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: MotoMapColors.outlineVariant),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 8,
            color: MotoMapColors.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.label, required this.score});

  final String label;
  final int? score;

  @override
  Widget build(BuildContext context) => SurfaceCard(
    child: Column(
      children: [
        Text(label, style: MotoMapText.labelCaps),
        const SizedBox(height: 8),
        Text(
          score == null ? 'N/A' : '$score/100',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: score == null
                ? MotoMapColors.onSurfaceVariant
                : score! >= 80
                ? MotoMapColors.success
                : score! >= 60
                ? MotoMapColors.warning
                : MotoMapColors.error,
          ),
        ),
      ],
    ),
  );
}

class _DataState extends StatelessWidget {
  const _DataState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const SizedBox(height: 70),
      Icon(icon, size: 46, color: MotoMapColors.onSurfaceVariant),
      const SizedBox(height: 12),
      Text(title, textAlign: TextAlign.center, style: MotoMapText.headlineMd),
      const SizedBox(height: 7),
      Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: MotoMapColors.onSurfaceVariant,
          height: 1.45,
        ),
      ),
      if (action != null) ...[
        const SizedBox(height: 14),
        Center(
          child: TextButton(onPressed: onAction, child: Text(action!)),
        ),
      ],
    ],
  );
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  return hours == 0 ? '${minutes}m' : '${hours}h ${minutes}m';
}

String _date(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final local = date.toLocal();
  return '${months[local.month - 1]} ${local.day}, ${local.year}';
}

String _friendlyError(Object error) {
  final text = error.toString();
  if (text.contains('route_plans') || text.contains('rides')) {
    return 'The real-ride database migration has not been applied yet.';
  }
  return text.startsWith('PostgrestException(message:')
      ? 'MotoMap could not load this data from Supabase.'
      : text;
}
