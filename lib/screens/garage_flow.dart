import 'package:flutter/material.dart';

import '../theme/motomap_colors.dart';
import '../widgets/app_ui.dart';

class MotorcycleDetailScreen extends StatelessWidget {
  const MotorcycleDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _CenteredPage(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Motorcycle'),
          actions: [
            IconButton(
              onPressed: () => showAppMessage(context, 'Motorcycle settings'),
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
                  const Icon(
                    Icons.two_wheeler_rounded,
                    size: 106,
                    color: Color(0xFFD2D9D5),
                  ),
                  Positioned(
                    top: 14,
                    right: 14,
                    child: AppPill(
                      label: 'ONLINE',
                      icon: Icons.bluetooth_connected_rounded,
                      compact: true,
                    ),
                  ),
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
                      Text('BMW R1250GS', style: MotoMapText.headlineMd),
                      const SizedBox(height: 4),
                      Text(
                        'Luna · 2025 Adventure',
                        style: MotoMapText.bodyMd.copyWith(
                          color: MotoMapColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: () => showAppMessage(context, 'Edit motorcycle'),
                  icon: const Icon(Icons.edit_outlined, size: 19),
                ),
              ],
            ),
            const SizedBox(height: 22),
            const Row(
              children: [
                Expanded(
                  child: _LargeBikeMetric(
                    icon: Icons.speed_rounded,
                    label: 'ODOMETER',
                    value: '14,205',
                    unit: 'km',
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _LargeBikeMetric(
                    icon: Icons.local_gas_station_outlined,
                    label: 'FUEL',
                    value: '65',
                    unit: '%',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Row(
              children: [
                Expanded(
                  child: _LargeBikeMetric(
                    icon: Icons.battery_charging_full_rounded,
                    label: 'BATTERY',
                    value: '12.8',
                    unit: 'V',
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _LargeBikeMetric(
                    icon: Icons.thermostat_rounded,
                    label: 'ENGINE',
                    value: '88',
                    unit: '°C',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const SectionHeader(
              'Health & maintenance',
              subtitle: 'Updated a few seconds ago',
            ),
            const SizedBox(height: 12),
            const _HealthRow(
              icon: Icons.check_circle_rounded,
              title: 'System diagnostics',
              detail: 'All systems normal',
              status: 'GOOD',
              color: MotoMapColors.success,
            ),
            const SizedBox(height: 8),
            const _HealthRow(
              icon: Icons.build_outlined,
              title: 'Next service',
              detail: 'Oil and filter at 15,000 km',
              status: '795 KM',
              color: MotoMapColors.warning,
            ),
            const SizedBox(height: 8),
            const _HealthRow(
              icon: Icons.tire_repair_outlined,
              title: 'Tire pressure',
              detail: 'Front 36 · Rear 42 PSI',
              status: 'GOOD',
              color: MotoMapColors.success,
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Run full diagnostics',
              icon: Icons.monitor_heart_outlined,
              secondary: true,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SystemDiagnosticsScreen(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
  final make = TextEditingController(text: 'BMW');
  final model = TextEditingController(text: 'R1250GS');
  final year = TextEditingController(text: '2025');
  int type = 0;

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
              Center(
                child: GestureDetector(
                  onTap: () => showAppMessage(context, 'Choose a bike photo.'),
                  child: Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      color: MotoMapColors.surfaceContainerLow,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: MotoMapColors.outline,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_a_photo_outlined,
                          color: MotoMapColors.primary,
                        ),
                        SizedBox(height: 6),
                        Text(
                          'ADD PHOTO',
                          style: TextStyle(
                            color: MotoMapColors.onSurfaceVariant,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
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
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _FieldLabel('MAKE'),
                        const SizedBox(height: 7),
                        TextFormField(
                          controller: make,
                          validator: _required,
                          decoration: const InputDecoration(hintText: 'BMW'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _FieldLabel('MODEL'),
                        const SizedBox(height: 7),
                        TextFormField(
                          controller: model,
                          validator: _required,
                          decoration: const InputDecoration(
                            hintText: 'R1250GS',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const _FieldLabel('YEAR'),
              const SizedBox(height: 7),
              TextFormField(
                controller: year,
                validator: (value) {
                  final parsed = int.tryParse(value ?? '');
                  if (parsed == null || parsed < 1900 || parsed > 2030) {
                    return 'Enter a valid year';
                  }
                  return null;
                },
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: '2025'),
              ),
              const SizedBox(height: 18),
              const _FieldLabel('MOTORCYCLE TYPE'),
              const SizedBox(height: 9),
              Row(
                children: [
                  Expanded(
                    child: _TypeOption(
                      icon: Icons.landscape_outlined,
                      label: 'Adventure',
                      selected: type == 0,
                      onTap: () => setState(() => type = 0),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: _TypeOption(
                      icon: Icons.sports_motorsports_outlined,
                      label: 'Sport',
                      selected: type == 1,
                      onTap: () => setState(() => type = 1),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: _TypeOption(
                      icon: Icons.luggage_outlined,
                      label: 'Touring',
                      selected: type == 2,
                      onTap: () => setState(() => type = 2),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              PrimaryButton(
                label: 'Add motorcycle',
                icon: Icons.add_rounded,
                onPressed: () {
                  if (!(formKey.currentState?.validate() ?? false)) return;
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => BikeAddedScreen(
                        name: '${make.text} ${model.text}',
                        year: year.text,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;
}

class BikeAddedScreen extends StatelessWidget {
  const BikeAddedScreen({required this.name, required this.year, super.key});

  final String name;
  final String year;

  @override
  Widget build(BuildContext context) {
    return _CenteredPage(
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Spacer(),
                Container(
                  width: 88,
                  height: 88,
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
                    size: 42,
                    color: MotoMapColors.primary,
                  ),
                ),
                const SizedBox(height: 24),
                Text('Bike added', style: MotoMapText.headlineLg),
                const SizedBox(height: 8),
                Text(
                  'Your garage is growing. This motorcycle is ready for routes and diagnostics.',
                  textAlign: TextAlign.center,
                  style: MotoMapText.bodyMd.copyWith(
                    color: MotoMapColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 28),
                SurfaceCard(
                  child: Column(
                    children: [
                      const SizedBox(
                        height: 108,
                        child: Icon(
                          Icons.two_wheeler_rounded,
                          size: 78,
                          color: Color(0xFFD3DAD6),
                        ),
                      ),
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$year model',
                        style: const TextStyle(
                          color: MotoMapColors.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                PrimaryButton(
                  label: 'Back to garage',
                  icon: Icons.garage_outlined,
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(height: 10),
                PrimaryButton(
                  label: 'Set up diagnostics',
                  icon: Icons.bluetooth_rounded,
                  secondary: true,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SystemDiagnosticsScreen(),
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
  const SystemDiagnosticsScreen({super.key});

  @override
  State<SystemDiagnosticsScreen> createState() =>
      _SystemDiagnosticsScreenState();
}

class _SystemDiagnosticsScreenState extends State<SystemDiagnosticsScreen> {
  bool scanning = false;

  Future<void> _scan() async {
    setState(() => scanning = true);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (mounted) setState(() => scanning = false);
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
                        : const Icon(
                            Icons.check_circle_outline_rounded,
                            size: 34,
                            color: MotoMapColors.success,
                          ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    scanning ? 'Scanning systems…' : 'Ready to ride',
                    style: MotoMapText.headlineMd,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    scanning
                        ? 'Reading live motorcycle data'
                        : 'All connected systems are operating normally.',
                    textAlign: TextAlign.center,
                    style: MotoMapText.bodyMd.copyWith(
                      color: MotoMapColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const _DiagnosticRow(
              icon: Icons.battery_charging_full_rounded,
              title: 'Battery',
              value: '12.8 V',
              detail: 'Charging normally',
            ),
            const SizedBox(height: 8),
            const _DiagnosticRow(
              icon: Icons.thermostat_rounded,
              title: 'Engine temperature',
              value: '88 °C',
              detail: 'Normal range',
            ),
            const SizedBox(height: 8),
            const _DiagnosticRow(
              icon: Icons.tire_repair_outlined,
              title: 'Tire pressure',
              value: '36 / 42',
              detail: 'Front / rear PSI',
            ),
            const SizedBox(height: 8),
            const _DiagnosticRow(
              icon: Icons.memory_rounded,
              title: 'ECU',
              value: 'OK',
              detail: 'No fault codes',
            ),
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

class _TypeOption extends StatelessWidget {
  const _TypeOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 80,
        decoration: BoxDecoration(
          color: selected
              ? MotoMapColors.primary.withValues(alpha: 0.10)
              : MotoMapColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? MotoMapColors.primary
                : MotoMapColors.outlineVariant,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 21,
              color: selected
                  ? MotoMapColors.primary
                  : MotoMapColors.onSurfaceVariant,
            ),
            const SizedBox(height: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: selected
                    ? MotoMapColors.onSurface
                    : MotoMapColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
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
