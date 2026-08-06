import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/diagnostic_data.dart';
import '../models/motorcycle.dart';
import '../models/motorcycle_catalog.dart';
import '../services/elm327_service.dart';
import '../services/diagnostic_repository.dart';
import '../services/image_storage_service.dart';
import '../services/motorcycle_catalog_service.dart';
import '../services/motorcycle_photo_picker.dart';
import '../services/motorcycle_service.dart';
import '../theme/motomap_colors.dart';
import '../widgets/app_ui.dart';
import 'elm327_setup_screen.dart';

class MotorcycleDetailScreen extends StatefulWidget {
  const MotorcycleDetailScreen({this.motorcycle, super.key});

  final Motorcycle? motorcycle;

  @override
  State<MotorcycleDetailScreen> createState() => _MotorcycleDetailScreenState();
}

class _MotorcycleDetailScreenState extends State<MotorcycleDetailScreen> {
  Motorcycle? _motorcycleOverride;
  String? _photoPathOverride;
  bool _uploadingPhoto = false;
  _MotorcycleDataTab _selectedDataTab = _MotorcycleDataTab.live;
  late Future<(List<DiagnosticHistoryEntry>, MotorcycleUsageSummary)>
  _storedData;

  @override
  void initState() {
    super.initState();
    Elm327Service.instance.addListener(_elmChanged);
    _storedData = _fetchStoredData();
  }

  @override
  void dispose() {
    Elm327Service.instance.removeListener(_elmChanged);
    super.dispose();
  }

  void _elmChanged() {
    if (mounted) setState(() {});
  }

  Future<(List<DiagnosticHistoryEntry>, MotorcycleUsageSummary)>
  _fetchStoredData() async {
    final bike =
        _motorcycleOverride ??
        widget.motorcycle ??
        Elm327Service.instance.motorcycle;
    if (bike == null) {
      return (
        const <DiagnosticHistoryEntry>[],
        const MotorcycleUsageSummary(
          recordedRideCount: 0,
          totalDistanceKm: null,
          totalFuelConsumedLiters: null,
        ),
      );
    }
    final results = await Future.wait<dynamic>([
      DiagnosticRepository.instance.fetchMotorcycleHistory(bike.id),
      DiagnosticRepository.instance.fetchMotorcycleUsageSummary(bike.id),
    ]);
    return (
      results[0] as List<DiagnosticHistoryEntry>,
      results[1] as MotorcycleUsageSummary,
    );
  }

  void _refreshStoredData() {
    setState(() => _storedData = _fetchStoredData());
  }

  @override
  Widget build(BuildContext context) {
    final bike =
        _motorcycleOverride ??
        widget.motorcycle ??
        Elm327Service.instance.motorcycle;
    final elm = Elm327Service.instance;
    final adapterConnected = bike?.id == elm.motorcycle?.id && elm.isConnected;
    final snapshot = adapterConnected && elm.ecuAvailable
        ? elm.latestSnapshot
        : null;
    final photoUrl = ImageStorageService.instance.publicUrl(
      ImageStorageService.motorcycleBucket,
      _photoPathOverride ?? bike?.photoPath,
    );
    return _CenteredPage(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Motorcycle'),
          actions: [
            PopupMenuButton<String>(
              tooltip: 'Motorcycle options',
              onSelected: (value) {
                if (bike == null) return;
                if (value == 'edit') _editMotorcycle(bike);
                if (value == 'delete') _confirmDeleteMotorcycle(bike);
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Edit motorcycle'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline_rounded),
                    title: Text('Delete motorcycle'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
              icon: const Icon(Icons.more_horiz_rounded),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          children: [
            Container(
              height: 205,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const RadialGradient(
                  colors: [
                    Color(0xFF3B4541),
                    MotoMapColors.surfaceContainerLow,
                  ],
                ),
                border: Border.all(color: MotoMapColors.outlineVariant),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (photoUrl.isEmpty)
                    const Icon(
                      Icons.two_wheeler_rounded,
                      size: 106,
                      color: Color(0xFFD2D9D5),
                    )
                  else
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(23),
                        child: Image.network(photoUrl, fit: BoxFit.cover),
                      ),
                    ),
                  Positioned(
                    top: 14,
                    right: 14,
                    child: AppPill(
                      label: adapterConnected
                          ? (elm.ecuAvailable
                                ? 'CONNECTED'
                                : 'ELM327 CONNECTED')
                          : 'NOT CONNECTED',
                      icon: adapterConnected
                          ? Icons.bluetooth_connected_rounded
                          : Icons.bluetooth_disabled_rounded,
                      compact: true,
                      onTap: bike == null
                          ? null
                          : () => _showBluetoothOptions(bike),
                    ),
                  ),
                  if (_uploadingPhoto)
                    const CircularProgressIndicator(strokeWidth: 2),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bike?.displayName ?? 'Motorcycle',
                        style: MotoMapText.headlineMd,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        bike?.subtitle ?? 'No motorcycle selected',
                        style: MotoMapText.bodyMd.copyWith(
                          color: MotoMapColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Change motorcycle photo',
                  onPressed: bike == null || _uploadingPhoto
                      ? null
                      : () => _changePhoto(bike),
                  icon: const Icon(Icons.add_a_photo_outlined, size: 19),
                ),
              ],
            ),
            const SizedBox(height: 22),
            FutureBuilder<
              (List<DiagnosticHistoryEntry>, MotorcycleUsageSummary)
            >(
              future: _storedData,
              builder: (context, storedSnapshot) {
                if (storedSnapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (storedSnapshot.hasError) {
                  return SurfaceCard(
                    color: MotoMapColors.error.withValues(alpha: 0.08),
                    child: Text(
                      'Stored motorcycle data is unavailable. '
                      '${storedSnapshot.error}',
                      style: const TextStyle(color: MotoMapColors.error),
                    ),
                  );
                }
                final data = storedSnapshot.data!;
                return _StoredMotorcycleData(
                  history: data.$1,
                  usage: data.$2,
                  liveSnapshot: snapshot,
                  adapterConnected: adapterConnected,
                  ecuConnected: adapterConnected && elm.ecuAvailable,
                  selectedTab: _selectedDataTab,
                  onTabSelected: (tab) {
                    setState(() => _selectedDataTab = tab);
                  },
                  onOpenHistory: _showHistoryDetails,
                  onRunDiagnostics: bike == null
                      ? null
                      : () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  SystemDiagnosticsScreen(motorcycle: bike),
                            ),
                          );
                          _refreshStoredData();
                        },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changePhoto(Motorcycle motorcycle) async {
    final file = await MotorcyclePhotoPicker.pickAndCrop(context);
    if (file == null || !mounted) return;
    setState(() => _uploadingPhoto = true);
    try {
      final path = await ImageStorageService.instance.uploadMotorcycleImage(
        motorcycle: motorcycle,
        file: file,
      );
      if (!mounted) return;
      setState(() => _photoPathOverride = path);
      showAppMessage(context, 'Motorcycle photo updated.');
    } catch (error) {
      if (!mounted) return;
      showAppMessage(
        context,
        'Could not upload the motorcycle photo. ${error.toString()}',
      );
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _editMotorcycle(Motorcycle motorcycle) async {
    final result = await Navigator.of(context).push<MotorcycleEditResult>(
      MaterialPageRoute(
        builder: (_) => EditMotorcycleScreen(motorcycle: motorcycle),
      ),
    );
    if (result == null || !mounted) return;
    if (result.deleted) {
      Navigator.pop(context, true);
      return;
    }
    final updated = result.motorcycle;
    if (updated == null) return;
    setState(() {
      _motorcycleOverride = updated;
      _photoPathOverride = updated.photoPath;
      _storedData = _fetchStoredData();
    });
  }

  Future<void> _confirmDeleteMotorcycle(Motorcycle motorcycle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete motorcycle?'),
        content: Text(
          'This removes ${motorcycle.displayName} and its stored ride and '
          'diagnostic history. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (Elm327Service.instance.motorcycle?.id == motorcycle.id) {
      await Elm327Service.instance.disconnect();
    }
    await MotorcycleService.instance.deleteMotorcycle(motorcycle.id);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _showBluetoothOptions(Motorcycle motorcycle) async {
    final elm = Elm327Service.instance;
    final connected = elm.motorcycle?.id == motorcycle.id && elm.isConnected;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: MotoMapColors.surfaceContainer,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('ELM327 connection', style: MotoMapText.headlineMd),
              const SizedBox(height: 16),
              _ConnectionStatusRow(
                label: 'ELM327',
                value: connected ? 'CONNECTED' : 'NOT CONNECTED',
                online: connected,
              ),
              const SizedBox(height: 10),
              _ConnectionStatusRow(
                label: 'Motorcycle ECU',
                value: connected && elm.ecuAvailable
                    ? 'CONNECTED'
                    : 'NOT CONNECTED',
                online: connected && elm.ecuAvailable,
              ),
              const SizedBox(height: 18),
              if (motorcycle.hasElmAdapter)
                PrimaryButton(
                  label: connected ? 'Reconnect ELM327' : 'Connect ELM327',
                  icon: Icons.bluetooth_connected_rounded,
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _connectSavedAdapter(motorcycle);
                  },
                )
              else
                PrimaryButton(
                  label: 'Set up ELM327',
                  icon: Icons.bluetooth_searching_rounded,
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _openElmSetup(motorcycle);
                  },
                ),
              const SizedBox(height: 10),
              PrimaryButton(
                label: motorcycle.hasElmAdapter
                    ? 'Choose another adapter'
                    : 'Open adapter setup',
                icon: Icons.settings_bluetooth_rounded,
                secondary: true,
                onPressed: () {
                  Navigator.pop(sheetContext);
                  _openElmSetup(motorcycle);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _connectSavedAdapter(Motorcycle motorcycle) async {
    try {
      await Elm327Service.instance.disconnect(manual: false);
      await Elm327Service.instance.connectToMotorcycle(motorcycle);
    } catch (error) {
      if (mounted) showAppMessage(context, 'ELM327 connection failed. $error');
    }
  }

  Future<void> _openElmSetup(Motorcycle motorcycle) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Elm327SetupScreen(motorcycle: motorcycle),
      ),
    );
    if (mounted) setState(() {});
  }

  void _showHistoryDetails(DiagnosticHistoryEntry entry) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: MotoMapColors.surfaceContainer,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _HistoryDetailsSheet(entry: entry),
    );
  }
}

class _ConnectionStatusRow extends StatelessWidget {
  const _ConnectionStatusRow({
    required this.label,
    required this.value,
    required this.online,
  });

  final String label;
  final String value;
  final bool online;

  @override
  Widget build(BuildContext context) => SurfaceCard(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
    radius: 13,
    child: Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: online ? MotoMapColors.success : MotoMapColors.warning,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: online ? MotoMapColors.success : MotoMapColors.warning,
            fontSize: 9,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

enum _MotorcycleDataTab { live, lastCheck, history }

class _StoredMotorcycleData extends StatelessWidget {
  const _StoredMotorcycleData({
    required this.history,
    required this.usage,
    required this.liveSnapshot,
    required this.adapterConnected,
    required this.ecuConnected,
    required this.selectedTab,
    required this.onTabSelected,
    required this.onOpenHistory,
    required this.onRunDiagnostics,
  });

  final List<DiagnosticHistoryEntry> history;
  final MotorcycleUsageSummary usage;
  final DiagnosticSnapshot? liveSnapshot;
  final bool adapterConnected;
  final bool ecuConnected;
  final _MotorcycleDataTab selectedTab;
  final ValueChanged<_MotorcycleDataTab> onTabSelected;
  final ValueChanged<DiagnosticHistoryEntry> onOpenHistory;
  final VoidCallback? onRunDiagnostics;

  @override
  Widget build(BuildContext context) {
    DiagnosticHistoryEntry? latestResult;
    for (final entry in history) {
      if (entry.healthScore != null) {
        latestResult = entry;
        break;
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          'Overall motorcycle use',
          subtitle: 'Calculated only from completed recorded rides',
        ),
        const SizedBox(height: 12),
        SurfaceCard(
          child: Row(
            children: [
              Expanded(
                child: _UsageValue(
                  label: 'RIDES',
                  value: usage.recordedRideCount.toString(),
                ),
              ),
              Expanded(
                child: _UsageValue(
                  label: 'DISTANCE',
                  value: usage.totalDistanceKm == null
                      ? 'N/A'
                      : '${usage.totalDistanceKm!.toStringAsFixed(1)} km',
                ),
              ),
              Expanded(
                child: _UsageValue(
                  label: 'FUEL USED',
                  value: usage.totalFuelConsumedLiters == null
                      ? 'N/A'
                      : '${usage.totalFuelConsumedLiters!.toStringAsFixed(2)} L',
                ),
              ),
            ],
          ),
        ),
        if (usage.ridesWithEstimatedFuel > 0) ...[
          const SizedBox(height: 7),
          Text(
            '${usage.ridesWithEstimatedFuel} ride(s) include an explicitly labeled fuel estimate because real ECU fuel-rate data was unavailable.',
            style: const TextStyle(
              color: MotoMapColors.warning,
              fontSize: 9,
              height: 1.35,
            ),
          ),
        ],
        const SizedBox(height: 24),
        _MotorcycleDataTabs(selected: selectedTab, onSelected: onTabSelected),
        const SizedBox(height: 16),
        switch (selectedTab) {
          _MotorcycleDataTab.live => _LiveMotorcycleData(
            snapshot: liveSnapshot,
            adapterConnected: adapterConnected,
            ecuConnected: ecuConnected,
          ),
          _MotorcycleDataTab.lastCheck => _LatestMotorcycleCheck(
            latest: latestResult,
            onRunDiagnostics: onRunDiagnostics,
            onOpenHistory: onOpenHistory,
          ),
          _MotorcycleDataTab.history => _MotorcycleHistory(
            history: history,
            onOpenHistory: onOpenHistory,
          ),
        },
      ],
    );
  }
}

class _MotorcycleDataTabs extends StatelessWidget {
  const _MotorcycleDataTabs({required this.selected, required this.onSelected});

  final _MotorcycleDataTab selected;
  final ValueChanged<_MotorcycleDataTab> onSelected;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: MotoMapColors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: MotoMapColors.outlineVariant),
    ),
    child: Row(
      children: [
        _DataTabButton(
          label: 'LIVE',
          selected: selected == _MotorcycleDataTab.live,
          onTap: () => onSelected(_MotorcycleDataTab.live),
        ),
        _DataTabButton(
          label: 'LAST CHECK',
          selected: selected == _MotorcycleDataTab.lastCheck,
          onTap: () => onSelected(_MotorcycleDataTab.lastCheck),
        ),
        _DataTabButton(
          label: 'HISTORY',
          selected: selected == _MotorcycleDataTab.history,
          onTap: () => onSelected(_MotorcycleDataTab.history),
        ),
      ],
    ),
  );
}

class _DataTabButton extends StatelessWidget {
  const _DataTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Material(
      color: selected ? MotoMapColors.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 11),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected
                  ? MotoMapColors.onPrimary
                  : MotoMapColors.onSurfaceVariant,
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    ),
  );
}

class _LiveMotorcycleData extends StatelessWidget {
  const _LiveMotorcycleData({
    required this.snapshot,
    required this.adapterConnected,
    required this.ecuConnected,
  });

  final DiagnosticSnapshot? snapshot;
  final bool adapterConnected;
  final bool ecuConnected;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SurfaceCard(
        child: Column(
          children: [
            _ConnectionStatusRow(
              label: 'ELM327',
              value: adapterConnected ? 'CONNECTED' : 'NOT CONNECTED',
              online: adapterConnected,
            ),
            const SizedBox(height: 8),
            _ConnectionStatusRow(
              label: 'Motorcycle ECU',
              value: ecuConnected ? 'CONNECTED' : 'NOT CONNECTED',
              online: ecuConnected,
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      const SectionHeader(
        'Live motorcycle readings',
        subtitle: 'Values currently reported by the connected ECU',
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: _LargeBikeMetric(
              icon: Icons.speed_rounded,
              label: 'RPM',
              value: snapshot?.engineRpm?.toStringAsFixed(0) ?? 'N/A',
              unit: snapshot?.engineRpm == null ? '' : 'rpm',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _LargeBikeMetric(
              icon: Icons.local_gas_station_outlined,
              label: 'FUEL',
              value: snapshot?.fuelLevelPercent?.toStringAsFixed(0) ?? 'N/A',
              unit: snapshot?.fuelLevelPercent == null ? '' : '%',
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: _LargeBikeMetric(
              icon: Icons.battery_charging_full_rounded,
              label: 'BATTERY',
              value:
                  snapshot?.controlModuleVoltage?.toStringAsFixed(1) ?? 'N/A',
              unit: snapshot?.controlModuleVoltage == null ? '' : 'V',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _LargeBikeMetric(
              icon: Icons.thermostat_rounded,
              label: 'ENGINE',
              value: snapshot?.coolantTemperatureC?.toStringAsFixed(0) ?? 'N/A',
              unit: snapshot?.coolantTemperatureC == null ? '' : '°C',
            ),
          ),
        ],
      ),
      if (!ecuConnected) ...[
        const SizedBox(height: 10),
        const Text(
          'Live values stay N/A until both the ELM327 adapter and ECU respond.',
          style: TextStyle(color: MotoMapColors.onSurfaceVariant, fontSize: 10),
        ),
      ],
    ],
  );
}

class _LatestMotorcycleCheck extends StatelessWidget {
  const _LatestMotorcycleCheck({
    required this.latest,
    required this.onRunDiagnostics,
    required this.onOpenHistory,
  });

  final DiagnosticHistoryEntry? latest;
  final VoidCallback? onRunDiagnostics;
  final ValueChanged<DiagnosticHistoryEntry> onOpenHistory;

  @override
  Widget build(BuildContext context) {
    final score = latest?.healthScore;
    final color = score == null
        ? MotoMapColors.onSurfaceVariant
        : score >= 80
        ? MotoMapColors.success
        : score >= 60
        ? MotoMapColors.warning
        : MotoMapColors.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          'Latest saved check',
          subtitle: latest == null
              ? 'No previous ELM327 check is available'
              : _formatHistoryDate(latest!.startedAt),
        ),
        const SizedBox(height: 12),
        _HealthRow(
          icon: score == null
              ? Icons.help_outline_rounded
              : Icons.monitor_heart_outlined,
          title: 'System diagnostics',
          detail: latest == null
              ? 'Connect the adapter and run a real check'
              : latest!.issues.isEmpty
              ? 'No issues were stored for this check'
              : latest!.issues.join(' '),
          status: score == null
              ? 'N/A'
              : score >= 80
              ? 'GOOD'
              : score >= 60
              ? 'CHECK'
              : 'BAD',
          color: color,
        ),
        const SizedBox(height: 8),
        _HealthRow(
          icon: Icons.bluetooth_connected_rounded,
          title: 'Last ELM327 result',
          detail: latest?.protocol?.trim().isNotEmpty == true
              ? 'Protocol: ${latest!.protocol}'
              : 'No adapter protocol was stored',
          status: latest == null ? 'N/A' : '${latest!.healthScore ?? 0}/100',
          color: color,
        ),
        if (latest != null) ...[
          const SizedBox(height: 10),
          PrimaryButton(
            label: 'View complete last result',
            secondary: true,
            onPressed: () => onOpenHistory(latest!),
          ),
        ],
        const SizedBox(height: 10),
        PrimaryButton(
          label: 'Run a new check',
          icon: Icons.monitor_heart_outlined,
          onPressed: onRunDiagnostics,
        ),
      ],
    );
  }
}

class _MotorcycleHistory extends StatelessWidget {
  const _MotorcycleHistory({
    required this.history,
    required this.onOpenHistory,
  });

  final List<DiagnosticHistoryEntry> history;
  final ValueChanged<DiagnosticHistoryEntry> onOpenHistory;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SectionHeader(
        'Ride & ELM327 history',
        subtitle: 'Previous real readings and diagnostic scores',
      ),
      const SizedBox(height: 12),
      if (history.isEmpty)
        const SurfaceCard(
          child: Text(
            'No ride or diagnostic history yet. Complete a diagnostic check '
            'or recorded ride to create the first entry.',
            textAlign: TextAlign.center,
            style: TextStyle(color: MotoMapColors.onSurfaceVariant),
          ),
        )
      else
        for (final entry in history) ...[
          _HistoryCard(entry: entry, onTap: () => onOpenHistory(entry)),
          const SizedBox(height: 9),
        ],
    ],
  );
}

class _UsageValue extends StatelessWidget {
  const _UsageValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        value,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 4),
      Text(label, style: MotoMapText.labelCaps.copyWith(fontSize: 7)),
    ],
  );
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.entry, required this.onTap});

  final DiagnosticHistoryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SurfaceCard(
    onTap: onTap,
    padding: const EdgeInsets.all(13),
    radius: 15,
    child: Column(
      children: [
        Row(
          children: [
            Icon(
              entry.isRide ? Icons.route_rounded : Icons.monitor_heart_outlined,
              color: MotoMapColors.primary,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.typeLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatHistoryDate(entry.startedAt),
                    style: const TextStyle(
                      color: MotoMapColors.onSurfaceVariant,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              entry.healthScore == null ? 'N/A' : '${entry.healthScore}/100',
              style: const TextStyle(
                color: MotoMapColors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, size: 18),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _HistoryValue(
                label: 'DISTANCE',
                value: entry.distanceKm == null
                    ? 'N/A'
                    : '${entry.distanceKm!.toStringAsFixed(1)} km',
              ),
            ),
            Expanded(
              child: _HistoryValue(
                label: 'FUEL',
                value: entry.fuelConsumedLiters == null
                    ? 'N/A'
                    : '${entry.fuelConsumedLiters!.toStringAsFixed(2)} L',
              ),
            ),
            Expanded(
              child: _HistoryValue(
                label: 'AVG SPEED',
                value: entry.averageSpeedKph == null
                    ? 'N/A'
                    : '${entry.averageSpeedKph!.toStringAsFixed(0)} km/h',
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _HistoryValue extends StatelessWidget {
  const _HistoryValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: MotoMapText.labelCaps.copyWith(fontSize: 6.5)),
      const SizedBox(height: 3),
      Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800),
      ),
    ],
  );
}

class _HistoryDetailsSheet extends StatelessWidget {
  const _HistoryDetailsSheet({required this.entry});

  final DiagnosticHistoryEntry entry;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(entry.typeLabel, style: MotoMapText.headlineMd),
          const SizedBox(height: 4),
          Text(
            _formatHistoryDate(entry.startedAt),
            style: const TextStyle(color: MotoMapColors.onSurfaceVariant),
          ),
          const SizedBox(height: 18),
          if (entry.isRide) ...[
            const SurfaceCard(
              child: Row(
                children: [
                  Icon(
                    Icons.map_outlined,
                    color: MotoMapColors.onSurfaceVariant,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Route map: N/A\nGPS route points were not recorded for '
                      'this ride.',
                      style: TextStyle(
                        color: MotoMapColors.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _HistoryDetailRow(label: 'Start location', value: 'N/A'),
            _HistoryDetailRow(label: 'End location', value: 'N/A'),
            _HistoryDetailRow(
              label: 'Ride duration',
              value: entry.duration == null
                  ? 'N/A'
                  : _formatHistoryDuration(entry.duration!),
            ),
          ],
          _HistoryDetailRow(
            label: 'Ride health score',
            value: entry.healthScore == null
                ? 'N/A'
                : '${entry.healthScore}/100',
          ),
          _HistoryDetailRow(
            label: 'Distance ridden',
            value: entry.distanceKm == null
                ? 'N/A'
                : '${entry.distanceKm!.toStringAsFixed(2)} km',
          ),
          _HistoryDetailRow(
            label: 'Fuel consumed',
            value: entry.fuelConsumedLiters == null
                ? 'N/A'
                : '${entry.fuelConsumedLiters!.toStringAsFixed(3)} L',
          ),
          _HistoryDetailRow(
            label: 'Average / maximum speed',
            value: _pairValue(
              entry.averageSpeedKph,
              entry.maximumSpeedKph,
              'km/h',
            ),
          ),
          _HistoryDetailRow(
            label: 'Average / maximum RPM',
            value: _pairValue(
              entry.averageEngineRpm,
              entry.maximumEngineRpm,
              'rpm',
            ),
          ),
          _HistoryDetailRow(
            label: 'Maximum coolant temperature',
            value: entry.maximumCoolantTemperatureC == null
                ? 'N/A'
                : '${entry.maximumCoolantTemperatureC!.toStringAsFixed(0)} °C',
          ),
          _HistoryDetailRow(
            label: 'Minimum ECU voltage',
            value: entry.minimumControlModuleVoltage == null
                ? 'N/A'
                : '${entry.minimumControlModuleVoltage!.toStringAsFixed(1)} V',
          ),
          _HistoryDetailRow(
            label: 'Ending fuel level',
            value: entry.endingFuelLevelPercent == null
                ? 'N/A'
                : '${entry.endingFuelLevelPercent!.toStringAsFixed(0)}%',
          ),
          _HistoryDetailRow(
            label: 'ELM327 protocol',
            value: entry.protocol?.trim().isNotEmpty == true
                ? entry.protocol!
                : 'N/A',
          ),
          _HistoryDetailRow(
            label: 'Trouble codes',
            value: entry.troubleCodes.isEmpty
                ? (entry.troubleCodeCount == 0 ? 'None recorded' : 'N/A')
                : entry.troubleCodes.join(', '),
          ),
          _HistoryDetailRow(
            label: 'Stored samples',
            value: entry.sampleCount.toString(),
          ),
          if (entry.issues.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Recorded findings',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            for (final issue in entry.issues)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• $issue'),
              ),
          ],
        ],
      ),
    ),
  );

  static String _pairValue(double? average, double? maximum, String unit) {
    if (average == null && maximum == null) return 'N/A';
    final averageText = average?.toStringAsFixed(0) ?? 'N/A';
    final maximumText = maximum?.toStringAsFixed(0) ?? 'N/A';
    return '$averageText / $maximumText $unit';
  }
}

class _HistoryDetailRow extends StatelessWidget {
  const _HistoryDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: MotoMapColors.onSurfaceVariant),
          ),
        ),
        const SizedBox(width: 14),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
}

String _formatHistoryDate(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.year}-$month-$day $hour:$minute';
}

String _formatHistoryDuration(Duration value) {
  final hours = value.inHours;
  final minutes = value.inMinutes.remainder(60);
  final seconds = value.inSeconds.remainder(60);
  if (hours > 0) return '${hours}h ${minutes}m';
  if (minutes > 0) return '${minutes}m ${seconds}s';
  return '${seconds}s';
}

class MotorcycleEditResult {
  const MotorcycleEditResult.saved(this.motorcycle) : deleted = false;
  const MotorcycleEditResult.deleted() : motorcycle = null, deleted = true;

  final Motorcycle? motorcycle;
  final bool deleted;
}

class EditMotorcycleScreen extends StatefulWidget {
  const EditMotorcycleScreen({required this.motorcycle, super.key});

  final Motorcycle motorcycle;

  @override
  State<EditMotorcycleScreen> createState() => _EditMotorcycleScreenState();
}

class _EditMotorcycleScreenState extends State<EditMotorcycleScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nickname;
  late final TextEditingController _make;
  late final TextEditingController _model;
  late final TextEditingController _year;
  late final TextEditingController _engineCc;
  late Motorcycle _currentMotorcycle;
  late String _type;
  late bool _makePrimary;
  MotorcycleCatalogMake? _selectedCatalogMake;
  MotorcycleCatalogModel? _selectedCatalogModel;
  XFile? _selectedPhoto;
  Uint8List? _selectedPhotoBytes;
  bool _saving = false;
  bool _loadingCatalog = false;
  String? _error;

  static const _types = <String, String>{
    'scooter': 'Scooter',
    'standard': 'Standard / naked',
    'sport': 'Sport',
    'cruiser': 'Cruiser',
    'touring': 'Touring',
    'adventure': 'Adventure',
    'dual_sport': 'Dual-sport / off-road',
    'other': 'Other',
  };

  @override
  void initState() {
    super.initState();
    _currentMotorcycle = widget.motorcycle;
    _nickname = TextEditingController(text: widget.motorcycle.nickname ?? '');
    _make = TextEditingController(text: widget.motorcycle.make);
    _model = TextEditingController(text: widget.motorcycle.model);
    _year = TextEditingController(text: widget.motorcycle.modelYear.toString());
    _engineCc = TextEditingController(
      text: widget.motorcycle.engineDisplacementCc?.toString() ?? '',
    );
    _type = _types.containsKey(widget.motorcycle.type)
        ? widget.motorcycle.type
        : 'other';
    _makePrimary = widget.motorcycle.isPrimary;
  }

  @override
  void dispose() {
    _nickname.dispose();
    _make.dispose();
    _model.dispose();
    _year.dispose();
    _engineCc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photoUrl = ImageStorageService.instance.publicUrl(
      ImageStorageService.motorcycleBucket,
      _currentMotorcycle.photoPath,
    );
    return _CenteredPage(
      child: Scaffold(
        appBar: AppBar(title: const Text('Edit motorcycle')),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              GestureDetector(
                onTap: _saving ? null : _pickPhoto,
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    decoration: BoxDecoration(
                      color: MotoMapColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: MotoMapColors.outlineVariant),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (_selectedPhotoBytes != null)
                          Image.memory(_selectedPhotoBytes!, fit: BoxFit.cover)
                        else if (photoUrl.isNotEmpty)
                          Image.network(photoUrl, fit: BoxFit.cover)
                        else
                          const Icon(
                            Icons.two_wheeler_rounded,
                            size: 86,
                            color: MotoMapColors.onSurfaceVariant,
                          ),
                        Positioned(
                          right: 12,
                          bottom: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: MotoMapColors.background.withValues(
                                alpha: 0.86,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.crop_rounded,
                                  color: MotoMapColors.primary,
                                  size: 17,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'CHOOSE & FIT',
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const _FieldLabel('NICKNAME', optional: true),
              const SizedBox(height: 7),
              TextFormField(
                controller: _nickname,
                decoration: const InputDecoration(hintText: 'e.g. Luna'),
              ),
              const SizedBox(height: 18),
              const _FieldLabel('BRAND (MAKE)'),
              const SizedBox(height: 7),
              TextFormField(
                controller: _make,
                validator: _required,
                onChanged: (_) {
                  _selectedCatalogMake = null;
                  _selectedCatalogModel = null;
                },
                decoration: InputDecoration(
                  suffixIcon: IconButton(
                    tooltip: 'Search motorcycle brands',
                    onPressed: _loadingCatalog ? null : _pickCatalogMake,
                    icon: const Icon(Icons.search_rounded),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const _FieldLabel('MODEL'),
              const SizedBox(height: 7),
              TextFormField(
                controller: _model,
                validator: _required,
                onChanged: (_) => _selectedCatalogModel = null,
                decoration: InputDecoration(
                  suffixIcon: IconButton(
                    tooltip: 'Search models for this brand and year',
                    onPressed: _loadingCatalog ? null : _pickCatalogModel,
                    icon: const Icon(Icons.search_rounded),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _FieldLabel('YEAR MODEL'),
                        const SizedBox(height: 7),
                        TextFormField(
                          controller: _year,
                          keyboardType: TextInputType.number,
                          validator: _validYear,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _FieldLabel('ENGINE CC', optional: true),
                        const SizedBox(height: 7),
                        TextFormField(
                          controller: _engineCc,
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return null;
                            }
                            final parsed = int.tryParse(value);
                            return parsed == null ||
                                    parsed < 25 ||
                                    parsed > 5000
                                ? '25–5000 CC'
                                : null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const _FieldLabel('MOTORCYCLE TYPE'),
              const SizedBox(height: 7),
              DropdownButtonFormField<String>(
                initialValue: _type,
                items: [
                  for (final entry in _types.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                ],
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _type = value ?? 'other'),
              ),
              const SizedBox(height: 22),
              SurfaceCard(
                child: SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _makePrimary,
                  onChanged: _currentMotorcycle.isPrimary
                      ? null
                      : (value) => setState(() => _makePrimary = value),
                  title: const Text(
                    'Primary motorcycle',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    _currentMotorcycle.isPrimary
                        ? 'Currently primary. Choose another motorcycle to change it.'
                        : 'New rides will use this motorcycle by default.',
                  ),
                ),
              ),
              const SizedBox(height: 22),
              const SectionHeader(
                'ELM327 adapter',
                subtitle: 'Choose from known Bluetooth devices when switching',
              ),
              const SizedBox(height: 10),
              SurfaceCard(
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        _currentMotorcycle.hasElmAdapter
                            ? Icons.bluetooth_connected_rounded
                            : Icons.bluetooth_disabled_rounded,
                        color: _currentMotorcycle.hasElmAdapter
                            ? MotoMapColors.primary
                            : MotoMapColors.onSurfaceVariant,
                      ),
                      title: Text(
                        _currentMotorcycle.elmDeviceName ??
                            'No adapter configured',
                      ),
                      subtitle: Text(
                        _currentMotorcycle.elmTransport == ElmTransport.ble
                            ? 'Bluetooth LE · No pairing PIN needed'
                            : _currentMotorcycle.elmTransport ==
                                  ElmTransport.bluetoothClassic
                            ? 'Bluetooth Classic'
                            : 'Connect an ELM327 to enable real ECU checks',
                      ),
                    ),
                    const SizedBox(height: 6),
                    PrimaryButton(
                      label: _currentMotorcycle.hasElmAdapter
                          ? 'Connect or change ELM327'
                          : 'Set up ELM327',
                      icon: Icons.bluetooth_searching_rounded,
                      secondary: true,
                      onPressed: _saving ? null : _openElmSetup,
                    ),
                    if (_currentMotorcycle.hasElmAdapter)
                      TextButton(
                        onPressed: _saving ? null : _removeElmAdapter,
                        child: const Text('Remove saved adapter'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: _saving ? 'Saving…' : 'Save changes',
                icon: Icons.save_outlined,
                onPressed: _saving ? null : _save,
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: MotoMapColors.error),
                ),
              ],
              const SizedBox(height: 26),
              TextButton.icon(
                onPressed: _saving ? null : _deleteMotorcycle,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Delete motorcycle'),
                style: TextButton.styleFrom(
                  foregroundColor: MotoMapColors.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;

  static String? _validYear(String? value) {
    final parsed = int.tryParse(value ?? '');
    if (parsed == null || parsed < 1900 || parsed > DateTime.now().year + 1) {
      return 'Enter a valid year';
    }
    return null;
  }

  Future<void> _pickPhoto() async {
    final file = await MotorcyclePhotoPicker.pickAndCrop(context);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _selectedPhoto = file;
      _selectedPhotoBytes = bytes;
      _error = null;
    });
  }

  Future<void> _pickCatalogMake() async {
    setState(() => _loadingCatalog = true);
    try {
      final makes = await MotorcycleCatalogService.instance.fetchMakes();
      if (!mounted) return;
      final selected = await showSearch<MotorcycleCatalogMake?>(
        context: context,
        delegate: _CatalogSearchDelegate<MotorcycleCatalogMake>(
          title: 'Search motorcycle brands',
          items: makes,
          labelOf: (item) => item.name,
        ),
      );
      if (selected == null || !mounted) return;
      setState(() {
        _selectedCatalogMake = selected;
        _selectedCatalogModel = null;
        _make.text = selected.name;
        _model.clear();
      });
    } catch (error) {
      if (mounted) showAppMessage(context, 'Catalog unavailable. $error');
    } finally {
      if (mounted) setState(() => _loadingCatalog = false);
    }
  }

  Future<void> _pickCatalogModel() async {
    final parsedYear = int.tryParse(_year.text);
    if (_make.text.trim().isEmpty || parsedYear == null) {
      showAppMessage(context, 'Choose a brand and valid year first.');
      return;
    }
    setState(() => _loadingCatalog = true);
    try {
      final models = await MotorcycleCatalogService.instance.fetchModels(
        make: _make.text,
        year: parsedYear,
      );
      if (!mounted) return;
      if (models.isEmpty) {
        showAppMessage(context, 'No catalog models found. Enter it manually.');
        return;
      }
      final selected = await showSearch<MotorcycleCatalogModel?>(
        context: context,
        delegate: _CatalogSearchDelegate<MotorcycleCatalogModel>(
          title: 'Search ${_make.text} $parsedYear models',
          items: models,
          labelOf: (item) => item.name,
        ),
      );
      if (selected == null || !mounted) return;
      setState(() {
        _selectedCatalogModel = selected;
        _make.text = selected.makeName;
        _model.text = selected.name;
      });
    } catch (error) {
      if (mounted) showAppMessage(context, 'Catalog unavailable. $error');
    } finally {
      if (mounted) setState(() => _loadingCatalog = false);
    }
  }

  Future<void> _openElmSetup() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Elm327SetupScreen(motorcycle: _currentMotorcycle),
      ),
    );
    if (!mounted) return;
    final refreshed = await MotorcycleService.instance.fetchMotorcycle(
      _currentMotorcycle.id,
    );
    if (!mounted) return;
    setState(() {
      _currentMotorcycle = refreshed;
      _makePrimary = refreshed.isPrimary;
    });
  }

  Future<void> _removeElmAdapter() async {
    await Elm327Service.instance.disconnect();
    await MotorcycleService.instance.removeElmAdapter(_currentMotorcycle.id);
    final refreshed = await MotorcycleService.instance.fetchMotorcycle(
      _currentMotorcycle.id,
    );
    if (!mounted) return;
    setState(() {
      _currentMotorcycle = refreshed;
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      var updated = await MotorcycleService.instance.updateMotorcycle(
        motorcycleId: _currentMotorcycle.id,
        nickname: _nickname.text,
        make: _make.text,
        model: _model.text,
        modelYear: int.parse(_year.text),
        type: _type,
        engineDisplacementCc: _engineCc.text.trim().isEmpty
            ? null
            : int.parse(_engineCc.text),
        catalogSource:
            _selectedCatalogMake != null || _selectedCatalogModel != null
            ? MotorcycleCatalogService.source
            : _currentMotorcycle.catalogSource,
        catalogMakeId:
            _selectedCatalogMake?.id ??
            _selectedCatalogModel?.makeId ??
            _currentMotorcycle.catalogMakeId,
        catalogModelId:
            _selectedCatalogModel?.id ?? _currentMotorcycle.catalogModelId,
        makePrimary: _makePrimary,
      );
      if (_selectedPhoto != null) {
        final path = await ImageStorageService.instance.uploadMotorcycleImage(
          motorcycle: updated,
          file: _selectedPhoto!,
        );
        updated = updated.copyWith(photoPath: path);
      }
      if (!mounted) return;
      Navigator.pop(context, MotorcycleEditResult.saved(updated));
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not save changes. $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteMotorcycle() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete motorcycle?'),
        content: Text(
          'Delete ${_currentMotorcycle.displayName} and all of its stored ride '
          'and diagnostic history? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _saving = true);
    try {
      if (Elm327Service.instance.motorcycle?.id == _currentMotorcycle.id) {
        await Elm327Service.instance.disconnect();
      }
      await MotorcycleService.instance.deleteMotorcycle(_currentMotorcycle.id);
      if (!mounted) return;
      Navigator.pop(context, const MotorcycleEditResult.deleted());
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not delete this motorcycle. $error';
        });
      }
    }
  }
}

class AddMotorcycleScreen extends StatefulWidget {
  const AddMotorcycleScreen({super.key});

  @override
  State<AddMotorcycleScreen> createState() => _AddMotorcycleScreenState();
}

class _AddMotorcycleScreenState extends State<AddMotorcycleScreen> {
  final formKey = GlobalKey<FormState>();
  final nickname = TextEditingController();
  final make = TextEditingController();
  final model = TextEditingController();
  final year = TextEditingController(text: DateTime.now().year.toString());
  MotorcycleCatalogMake? selectedCatalogMake;
  MotorcycleCatalogModel? selectedCatalogModel;
  bool loadingCatalog = false;
  bool saving = false;
  bool makePrimary = false;
  String? saveError;
  XFile? selectedPhoto;
  Uint8List? selectedPhotoBytes;

  @override
  void dispose() {
    nickname.dispose();
    make.dispose();
    model.dispose();
    year.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _CenteredPage(
      child: Scaffold(
        appBar: AppBar(title: const Text('Add motorcycle')),
        body: Form(
          key: formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              GestureDetector(
                onTap: saving ? null : _pickPhoto,
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: MotoMapColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: MotoMapColors.outlineVariant),
                    ),
                    child: selectedPhotoBytes == null
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_a_photo_outlined,
                                color: MotoMapColors.primary,
                                size: 32,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'CHOOSE & FIT PHOTO',
                                style: TextStyle(
                                  color: MotoMapColors.onSurfaceVariant,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          )
                        : Image.memory(selectedPhotoBytes!, fit: BoxFit.cover),
                  ),
                ),
              ),
              const SizedBox(height: 26),
              _FieldLabel('NICKNAME', optional: true),
              const SizedBox(height: 7),
              TextFormField(
                controller: nickname,
                decoration: const InputDecoration(hintText: 'e.g. Luna'),
              ),
              const SizedBox(height: 18),
              const _FieldLabel('BRAND (MAKE)'),
              const SizedBox(height: 7),
              TextFormField(
                controller: make,
                validator: _required,
                onChanged: (_) {
                  selectedCatalogMake = null;
                  selectedCatalogModel = null;
                  model.clear();
                },
                decoration: InputDecoration(
                  hintText: 'e.g. Honda',
                  suffixIcon: IconButton(
                    tooltip: 'Search motorcycle brands',
                    onPressed: loadingCatalog ? null : _pickCatalogMake,
                    icon: loadingCatalog
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search_rounded),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const _FieldLabel('MODEL'),
              const SizedBox(height: 7),
              TextFormField(
                controller: model,
                validator: _required,
                onChanged: (_) => selectedCatalogModel = null,
                decoration: InputDecoration(
                  hintText: 'e.g. PCX160',
                  suffixIcon: IconButton(
                    tooltip: 'Search models for this brand and year',
                    onPressed: loadingCatalog ? null : _pickCatalogModel,
                    icon: const Icon(Icons.search_rounded),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const _FieldLabel('YEAR MODEL'),
              const SizedBox(height: 7),
              TextFormField(
                controller: year,
                onChanged: (_) {
                  selectedCatalogModel = null;
                  model.clear();
                },
                validator: (value) {
                  final parsed = int.tryParse(value ?? '');
                  if (parsed == null ||
                      parsed < 1900 ||
                      parsed > DateTime.now().year + 1) {
                    return 'Enter a valid year';
                  }
                  return null;
                },
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: '2025'),
              ),
              const SizedBox(height: 8),
              Text(
                'Use the search buttons to autofill from the NHTSA motorcycle '
                'catalog, or type a motorcycle manually if it is not listed.',
                style: MotoMapText.bodyMd.copyWith(
                  color: MotoMapColors.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 18),
              SurfaceCard(
                child: SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: makePrimary,
                  onChanged: saving
                      ? null
                      : (value) => setState(() => makePrimary = value),
                  title: const Text(
                    'Make this my primary motorcycle',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text(
                    'MotoMap will use it for new rides by default.',
                  ),
                ),
              ),
              const SizedBox(height: 22),
              PrimaryButton(
                label: saving ? 'Saving motorcycle…' : 'Add motorcycle',
                icon: Icons.add_rounded,
                onPressed: saving ? null : _save,
              ),
              if (saveError != null) ...[
                const SizedBox(height: 12),
                Text(
                  saveError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: MotoMapColors.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;

  Future<void> _pickPhoto() async {
    final file = await MotorcyclePhotoPicker.pickAndCrop(context);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      selectedPhoto = file;
      selectedPhotoBytes = bytes;
      saveError = null;
    });
  }

  Future<void> _pickCatalogMake() async {
    setState(() => loadingCatalog = true);
    try {
      final makes = await MotorcycleCatalogService.instance.fetchMakes();
      if (!mounted) return;
      final selected = await showSearch<MotorcycleCatalogMake?>(
        context: context,
        delegate: _CatalogSearchDelegate<MotorcycleCatalogMake>(
          title: 'Search motorcycle brands',
          items: makes,
          labelOf: (item) => item.name,
        ),
      );
      if (selected == null || !mounted) return;
      setState(() {
        selectedCatalogMake = selected;
        selectedCatalogModel = null;
        make.text = selected.name;
        model.clear();
        saveError = null;
      });
    } catch (error) {
      if (mounted) {
        showAppMessage(
          context,
          'Catalog unavailable. You can still type the brand manually. $error',
        );
      }
    } finally {
      if (mounted) setState(() => loadingCatalog = false);
    }
  }

  Future<void> _pickCatalogModel() async {
    final parsedYear = int.tryParse(year.text);
    if (make.text.trim().isEmpty || parsedYear == null) {
      showAppMessage(context, 'Choose a brand and valid year first.');
      return;
    }
    setState(() => loadingCatalog = true);
    try {
      final models = await MotorcycleCatalogService.instance.fetchModels(
        make: make.text,
        year: parsedYear,
      );
      if (!mounted) return;
      if (models.isEmpty) {
        showAppMessage(
          context,
          'No catalog models were found. Enter the model manually.',
        );
        return;
      }
      final selected = await showSearch<MotorcycleCatalogModel?>(
        context: context,
        delegate: _CatalogSearchDelegate<MotorcycleCatalogModel>(
          title: 'Search ${make.text} $parsedYear models',
          items: models,
          labelOf: (item) => item.name,
        ),
      );
      if (selected == null || !mounted) return;
      setState(() {
        selectedCatalogModel = selected;
        make.text = selected.makeName;
        model.text = selected.name;
        saveError = null;
      });
    } catch (error) {
      if (mounted) {
        showAppMessage(
          context,
          'Catalog unavailable. You can still type the model manually. $error',
        );
      }
    } finally {
      if (mounted) setState(() => loadingCatalog = false);
    }
  }

  Future<void> _save() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    setState(() {
      saving = true;
      saveError = null;
    });
    try {
      var motorcycle = await MotorcycleService.instance.createMotorcycle(
        NewMotorcycle(
          nickname: nickname.text,
          make: make.text,
          model: model.text,
          modelYear: int.parse(year.text),
          type: 'other',
          catalogSource:
              selectedCatalogMake != null || selectedCatalogModel != null
              ? MotorcycleCatalogService.source
              : null,
          catalogMakeId:
              selectedCatalogMake?.id ?? selectedCatalogModel?.makeId,
          catalogModelId: selectedCatalogModel?.id,
          makePrimary: makePrimary,
        ),
      );
      String? photoWarning;
      if (selectedPhoto != null) {
        try {
          final path = await ImageStorageService.instance.uploadMotorcycleImage(
            motorcycle: motorcycle,
            file: selectedPhoto!,
          );
          motorcycle = motorcycle.copyWith(photoPath: path);
        } catch (error) {
          photoWarning =
              'The motorcycle was saved, but its photo did not finish uploading. You can try again from the motorcycle screen.';
        }
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => BikeAddedScreen(
            motorcycle: motorcycle,
            photoWarning: photoWarning,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(
        () => saveError = 'Could not save this motorcycle. ${error.toString()}',
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}

class BikeAddedScreen extends StatelessWidget {
  const BikeAddedScreen({
    required this.motorcycle,
    this.photoWarning,
    super.key,
  });

  final Motorcycle motorcycle;
  final String? photoWarning;

  @override
  Widget build(BuildContext context) {
    final photoUrl = ImageStorageService.instance.publicUrl(
      ImageStorageService.motorcycleBucket,
      motorcycle.photoPath,
    );
    return _CenteredPage(
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Spacer(),
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: MotoMapColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: MotoMapColors.primary.withValues(alpha: 0.35),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 36,
                    color: MotoMapColors.primary,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Bike Added!',
                  style: MotoMapText.headlineLg.copyWith(
                    color: MotoMapColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your garage is expanding. Ready to hit the road?',
                  textAlign: TextAlign.center,
                  style: MotoMapText.bodyMd.copyWith(
                    color: MotoMapColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 28),
                SurfaceCard(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    children: [
                      Container(
                        height: 132,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: MotoMapColors.surfaceContainer,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: photoUrl.isEmpty
                            ? const Icon(
                                Icons.two_wheeler_rounded,
                                size: 78,
                                color: Color(0xFFD3DAD6),
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.network(
                                  photoUrl,
                                  fit: BoxFit.cover,
                                ),
                              ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        motorcycle.displayName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '▣  ${motorcycle.modelYear} Model',
                        style: const TextStyle(
                          color: MotoMapColors.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                if (photoWarning != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    photoWarning!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: MotoMapColors.warning),
                  ),
                ],
                const Spacer(),
                PrimaryButton(
                  label: 'Go to Garage',
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(height: 10),
                PrimaryButton(
                  label: 'Set up ELM327',
                  icon: Icons.bluetooth_rounded,
                  secondary: true,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => Elm327SetupScreen(motorcycle: motorcycle),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SystemDiagnosticsScreen extends StatefulWidget {
  const SystemDiagnosticsScreen({this.motorcycle, super.key});

  final Motorcycle? motorcycle;

  @override
  State<SystemDiagnosticsScreen> createState() =>
      _SystemDiagnosticsScreenState();
}

class _SystemDiagnosticsScreenState extends State<SystemDiagnosticsScreen> {
  bool scanning = false;
  DiagnosticReport? report;
  String? scanError;

  Future<void> _scan() async {
    setState(() {
      scanning = true;
      scanError = null;
    });
    try {
      final bike = widget.motorcycle ?? Elm327Service.instance.motorcycle;
      if (bike == null) throw StateError('Add a motorcycle first.');
      if (!bike.hasElmAdapter) {
        throw StateError('Connect an ELM327 adapter to this motorcycle first.');
      }
      await Elm327Service.instance.connectToMotorcycle(bike);
      final result = await Elm327Service.instance.runDiagnostic(
        type: DiagnosticSessionType.preRide,
      );
      if (mounted) setState(() => report = result);
    } catch (error) {
      if (mounted) {
        setState(
          () => scanError = error.toString().replaceFirst('Bad state: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => scanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _CenteredPage(
      child: Scaffold(
        appBar: AppBar(title: const Text('System diagnostics')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            SurfaceCard(
              color: const Color(0xFF13211B),
              borderColor: MotoMapColors.success.withValues(alpha: 0.24),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: MotoMapColors.success.withValues(alpha: 0.13),
                      shape: BoxShape.circle,
                    ),
                    child: scanning
                        ? const Padding(
                            padding: EdgeInsets.all(19),
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: MotoMapColors.success,
                            ),
                          )
                        : Icon(
                            report == null
                                ? Icons.bluetooth_searching_rounded
                                : report!.issues.isEmpty
                                ? Icons.check_circle_outline_rounded
                                : Icons.warning_amber_rounded,
                            size: 34,
                            color: report?.issues.isNotEmpty == true
                                ? MotoMapColors.warning
                                : MotoMapColors.success,
                          ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    scanning
                        ? 'Scanning systems…'
                        : report == null
                        ? 'Ready to check'
                        : 'Ride health ${report!.healthScore}/100',
                    style: MotoMapText.headlineMd,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    scanning
                        ? 'Reading supported ECU sensors and trouble codes'
                        : report == null
                        ? Elm327Service.instance.statusLabel
                        : report!.issues.isEmpty
                        ? 'No issues were detected in the supported ECU data.'
                        : report!.issues.join(' '),
                    textAlign: TextAlign.center,
                    style: MotoMapText.bodyMd.copyWith(
                      color: MotoMapColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _DiagnosticRow(
              icon: Icons.battery_charging_full_rounded,
              title: 'Battery',
              value: report?.snapshot.controlModuleVoltage == null
                  ? 'N/A'
                  : '${report!.snapshot.controlModuleVoltage!.toStringAsFixed(1)} V',
              detail: 'Control-module voltage reported by the ECU',
            ),
            const SizedBox(height: 8),
            _DiagnosticRow(
              icon: Icons.thermostat_rounded,
              title: 'Engine temperature',
              value: report?.snapshot.coolantTemperatureC == null
                  ? 'N/A'
                  : '${report!.snapshot.coolantTemperatureC!.toStringAsFixed(0)} °C',
              detail: 'Shown only when this PID is supported',
            ),
            const SizedBox(height: 8),
            _DiagnosticRow(
              icon: Icons.speed_rounded,
              title: 'Engine speed',
              value: report?.snapshot.engineRpm == null
                  ? 'N/A'
                  : '${report!.snapshot.engineRpm!.toStringAsFixed(0)} rpm',
              detail: 'Live engine RPM',
            ),
            const SizedBox(height: 8),
            _DiagnosticRow(
              icon: Icons.memory_rounded,
              title: 'ECU',
              value: report == null
                  ? 'N/A'
                  : report!.troubleCodes.isEmpty
                  ? 'NO DTC'
                  : '${report!.troubleCodes.length} DTC',
              detail: report?.protocol ?? 'Protocol not detected yet',
            ),
            if (report?.troubleCodes.isNotEmpty == true) ...[
              const SizedBox(height: 18),
              const SectionHeader('Diagnostic trouble codes'),
              const SizedBox(height: 10),
              for (final code in report!.troubleCodes) ...[
                SurfaceCard(
                  borderColor: MotoMapColors.error.withValues(alpha: 0.3),
                  child: Row(
                    children: [
                      Text(
                        code.code,
                        style: const TextStyle(
                          color: MotoMapColors.error,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          code.description ??
                              'Manufacturer service information required',
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              PrimaryButton(
                label: 'Clear trouble codes',
                icon: Icons.delete_sweep_outlined,
                secondary: true,
                onPressed: _confirmClearCodes,
              ),
            ],
            if (scanError != null) ...[
              const SizedBox(height: 12),
              Text(
                scanError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: MotoMapColors.error),
              ),
            ],
            const SizedBox(height: 20),
            PrimaryButton(
              label: scanning ? 'Scanning…' : 'Run diagnostics again',
              icon: Icons.refresh_rounded,
              onPressed: scanning ? null : _scan,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmClearCodes() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear ECU trouble codes?'),
        content: const Text(
          'Save or photograph the codes first. Clearing them can reset readiness information and does not repair the underlying fault.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear codes'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await Elm327Service.instance.clearTroubleCodes();
      await _scan();
    } catch (error) {
      if (mounted) setState(() => scanError = '$error');
    }
  }
}

class _CenteredPage extends StatelessWidget {
  const _CenteredPage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: child,
      ),
    );
  }
}

class _LargeBikeMetric extends StatelessWidget {
  const _LargeBikeMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
  });

  final IconData icon;
  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: MotoMapColors.primary),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  unit,
                  style: const TextStyle(
                    fontSize: 9,
                    color: MotoMapColors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(label, style: MotoMapText.labelCaps.copyWith(fontSize: 8)),
        ],
      ),
    );
  }
}

class _HealthRow extends StatelessWidget {
  const _HealthRow({
    required this.icon,
    required this.title,
    required this.detail,
    required this.status,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String detail;
  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(13),
      radius: 15,
      child: Row(
        children: [
          Icon(icon, color: color, size: 21),
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
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          Text(
            status,
            style: MotoMapText.labelCaps.copyWith(color: color, fontSize: 8),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label, {this.optional = false});

  final String label;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    return Text(
      optional ? '$label  ·  OPTIONAL' : label,
      style: MotoMapText.labelCaps.copyWith(fontSize: 9),
    );
  }
}

class _CatalogSearchDelegate<T> extends SearchDelegate<T?> {
  _CatalogSearchDelegate({
    required this.title,
    required this.items,
    required this.labelOf,
  }) : super(searchFieldLabel: title);

  final String title;
  final List<T> items;
  final String Function(T item) labelOf;

  @override
  List<Widget>? buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      IconButton(
        tooltip: 'Clear search',
        onPressed: () => query = '',
        icon: const Icon(Icons.clear_rounded),
      ),
  ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    tooltip: 'Back',
    onPressed: () => close(context, null),
    icon: const Icon(Icons.arrow_back_rounded),
  );

  @override
  Widget buildResults(BuildContext context) => _results(context);

  @override
  Widget buildSuggestions(BuildContext context) => _results(context);

  Widget _results(BuildContext context) {
    final normalized = query.trim().toLowerCase();
    final matches = normalized.isEmpty
        ? items
        : items
              .where((item) => labelOf(item).toLowerCase().contains(normalized))
              .toList(growable: false);
    if (matches.isEmpty) {
      return const Center(child: Text('No catalog matches found.'));
    }
    return ListView.separated(
      itemCount: matches.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = matches[index];
        return ListTile(
          leading: const Icon(
            Icons.two_wheeler_rounded,
            color: MotoMapColors.primary,
          ),
          title: Text(labelOf(item)),
          onTap: () => close(context, item),
        );
      },
    );
  }
}

class _DiagnosticRow extends StatelessWidget {
  const _DiagnosticRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      radius: 16,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: MotoMapColors.success.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: MotoMapColors.success, size: 20),
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
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: MotoMapColors.success,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
