import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial_plus/flutter_bluetooth_serial_plus.dart';

import '../models/motorcycle.dart';
import '../services/elm327_service.dart';
import '../services/motorcycle_service.dart';
import '../theme/motomap_colors.dart';
import '../widgets/app_ui.dart';

class Elm327SetupScreen extends StatefulWidget {
  const Elm327SetupScreen({required this.motorcycle, super.key});

  final Motorcycle motorcycle;

  @override
  State<Elm327SetupScreen> createState() => _Elm327SetupScreenState();
}

class _Elm327SetupScreenState extends State<Elm327SetupScreen>
    with SingleTickerProviderStateMixin {
  late Future<List<ElmDeviceOption>> _devices;
  late final AnimationController _radarController;
  ElmDeviceOption? _selectedDevice;
  bool _connecting = false;
  bool _complete = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    _devices = Elm327Service.instance.availableDevices();
  }

  @override
  void dispose() {
    _radarController.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _error = null;
      _selectedDevice = null;
      _devices = Elm327Service.instance.availableDevices();
    });
  }

  Future<void> _connectSelected() async {
    final device = _selectedDevice;
    if (device == null || _connecting) return;
    setState(() {
      _connecting = true;
      _error = null;
    });

    final configured = widget.motorcycle.copyWith(
      elmDeviceName: device.name,
      elmDeviceIdentifier: device.identifier,
      elmTransport: device.transport,
      elmAutoConnect: true,
    );

    try {
      await WidgetsBinding.instance.endOfFrame;
      await Elm327Service.instance.reconnectToMotorcycle(configured);
      await MotorcycleService.instance.saveElmAdapter(
        motorcycleId: widget.motorcycle.id,
        deviceName: device.name,
        deviceIdentifier: device.identifier,
        transport: device.transport,
      );
      if (!mounted) return;
      setState(() => _complete = true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Bad state: ', '');
      });
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _chooseAnother() async {
    await Elm327Service.instance.disconnect();
    if (!mounted) return;
    setState(() {
      _complete = false;
      _selectedDevice = null;
      _error = null;
    });
  }

  void _showHelp() {
    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ELM327 setup help'),
        content: Text(
          kIsWeb
              ? 'Safari cannot provide the native Bluetooth LE connection '
                    'MotoMap needs. Install a signed iPhone build, then scan '
                    'from inside the app.'
              : 'Plug the adapter into the motorcycle diagnostic cable, turn '
                    'the ignition on, close any other scanner app using it, '
                    'then refresh. Bluetooth LE adapters such as OBDBLE do '
                    'not need a PIN or pairing in iPhone Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (isAndroid)
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                FlutterBluetoothSerial.instance.openSettings();
              },
              child: const Text('Bluetooth settings'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close',
          onPressed: _connecting
              ? null
              : () => Navigator.pop(context, _complete),
          icon: const Icon(Icons.close_rounded),
        ),
        title: const Text('Setup Adapter'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Setup help',
            onPressed: _connecting ? null : _showHelp,
            icon: const Icon(Icons.help_outline_rounded),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                _SetupProgress(
                  currentStep: _connecting
                      ? 1
                      : _complete && Elm327Service.instance.ecuAvailable
                      ? 2
                      : _complete
                      ? 1
                      : 0,
                ),
                Expanded(
                  child: _connecting
                      ? _VerificationBody(motorcycle: widget.motorcycle)
                      : _complete
                      ? _ConnectionResult(
                          motorcycle: widget.motorcycle,
                          onRetry: _connectSelected,
                          onChooseAnother: _chooseAnother,
                          onDone: () => Navigator.pop(context, true),
                        )
                      : _ScannerBody(
                          motorcycle: widget.motorcycle,
                          devices: _devices,
                          selectedDevice: _selectedDevice,
                          radarController: _radarController,
                          connecting: _connecting,
                          error: _error,
                          onRefresh: _refresh,
                          onSelected: (device) {
                            setState(() {
                              _selectedDevice = device;
                              _error = null;
                            });
                          },
                          onTroubleshoot: _showHelp,
                          onNext: _selectedDevice == null || _connecting
                              ? null
                              : _connectSelected,
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

class _SetupProgress extends StatelessWidget {
  const _SetupProgress({required this.currentStep});

  final int currentStep;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(54, 2, 54, 8),
    child: Row(
      children: [
        for (var index = 0; index < 3; index++) ...[
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: 3,
              decoration: BoxDecoration(
                color: index <= currentStep
                    ? MotoMapColors.primary
                    : MotoMapColors.outlineVariant,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          if (index < 2) const SizedBox(width: 6),
        ],
      ],
    ),
  );
}

class _VerificationBody extends StatelessWidget {
  const _VerificationBody({required this.motorcycle});

  final Motorcycle motorcycle;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Elm327Service.instance,
    builder: (context, _) {
      final elm = Elm327Service.instance;
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 34, 20, 24),
        children: [
          const Center(
            child: SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(strokeWidth: 4),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Verifying connection',
            textAlign: TextAlign.center,
            style: MotoMapText.headlineMd,
          ),
          const SizedBox(height: 8),
          Text(
            'MotoMap is checking the ELM327 and requesting one valid response '
            'from ${motorcycle.displayName}.',
            textAlign: TextAlign.center,
            style: MotoMapText.bodyMd.copyWith(
              color: MotoMapColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 26),
          SurfaceCard(
            child: Column(
              children: [
                _ConnectionRow(
                  label: 'ELM327',
                  value: elm.adapterConnected ? 'CONNECTED' : 'CONNECTING',
                  online: elm.adapterConnected,
                ),
                const Divider(height: 24),
                _ConnectionRow(
                  label: 'Motorcycle ECU',
                  value: elm.ecuAvailable ? 'CONNECTED' : 'CHECKING',
                  online: elm.ecuAvailable,
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
}

class _ScannerBody extends StatelessWidget {
  const _ScannerBody({
    required this.motorcycle,
    required this.devices,
    required this.selectedDevice,
    required this.radarController,
    required this.connecting,
    required this.error,
    required this.onRefresh,
    required this.onSelected,
    required this.onTroubleshoot,
    required this.onNext,
  });

  final Motorcycle motorcycle;
  final Future<List<ElmDeviceOption>> devices;
  final ElmDeviceOption? selectedDevice;
  final Animation<double> radarController;
  final bool connecting;
  final String? error;
  final VoidCallback onRefresh;
  final ValueChanged<ElmDeviceOption> onSelected;
  final VoidCallback onTroubleshoot;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    if (!Elm327Service.instance.isSupportedPlatform) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
        children: [
          const Icon(
            Icons.bluetooth_disabled_rounded,
            size: 64,
            color: MotoMapColors.warning,
          ),
          const SizedBox(height: 18),
          Text(
            kIsWeb
                ? 'Native app required for Bluetooth'
                : 'Bluetooth unavailable',
            textAlign: TextAlign.center,
            style: MotoMapText.headlineMd,
          ),
          const SizedBox(height: 10),
          Text(
            kIsWeb
                ? 'This Safari page cannot scan your OBDBLE adapter. Your '
                      'Kingbolen adapter is Bluetooth LE and can work on '
                      'iPhone once MotoMap is installed as a signed native app.'
                : 'Bluetooth is not available on this device.',
            textAlign: TextAlign.center,
            style: MotoMapText.bodyMd.copyWith(
              color: MotoMapColors.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      children: [
        Text(
          'Scanning for OBD-II',
          textAlign: TextAlign.center,
          style: MotoMapText.headlineMd,
        ),
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Ensure your motorcycle ignition is '),
              TextSpan(
                text: 'ON',
                style: MotoMapText.bodyMd.copyWith(
                  color: MotoMapColors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const TextSpan(
                text:
                    ' and the adapter is securely plugged into the '
                    'diagnostic port.',
              ),
            ],
          ),
          textAlign: TextAlign.center,
          style: MotoMapText.bodyMd.copyWith(
            color: MotoMapColors.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 220,
          child: AnimatedBuilder(
            animation: radarController,
            builder: (context, _) => CustomPaint(
              painter: _RadarPainter(progress: radarController.value),
              child: Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: MotoMapColors.surfaceContainerHigh,
                    border: Border.all(
                      color: MotoMapColors.primary.withValues(alpha: 0.38),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: MotoMapColors.primary.withValues(alpha: 0.16),
                        blurRadius: 22,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.bluetooth_rounded,
                    size: 30,
                    color: MotoMapColors.primary,
                  ),
                ),
              ),
            ),
          ),
        ),
        SurfaceCard(
          padding: const EdgeInsets.all(12),
          radius: 14,
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    'KNOWN & NEARBY ELM327 DEVICES',
                    style: MotoMapText.labelCaps.copyWith(
                      color: MotoMapColors.primary,
                      fontSize: 9,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(
                    width: 7,
                    height: 7,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: MotoMapColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    connecting ? 'Connecting…' : 'Scanning',
                    style: const TextStyle(
                      color: MotoMapColors.onSurfaceVariant,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh devices',
                    visualDensity: VisualDensity.compact,
                    onPressed: connecting ? null : onRefresh,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                  ),
                ],
              ),
              const Divider(height: 10),
              FutureBuilder<List<ElmDeviceOption>>(
                future: devices,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.all(22),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  }
                  if (snapshot.hasError) {
                    return _InlineMessage(
                      message: '${snapshot.error}',
                      error: true,
                    );
                  }
                  final found = snapshot.data ?? const [];
                  if (found.isEmpty) {
                    return const _InlineMessage(
                      message:
                          'No adapters found. Turn the motorcycle ignition on, '
                          'keep OBDBLE close, close Car Scanner, then refresh.',
                    );
                  }
                  return Column(
                    children: [
                      for (final device in found)
                        _DeviceTile(
                          device: device,
                          selected:
                              selectedDevice?.identifier == device.identifier &&
                              selectedDevice?.transport == device.transport,
                          enabled: !connecting && device.isAvailable,
                          onTap: () => onSelected(device),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 10),
          _InlineMessage(message: error!, error: true),
        ],
        const SizedBox(height: 12),
        PrimaryButton(
          label: 'Troubleshoot Connection',
          icon: Icons.build_circle_outlined,
          secondary: true,
          onPressed: connecting ? null : onTroubleshoot,
        ),
        const SizedBox(height: 10),
        PrimaryButton(
          label: connecting ? 'Connecting ELM327…' : 'Connect ELM327',
          onPressed: onNext,
        ),
        const SizedBox(height: 10),
        Text(
          'Setting up ${motorcycle.displayName}. The selected adapter will be '
          'remembered. MotoMap will automatically reconnect to this motorcycle '
          'until you connect a different motorcycle.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: MotoMapColors.onSurfaceVariant,
            fontSize: 9,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.device,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final ElmDeviceOption device;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 7),
    child: Material(
      color: selected
          ? MotoMapColors.primary.withValues(alpha: 0.10)
          : MotoMapColors.surfaceContainer,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? MotoMapColors.primary
                  : MotoMapColors.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.bluetooth_rounded,
                color: selected
                    ? MotoMapColors.primary
                    : MotoMapColors.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${device.transport == ElmTransport.ble ? 'Bluetooth LE' : 'Bluetooth Classic'} · '
                      '${device.isKnown ? (device.isAvailable ? 'KNOWN · NEARBY' : 'KNOWN · NOT DETECTED') : 'NEARBY'}',
                      style: const TextStyle(
                        color: MotoMapColors.onSurfaceVariant,
                        fontSize: 9,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      device.identifier,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: MotoMapColors.outline,
                        fontSize: 8,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? MotoMapColors.primary : MotoMapColors.outline,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ConnectionResult extends StatelessWidget {
  const _ConnectionResult({
    required this.motorcycle,
    required this.onRetry,
    required this.onChooseAnother,
    required this.onDone,
  });

  final Motorcycle motorcycle;
  final VoidCallback onRetry;
  final VoidCallback onChooseAnother;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final elm = Elm327Service.instance;
    final ecuOnline = elm.ecuAvailable;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      children: [
        Center(
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: MotoMapColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: MotoMapColors.primary.withValues(alpha: 0.42),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.bluetooth_connected_rounded,
              color: MotoMapColors.primary,
              size: 42,
            ),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          ecuOnline ? 'ELM327 & ECU Connected' : 'ELM327 Connected',
          textAlign: TextAlign.center,
          style: MotoMapText.headlineMd.copyWith(color: MotoMapColors.primary),
        ),
        const SizedBox(height: 8),
        Text(
          ecuOnline
              ? 'MotoMap verified the adapter and received a response from '
                    '${motorcycle.displayName}.'
              : 'Bluetooth reached the adapter, but the motorcycle ECU did '
                    'not return supported OBD-II data. Check the ignition and '
                    'diagnostic cable.',
          textAlign: TextAlign.center,
          style: MotoMapText.bodyMd.copyWith(
            color: MotoMapColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 28),
        SurfaceCard(
          child: Column(
            children: [
              _ConnectionRow(
                label: 'ELM327',
                value: elm.isConnected ? 'CONNECTED' : 'NOT CONNECTED',
                online: elm.isConnected,
              ),
              const Divider(height: 24),
              _ConnectionRow(
                label: 'Motorcycle ECU',
                value: ecuOnline ? 'CONNECTED' : 'NOT CONNECTED',
                online: ecuOnline,
              ),
              if (elm.detectedProtocol?.isNotEmpty == true) ...[
                const Divider(height: 24),
                _ConnectionRow(
                  label: 'Detected protocol',
                  value: elm.detectedProtocol!,
                  online: ecuOnline,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        PrimaryButton(
          label: ecuOnline ? 'Done' : 'Retry ECU connection',
          icon: ecuOnline ? null : Icons.refresh_rounded,
          onPressed: ecuOnline ? onDone : onRetry,
        ),
        if (!ecuOnline) ...[
          const SizedBox(height: 10),
          PrimaryButton(
            label: 'Done for now',
            secondary: true,
            onPressed: onDone,
          ),
        ],
        const SizedBox(height: 10),
        PrimaryButton(
          label: 'Choose another adapter',
          icon: Icons.refresh_rounded,
          secondary: true,
          onPressed: onChooseAnother,
        ),
      ],
    );
  }
}

class _ConnectionRow extends StatelessWidget {
  const _ConnectionRow({
    required this.label,
    required this.value,
    required this.online,
  });

  final String label;
  final String value;
  final bool online;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 9,
        height: 9,
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
      Flexible(
        child: Text(
          value,
          textAlign: TextAlign.right,
          style: TextStyle(
            color: online ? MotoMapColors.success : MotoMapColors.warning,
            fontSize: 9,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    ],
  );
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.message, this.error = false});

  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: (error ? MotoMapColors.error : MotoMapColors.surfaceContainer)
          .withValues(alpha: error ? 0.08 : 1),
      borderRadius: BorderRadius.circular(11),
      border: Border.all(
        color: error
            ? MotoMapColors.error.withValues(alpha: 0.28)
            : MotoMapColors.outlineVariant,
      ),
    ),
    child: Text(
      message,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: error ? MotoMapColors.error : MotoMapColors.onSurfaceVariant,
        fontSize: 10,
        height: 1.4,
      ),
    ),
  );
}

class _RadarPainter extends CustomPainter {
  const _RadarPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width, size.height) * 0.45;
    final ringPaint = Paint()
      ..color = MotoMapColors.outlineVariant.withValues(alpha: 0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var index = 1; index <= 4; index++) {
      canvas.drawCircle(center, maxRadius * index / 4, ringPaint);
    }

    final sweepRect = Rect.fromCircle(center: center, radius: maxRadius);
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: math.pi * 2,
        colors: [
          Colors.transparent,
          MotoMapColors.primary.withValues(alpha: 0.04),
          MotoMapColors.primary.withValues(alpha: 0.34),
          Colors.transparent,
        ],
        stops: const [0, 0.58, 0.94, 1],
        transform: GradientRotation(progress * math.pi * 2),
      ).createShader(sweepRect);
    canvas.drawCircle(center, maxRadius, sweepPaint);

    final pulseRadius = maxRadius * (0.35 + (progress * 0.65));
    canvas.drawCircle(
      center,
      pulseRadius,
      Paint()
        ..color = MotoMapColors.primary.withValues(alpha: (1 - progress) * 0.16)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
