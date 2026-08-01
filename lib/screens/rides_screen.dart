import 'package:flutter/material.dart';

import '../models/motorcycle.dart';
import '../services/elm327_service.dart';
import '../services/image_storage_service.dart';
import '../services/motorcycle_service.dart';
import '../theme/motomap_colors.dart';
import '../widgets/app_ui.dart';
import 'elm327_setup_screen.dart';
import 'garage_flow.dart';
import 'route_detail_screen.dart';

class RidesScreen extends StatefulWidget {
  const RidesScreen({super.key});

  @override
  State<RidesScreen> createState() => _RidesScreenState();
}

class _RidesScreenState extends State<RidesScreen> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('My rides', style: MotoMapText.headlineLg),
                    ),
                    IconButton.filledTonal(
                      onPressed: () =>
                          showAppMessage(context, 'Ride history filtered.'),
                      icon: const Icon(Icons.tune_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SegmentedTabs(
                  selected: tab,
                  onChanged: (value) => setState(() => tab = value),
                ),
              ],
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: tab,
              children: const [_PlannedRides(), _CompletedRides(), _Garage()],
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({required this.selected, required this.onChanged});

  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = ['Planned', 'Completed', 'Garage'];
    const icons = [
      Icons.calendar_today_outlined,
      Icons.check_circle_outline_rounded,
      Icons.two_wheeler_outlined,
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: MotoMapColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: MotoMapColors.outlineVariant),
      ),
      child: Row(
        children: List.generate(labels.length, (index) {
          final active = selected == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: active
                      ? MotoMapColors.surfaceContainerHighest
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icons[index],
                      size: 15,
                      color: active
                          ? MotoMapColors.primary
                          : MotoMapColors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      labels[index],
                      style: TextStyle(
                        fontSize: 10,
                        color: active
                            ? MotoMapColors.onSurface
                            : MotoMapColors.onSurfaceVariant,
                        fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _PlannedRides extends StatelessWidget {
  const _PlannedRides();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        SurfaceCard(
          color: const Color(0xFF17201D),
          borderColor: MotoMapColors.primary.withValues(alpha: 0.22),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: MotoMapColors.primary.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.wb_sunny_outlined,
                  color: MotoMapColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Good weather window',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Saturday · 23–28°C · Low chance of rain',
                      style: TextStyle(
                        color: MotoMapColors.onSurfaceVariant,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SectionHeader('Coming up'),
        const SizedBox(height: 12),
        _PlannedRideCard(
          day: 'SAT',
          date: '03',
          title: 'Kaybiang Breakfast Ride',
          detail: '5:30 AM · 132 km · 12 riders',
          variant: 2,
          onTap: () => _openRoute(context, 'Kaybiang Breakfast Ride', 2),
        ),
        const SizedBox(height: 12),
        _PlannedRideCard(
          day: 'SUN',
          date: '11',
          title: 'Rizal Coffee Ridge Loop',
          detail: '6:15 AM · 104 km · Solo',
          variant: 3,
          onTap: () => _openRoute(context, 'Rizal Coffee Ridge Loop', 3),
        ),
        const SizedBox(height: 24),
        const SectionHeader('Saved for later'),
        const SizedBox(height: 12),
        _CompactSavedRoute(
          title: 'Laguna Lakeshore Loop',
          detail: '188 km · 4h 20m',
          variant: 0,
          onTap: () => _openRoute(context, 'Laguna Lakeshore Loop', 0),
        ),
      ],
    );
  }

  static void _openRoute(BuildContext context, String title, int variant) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RouteDetailScreen(
          title: title,
          distance: variant == 2 ? '132 km' : '104 km',
          duration: variant == 2 ? '3h 40m' : '2h 54m',
          elevation: variant == 2 ? '860 m' : '980 m',
          variant: variant,
        ),
      ),
    );
  }
}

class _PlannedRideCard extends StatelessWidget {
  const _PlannedRideCard({
    required this.day,
    required this.date,
    required this.title,
    required this.detail,
    required this.variant,
    required this.onTap,
  });

  final String day;
  final String date;
  final String title;
  final String detail;
  final int variant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(8),
      onTap: onTap,
      child: Column(
        children: [
          RouteArtwork(height: 130, variant: variant),
          Padding(
            padding: const EdgeInsets.fromLTRB(7, 12, 7, 6),
            child: Row(
              children: [
                Container(
                  width: 44,
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: MotoMapColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        day,
                        style: MotoMapText.labelCaps.copyWith(
                          color: MotoMapColors.primary,
                          fontSize: 8,
                        ),
                      ),
                      Text(
                        date,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
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
          ),
        ],
      ),
    );
  }
}

class _CompactSavedRoute extends StatelessWidget {
  const _CompactSavedRoute({
    required this.title,
    required this.detail,
    required this.variant,
    required this.onTap,
  });

  final String title;
  final String detail;
  final int variant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          SizedBox(
            width: 94,
            child: RouteArtwork(height: 76, variant: variant),
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
                const SizedBox(height: 5),
                Text(
                  detail,
                  style: const TextStyle(
                    fontSize: 10,
                    color: MotoMapColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.bookmark_rounded, color: MotoMapColors.primary),
        ],
      ),
    );
  }
}

class _CompletedRides extends StatelessWidget {
  const _CompletedRides();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        Row(
          children: const [
            Expanded(
              child: _SummaryMetric(label: 'THIS MONTH', value: '428 km'),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _SummaryMetric(label: 'RIDE TIME', value: '11h 42m'),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _SummaryMetric(label: 'RIDES', value: '6'),
            ),
          ],
        ),
        const SizedBox(height: 22),
        const SectionHeader('July 2026'),
        const SizedBox(height: 12),
        const _CompletedRide(
          title: 'Marilaque Sunrise Loop',
          date: '27 JUL',
          detail: '68 km · 2h 14m · 51 km/h avg',
          variant: 0,
        ),
        const SizedBox(height: 10),
        const _CompletedRide(
          title: 'Tagaytay Backroads',
          date: '20 JUL',
          detail: '92 km · 3h 06m · 46 km/h avg',
          variant: 2,
        ),
        const SizedBox(height: 10),
        const _CompletedRide(
          title: 'Boso-Boso Quick Loop',
          date: '13 JUL',
          detail: '54 km · 1h 35m · 48 km/h avg',
          variant: 3,
        ),
      ],
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
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
}

class _CompletedRide extends StatelessWidget {
  const _CompletedRide({
    required this.title,
    required this.date,
    required this.detail,
    required this.variant,
  });

  final String title;
  final String date;
  final String detail;
  final int variant;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(8),
      onTap: () => showAppMessage(context, 'Opening ride summary.'),
      child: Row(
        children: [
          SizedBox(
            width: 102,
            child: RouteArtwork(height: 82, variant: variant),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(date, style: MotoMapText.labelCaps.copyWith(fontSize: 8)),
                const SizedBox(height: 5),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  detail,
                  style: const TextStyle(
                    fontSize: 9,
                    color: MotoMapColors.onSurfaceVariant,
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

class _Garage extends StatefulWidget {
  const _Garage();

  @override
  State<_Garage> createState() => _GarageState();
}

class _GarageState extends State<_Garage> {
  late Future<List<Motorcycle>> _motorcycles;

  @override
  void initState() {
    super.initState();
    _motorcycles = MotorcycleService.instance.fetchMotorcycles();
    MotorcycleService.instance.changes.addListener(_refresh);
    Elm327Service.instance.addListener(_elmChanged);
  }

  @override
  void dispose() {
    MotorcycleService.instance.changes.removeListener(_refresh);
    Elm327Service.instance.removeListener(_elmChanged);
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(
        () => _motorcycles = MotorcycleService.instance.fetchMotorcycles(),
      );
    }
  }

  void _elmChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _addMotorcycle() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AddMotorcycleScreen()));
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        FutureBuilder<List<Motorcycle>>(
          future: _motorcycles,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return SurfaceCard(
                color: MotoMapColors.error.withValues(alpha: 0.08),
                child: Text(
                  'Garage unavailable. ${snapshot.error}',
                  style: const TextStyle(color: MotoMapColors.error),
                ),
              );
            }
            final bikes = snapshot.data ?? const [];
            if (bikes.isEmpty) return const _EmptyGarage();
            return Column(
              children: [
                for (final bike in bikes) ...[
                  _RealMotorcycleCard(bike: bike),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
        PrimaryButton(
          label: 'Add motorcycle',
          icon: Icons.add_rounded,
          secondary: true,
          onPressed: _addMotorcycle,
        ),
        const SizedBox(height: 24),
        const SectionHeader('ELM327 status'),
        const SizedBox(height: 12),
        _ElmStatusCard(service: Elm327Service.instance),
      ],
    );
  }
}

class _EmptyGarage extends StatelessWidget {
  const _EmptyGarage();

  @override
  Widget build(BuildContext context) => SurfaceCard(
    child: Column(
      children: [
        const Icon(
          Icons.two_wheeler_rounded,
          size: 58,
          color: MotoMapColors.primary,
        ),
        const SizedBox(height: 14),
        Text('Add your first motorcycle', style: MotoMapText.title),
        const SizedBox(height: 7),
        Text(
          'MotoMap automatically reconnects to the most recently connected motorcycle.',
          textAlign: TextAlign.center,
          style: MotoMapText.bodyMd.copyWith(
            color: MotoMapColors.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}

class _RealMotorcycleCard extends StatelessWidget {
  const _RealMotorcycleCard({required this.bike});

  final Motorcycle bike;

  @override
  Widget build(BuildContext context) {
    final elm = Elm327Service.instance;
    final connected = elm.motorcycle?.id == bike.id && elm.isConnected;
    final reading = connected && elm.ecuAvailable ? elm.latestSnapshot : null;
    final photoUrl = ImageStorageService.instance.publicUrl(
      ImageStorageService.motorcycleBucket,
      bike.photoPath,
    );
    return SurfaceCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MotorcycleDetailScreen(motorcycle: bike),
        ),
      ),
      borderColor: bike.isPrimary
          ? MotoMapColors.primary.withValues(alpha: 0.4)
          : MotoMapColors.outlineVariant,
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: MotoMapColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: photoUrl.isEmpty
                    ? const Icon(
                        Icons.two_wheeler_rounded,
                        color: MotoMapColors.primary,
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(photoUrl, fit: BoxFit.cover),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bike.displayName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      bike.subtitle,
                      style: const TextStyle(
                        color: MotoMapColors.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              if (bike.isPrimary)
                const AppPill(
                  label: 'PRIMARY',
                  icon: Icons.check_circle_rounded,
                  compact: true,
                ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: _BikeStat(
                  label: 'ELM327',
                  value: connected ? 'Connected' : 'Not connected',
                ),
              ),
              Expanded(
                child: _BikeStat(
                  label: 'RPM',
                  value: reading?.engineRpm?.toStringAsFixed(0) ?? 'N/A',
                ),
              ),
              Expanded(
                child: _BikeStat(
                  label: 'VOLTAGE',
                  value: reading?.controlModuleVoltage == null
                      ? 'N/A'
                      : '${reading!.controlModuleVoltage!.toStringAsFixed(1)} V',
                ),
              ),
            ],
          ),
          if (!bike.isPrimary || !connected) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (!bike.isPrimary)
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () =>
                          MotorcycleService.instance.setPrimary(bike.id),
                      icon: const Icon(Icons.star_outline_rounded, size: 17),
                      label: const Text('Use this motorcycle'),
                    ),
                  ),
                if (!connected)
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () async {
                        if (bike.hasElmAdapter) {
                          try {
                            await Elm327Service.instance.disconnect(
                              manual: false,
                            );
                            await Elm327Service.instance.connectToMotorcycle(
                              bike,
                            );
                          } catch (error) {
                            if (context.mounted) {
                              showAppMessage(
                                context,
                                'ELM327 connection failed. $error',
                              );
                            }
                          }
                        } else {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  Elm327SetupScreen(motorcycle: bike),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.bluetooth_rounded, size: 17),
                      label: const Text('Connect ELM327'),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ElmStatusCard extends StatelessWidget {
  const _ElmStatusCard({required this.service});

  final Elm327Service service;

  @override
  Widget build(BuildContext context) => SurfaceCard(
    child: Column(
      children: [
        Row(
          children: [
            Icon(
              service.isConnected
                  ? Icons.bluetooth_connected_rounded
                  : Icons.bluetooth_disabled_rounded,
              color: service.isConnected
                  ? MotoMapColors.success
                  : MotoMapColors.warning,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service.statusLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    service.motorcycle?.displayName ??
                        'No recently connected motorcycle',
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
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _ConnectionBadge(
                label: 'ELM327',
                value: service.isConnected ? 'CONNECTED' : 'NOT CONNECTED',
                online: service.isConnected,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ConnectionBadge(
                label: 'ECU',
                value: service.ecuAvailable ? 'CONNECTED' : 'NOT CONNECTED',
                online: service.ecuAvailable,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _ConnectionBadge extends StatelessWidget {
  const _ConnectionBadge({
    required this.label,
    required this.value,
    required this.online,
  });

  final String label;
  final String value;
  final bool online;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    decoration: BoxDecoration(
      color: MotoMapColors.surfaceContainer,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: MotoMapColors.outlineVariant),
    ),
    child: Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: online ? MotoMapColors.success : MotoMapColors.warning,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: MotoMapText.labelCaps.copyWith(fontSize: 7)),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: online ? MotoMapColors.success : MotoMapColors.warning,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// Kept temporarily as a visual reference while the remaining mock ride data is migrated.
// ignore: unused_element
class _GarageMock extends StatelessWidget {
  const _GarageMock();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        SurfaceCard(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const MotorcycleDetailScreen()),
          ),
          padding: EdgeInsets.zero,
          borderColor: MotoMapColors.primary.withValues(alpha: 0.25),
          child: Column(
            children: [
              Container(
                height: 150,
                width: double.infinity,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  gradient: RadialGradient(
                    colors: [
                      Color(0xFF39423E),
                      MotoMapColors.surfaceContainerLow,
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.two_wheeler_rounded,
                  size: 86,
                  color: Color(0xFFD5DBD7),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'BMW R1250GS',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Adventure · 2025',
                                style: TextStyle(
                                  color: MotoMapColors.onSurfaceVariant,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        AppPill(
                          label: 'CONNECTED',
                          icon: Icons.bluetooth_connected_rounded,
                          compact: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Row(
                      children: [
                        Expanded(
                          child: _BikeStat(
                            label: 'ODOMETER',
                            value: '14,205 km',
                          ),
                        ),
                        Expanded(
                          child: _BikeStat(label: 'FUEL', value: '65%'),
                        ),
                        Expanded(
                          child: _BikeStat(label: 'RANGE', value: '238 km'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        PrimaryButton(
          label: 'Add motorcycle',
          icon: Icons.add_rounded,
          secondary: true,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddMotorcycleScreen()),
          ),
        ),
        const SizedBox(height: 24),
        const SectionHeader('Garage insights'),
        const SizedBox(height: 12),
        const SurfaceCard(
          child: Row(
            children: [
              Icon(Icons.build_circle_outlined, color: MotoMapColors.warning),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Service due in 795 km',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Oil and filter · Estimated at 15,000 km',
                      style: TextStyle(
                        fontSize: 9,
                        color: MotoMapColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ],
    );
  }
}

class _BikeStat extends StatelessWidget {
  const _BikeStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: MotoMapText.labelCaps.copyWith(fontSize: 7)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}
