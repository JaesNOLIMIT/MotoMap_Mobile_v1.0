import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bluetooth_serial_plus/flutter_bluetooth_serial_plus.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/diagnostic_data.dart';
import '../models/motorcycle.dart';
import 'diagnostic_repository.dart';
import 'motorcycle_service.dart';

enum ElmConnectionStatus {
  unsupported,
  disconnected,
  connecting,
  initializing,
  connected,
  error,
}

class ElmDeviceOption {
  const ElmDeviceOption({
    required this.name,
    required this.identifier,
    required this.transport,
    this.isKnown = false,
    this.isAvailable = true,
  });

  final String name;
  final String identifier;
  final ElmTransport transport;
  final bool isKnown;
  final bool isAvailable;
}

class Elm327Service extends ChangeNotifier with WidgetsBindingObserver {
  Elm327Service._();

  static final instance = Elm327Service._();

  final FlutterBluetoothSerial _bluetooth = FlutterBluetoothSerial.instance;
  static const _permissionChannel = MethodChannel(
    'io.motomap.app/bluetooth_permissions',
  );
  final DiagnosticRepository _repository = DiagnosticRepository.instance;
  final StringBuffer _incoming = StringBuffer();

  BluetoothConnection? _connection;
  StreamSubscription<Uint8List>? _inputSubscription;
  fbp.BluetoothDevice? _bleDevice;
  fbp.BluetoothCharacteristic? _bleWriteCharacteristic;
  fbp.BluetoothCharacteristic? _bleNotifyCharacteristic;
  StreamSubscription<List<int>>? _bleInputSubscription;
  StreamSubscription<fbp.BluetoothConnectionState>? _bleConnectionSubscription;
  Completer<String>? _responseCompleter;
  Future<void> _commandTail = Future<void>.value();
  Timer? _reconnectTimer;
  Timer? _monitorTimer;
  Timer? _liveDisplayTimer;
  Motorcycle? _motorcycle;
  String? _activeSessionId;
  _SessionAccumulator? _activeAccumulator;
  bool _initialized = false;
  bool _manuallyDisconnected = false;
  bool _liveDisplayBusy = false;
  int _reconnectAttempt = 0;

  ElmConnectionStatus status = ElmConnectionStatus.disconnected;
  DiagnosticSnapshot? latestSnapshot;
  List<DiagnosticTroubleCode> latestTroubleCodes = const [];
  String? elmVersion;
  String? detectedProtocol;
  double? adapterVoltage;
  String? errorMessage;
  bool ecuAvailable = false;
  Set<int> supportedPids = <int>{};

  Motorcycle? get motorcycle => _motorcycle;
  String? get activeSessionId => _activeSessionId;
  bool get isConnected =>
      status == ElmConnectionStatus.connected && _transportIsConnected;

  bool get _transportIsConnected =>
      (_connection?.isConnected ?? false) || (_bleDevice?.isConnected ?? false);

  bool get isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  String get statusLabel => switch (status) {
    ElmConnectionStatus.unsupported => 'Not supported on this device',
    ElmConnectionStatus.disconnected => 'ELM327 disconnected',
    ElmConnectionStatus.connecting => 'Connecting to ELM327…',
    ElmConnectionStatus.initializing => 'Checking motorcycle ECU…',
    ElmConnectionStatus.connected when ecuAvailable => 'ECU connected',
    ElmConnectionStatus.connected => 'ELM327 connected · ECU not connected',
    ElmConnectionStatus.error => errorMessage ?? 'ELM327 connection failed',
  };

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    WidgetsBinding.instance.addObserver(this);
    if (!isSupportedPlatform) {
      status = ElmConnectionStatus.unsupported;
      notifyListeners();
      return;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await fbp.FlutterBluePlus.setOptions(restoreState: true);
    }
    await refreshReconnectMotorcycle();
  }

  Future<void> refreshReconnectMotorcycle() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      _motorcycle = null;
      notifyListeners();
      return;
    }
    final reconnectTarget = await MotorcycleService.instance
        .fetchReconnectMotorcycle();
    if (reconnectTarget?.id != _motorcycle?.id) {
      await disconnect(manual: false);
      _motorcycle = reconnectTarget;
    } else {
      _motorcycle = reconnectTarget;
    }

    if (reconnectTarget?.hasElmAdapter == true) {
      await connectToMotorcycle(reconnectTarget!, automatic: true);
    } else {
      notifyListeners();
    }
  }

  Future<List<ElmDeviceOption>> availableDevices() async {
    if (!isSupportedPlatform) return const [];
    final allowed = await _requestBluetoothPermission();
    if (!allowed) {
      throw StateError(
        'Bluetooth permission is required to find ELM327 adapters.',
      );
    }
    final devices = <String, ElmDeviceOption>{};

    if (Supabase.instance.client.auth.currentUser != null) {
      try {
        for (final motorcycle
            in await MotorcycleService.instance.fetchMotorcycles()) {
          if (!motorcycle.hasElmAdapter) continue;
          final transport = motorcycle.elmTransport!;
          final identifier = motorcycle.elmDeviceIdentifier!;
          final key = _deviceKey(transport, identifier);
          devices[key] = ElmDeviceOption(
            name: motorcycle.elmDeviceName ?? 'Saved ELM327',
            identifier: identifier,
            transport: transport,
            isKnown: true,
            isAvailable: false,
          );
        }
      } catch (_) {
        // Scanning should still work when saved devices cannot be loaded.
      }
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final enabled = await _bluetooth.isEnabled ?? false;
      if (!enabled) await _bluetooth.requestEnable();
      try {
        for (final device in await _bluetooth.getBondedDevices()) {
          final option = ElmDeviceOption(
            name: device.name?.trim().isNotEmpty == true
                ? device.name!.trim()
                : 'Paired Bluetooth device',
            identifier: device.address,
            transport: ElmTransport.bluetoothClassic,
            isKnown:
                devices[_deviceKey(
                      ElmTransport.bluetoothClassic,
                      device.address,
                    )]
                    ?.isKnown ??
                false,
            isAvailable: true,
          );
          if (_looksLikeElm(option.name) || option.isKnown) {
            devices[_deviceKey(option.transport, option.identifier)] = option;
          }
        }
      } catch (_) {
        // BLE discovery can still work when no Classic devices are paired.
      }
    }

    if (!await fbp.FlutterBluePlus.isSupported) {
      return devices.values.toList(growable: false);
    }
    final adapterState = await fbp.FlutterBluePlus.adapterState
        .where((state) => state != fbp.BluetoothAdapterState.unknown)
        .first;
    if (adapterState != fbp.BluetoothAdapterState.on) {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await fbp.FlutterBluePlus.turnOn();
      } else {
        throw StateError('Turn on Bluetooth in iPhone Settings, then retry.');
      }
    }

    final scanSubscription = fbp.FlutterBluePlus.scanResults.listen((results) {
      for (final result in results) {
        final advertisedName = result.advertisementData.advName.trim();
        final platformName = result.device.platformName.trim();
        final name = advertisedName.isNotEmpty
            ? advertisedName
            : platformName.isNotEmpty
            ? platformName
            : 'Bluetooth LE device';
        final identifier = result.device.remoteId.str;
        final key = _deviceKey(ElmTransport.ble, identifier);
        final known = devices[key]?.isKnown ?? false;
        if (!_looksLikeElm(name) && !known) continue;
        devices[key] = ElmDeviceOption(
          name: name,
          identifier: identifier,
          transport: ElmTransport.ble,
          isKnown: known,
          isAvailable: true,
        );
      }
    });
    try {
      await fbp.FlutterBluePlus.startScan(timeout: const Duration(seconds: 7));
      await fbp.FlutterBluePlus.isScanning.where((value) => !value).first;
    } finally {
      await scanSubscription.cancel();
      if (fbp.FlutterBluePlus.isScanningNow) {
        await fbp.FlutterBluePlus.stopScan();
      }
    }
    return devices.values.toList(growable: false)..sort((left, right) {
      if (left.isKnown != right.isKnown) return left.isKnown ? -1 : 1;
      if (left.isAvailable != right.isAvailable) {
        return left.isAvailable ? -1 : 1;
      }
      return left.name.compareTo(right.name);
    });
  }

  Future<void> connectToMotorcycle(
    Motorcycle motorcycle, {
    bool automatic = false,
  }) async {
    if (!isSupportedPlatform) {
      status = ElmConnectionStatus.unsupported;
      notifyListeners();
      return;
    }
    if (!motorcycle.hasElmAdapter) {
      if (!automatic) {
        throw StateError('This motorcycle has no ELM327 adapter configured.');
      }
      return;
    }
    if (motorcycle.elmTransport == ElmTransport.bluetoothClassic &&
        defaultTargetPlatform != TargetPlatform.android) {
      throw StateError(
        'Bluetooth Classic ELM327 adapters require Android. '
        'Choose a Bluetooth LE adapter on iPhone.',
      );
    }
    if (isConnected && _motorcycle?.id == motorcycle.id) return;

    _motorcycle = motorcycle;
    _manuallyDisconnected = false;
    _reconnectTimer?.cancel();
    errorMessage = null;
    _clearLiveData();
    _setStatus(ElmConnectionStatus.connecting);

    try {
      if (!await _requestBluetoothPermission()) {
        throw StateError('Bluetooth permission was denied.');
      }
      await _closeConnection();
      if (motorcycle.elmTransport == ElmTransport.ble) {
        await _connectBle(motorcycle.elmDeviceIdentifier!);
      } else {
        final enabled = await _bluetooth.isEnabled ?? false;
        if (!enabled) {
          if (automatic) {
            _setStatus(ElmConnectionStatus.disconnected);
            return;
          }
          final accepted = await _bluetooth.requestEnable() ?? false;
          if (!accepted) throw StateError('Turn on Bluetooth to connect.');
        }
        final connection = await BluetoothConnection.toAddress(
          motorcycle.elmDeviceIdentifier,
        ).timeout(const Duration(seconds: 12));
        _connection = connection;
        _inputSubscription = connection.input.listen(
          _onBytes,
          onError: _onConnectionError,
          onDone: _onConnectionClosed,
          cancelOnError: true,
        );
      }
      _reconnectAttempt = 0;
      _setStatus(ElmConnectionStatus.initializing);
      await _initializeAdapter();
      _setStatus(ElmConnectionStatus.connected);
      _startLiveDisplayPolling();
      await MotorcycleService.instance.markElmConnected(motorcycle.id);
    } catch (error) {
      await _closeConnection();
      errorMessage = _friendlyError(error);
      _setStatus(
        automatic
            ? ElmConnectionStatus.disconnected
            : ElmConnectionStatus.error,
      );
      _scheduleReconnect();
      if (!automatic) rethrow;
    }
  }

  Future<void> disconnect({bool manual = true}) async {
    _manuallyDisconnected = manual;
    _reconnectTimer?.cancel();
    await stopLiveMonitoring();
    await _closeConnection();
    _clearLiveData();
    if (status != ElmConnectionStatus.unsupported) {
      _setStatus(ElmConnectionStatus.disconnected);
    }
  }

  Future<DiagnosticReport> runDiagnostic({
    DiagnosticSessionType type = DiagnosticSessionType.manual,
  }) async {
    final bike = _motorcycle;
    if (bike == null) throw StateError('Select a primary motorcycle first.');
    if (!isConnected) await connectToMotorcycle(bike);

    final snapshot = await pollOnce();
    final codes = await readTroubleCodes();
    final scoreResult = score(snapshot, codes);
    final sessionId = await _repository.startSession(
      motorcycle: bike,
      type: type,
      elmVersion: elmVersion,
      protocol: detectedProtocol,
      adapterVoltage: adapterVoltage,
      supportedPids: supportedPids.map(pidHex).toList(growable: false),
    );
    await _repository.saveSnapshot(
      sessionId: sessionId,
      motorcycle: bike,
      snapshot: snapshot,
    );
    await _repository.saveTroubleCodes(
      sessionId: sessionId,
      motorcycle: bike,
      codes: codes,
    );
    await _repository.finishSession(
      sessionId: sessionId,
      healthScore: scoreResult.$1,
      issues: scoreResult.$2,
      summary: DiagnosticSessionSummary.fromSnapshot(snapshot, codes),
    );
    return DiagnosticReport(
      sessionId: sessionId,
      snapshot: snapshot,
      troubleCodes: codes,
      healthScore: scoreResult.$1,
      issues: scoreResult.$2,
      elmVersion: elmVersion,
      protocol: detectedProtocol,
      adapterVoltage: adapterVoltage,
    );
  }

  Future<void> startLiveMonitoring({
    DiagnosticSessionType type = DiagnosticSessionType.ride,
  }) async {
    final bike = _motorcycle;
    if (bike == null || _activeSessionId != null) return;
    if (bike.hasElmAdapter && !isConnected) {
      await connectToMotorcycle(bike, automatic: true);
    }

    _activeSessionId = await _repository.startSession(
      motorcycle: bike,
      type: type,
      elmVersion: elmVersion,
      protocol: detectedProtocol,
      adapterVoltage: adapterVoltage,
      supportedPids: supportedPids.map(pidHex).toList(growable: false),
    );
    _activeAccumulator = _SessionAccumulator();
    if (isConnected) {
      try {
        latestTroubleCodes = await readTroubleCodes();
        _activeAccumulator?.troubleCodes = latestTroubleCodes;
        await _repository.saveTroubleCodes(
          sessionId: _activeSessionId!,
          motorcycle: bike,
          codes: latestTroubleCodes,
        );
      } catch (_) {
        // Some motorcycle ECUs do not expose generic mode 03 while moving.
      }
    }
    _monitorTimer?.cancel();
    _monitorTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(_pollAndStore());
    });
    if (isConnected) await _pollAndStore();
  }

  Future<void> stopLiveMonitoring() async {
    _monitorTimer?.cancel();
    _monitorTimer = null;
    final sessionId = _activeSessionId;
    final accumulator = _activeAccumulator;
    _activeSessionId = null;
    _activeAccumulator = null;
    if (sessionId == null) return;
    final storedCodes = accumulator?.troubleCodes ?? latestTroubleCodes;
    final finalSnapshot = accumulator?.lastSnapshot ?? latestSnapshot;
    final hasDiagnosticData =
        finalSnapshot?.hasAnyValue == true || storedCodes.isNotEmpty;
    final result = hasDiagnosticData
        ? score(finalSnapshot, storedCodes)
        : (null, const <String>['No ECU data was recorded for this ride.']);
    await _repository.finishSession(
      sessionId: sessionId,
      healthScore: result.$1,
      issues: result.$2,
      summary: accumulator?.summary(storedCodes),
    );
  }

  Future<DiagnosticSnapshot> pollOnce() async {
    if (!isConnected) throw StateError('ELM327 is not connected.');
    final values = <int, double>{};
    for (final pid in _livePids) {
      if (supportedPids.isNotEmpty && !supportedPids.contains(pid)) continue;
      final value = await _readPid(pid);
      if (value != null) values[pid] = value;
    }
    ecuAvailable = values.isNotEmpty;
    final snapshot = DiagnosticSnapshot(
      recordedAt: DateTime.now().toUtc(),
      engineRpm: values[0x0C],
      vehicleSpeedKph: values[0x0D],
      coolantTemperatureC: values[0x05],
      intakeAirTemperatureC: values[0x0F],
      throttlePositionPercent: values[0x11],
      engineLoadPercent: values[0x04],
      fuelLevelPercent: values[0x2F],
      controlModuleVoltage: values[0x42],
      distanceWithMilKm: values[0x21],
      runtimeSinceEngineStartSeconds: values[0x1F]?.round(),
      fuelRateLitersPerHour: values[0x5E],
    );
    latestSnapshot = snapshot;
    notifyListeners();
    return snapshot;
  }

  Future<List<DiagnosticTroubleCode>> readTroubleCodes() async {
    final response = await sendCommand(
      '03',
      timeout: const Duration(seconds: 8),
    );
    final codes = parseTroubleCodes(response, status: 'active');
    latestTroubleCodes = codes;
    notifyListeners();
    return codes;
  }

  Future<void> clearTroubleCodes() async {
    if (!isConnected) throw StateError('ELM327 is not connected.');
    final response = await sendCommand(
      '04',
      timeout: const Duration(seconds: 8),
    );
    if (!response.contains('44') && !response.toUpperCase().contains('OK')) {
      throw StateError(
        'The ECU did not confirm that trouble codes were cleared.',
      );
    }
    latestTroubleCodes = const [];
    notifyListeners();
  }

  Future<String> sendCommand(
    String command, {
    Duration timeout = const Duration(seconds: 4),
  }) {
    final result = Completer<String>();
    _commandTail = _commandTail.catchError((_) {}).then((_) async {
      try {
        result.complete(await _sendCommandNow(command, timeout));
      } catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
  }

  Future<String> _sendCommandNow(String command, Duration timeout) async {
    if (!_transportIsConnected) {
      throw StateError('ELM327 is not connected.');
    }
    if (_responseCompleter != null) {
      throw StateError('Another ELM327 command is still running.');
    }
    _incoming.clear();
    final completer = Completer<String>();
    _responseCompleter = completer;
    final bytes = ascii.encode('$command\r');
    final connection = _connection;
    if (connection?.isConnected == true) {
      connection!.output.add(Uint8List.fromList(bytes));
      await connection.output.allSent;
    } else {
      final characteristic = _bleWriteCharacteristic;
      if (characteristic == null || _bleDevice?.isConnected != true) {
        throw StateError('ELM327 Bluetooth LE channel is unavailable.');
      }
      await characteristic.write(
        bytes,
        withoutResponse: !characteristic.properties.write,
      );
    }
    try {
      final raw = await completer.future.timeout(timeout);
      return normalizeResponse(raw, command: command);
    } finally {
      if (identical(_responseCompleter, completer)) _responseCompleter = null;
    }
  }

  Future<void> _initializeAdapter() async {
    await sendCommand('ATZ', timeout: const Duration(seconds: 6));
    await sendCommand('ATE0');
    await sendCommand('ATL0');
    await sendCommand('ATS0');
    await sendCommand('ATH0');
    await sendCommand('ATSP0');
    elmVersion = _firstUsefulLine(await sendCommand('ATI'));
    detectedProtocol = _firstUsefulLine(
      await sendCommand('ATDP', timeout: const Duration(seconds: 8)),
    );
    adapterVoltage = parseVoltage(await sendCommand('ATRV'));
    supportedPids = await _readSupportedPids();
    ecuAvailable = supportedPids.isNotEmpty;
  }

  Future<Set<int>> _readSupportedPids() async {
    final result = <int>{};
    for (var base = 0x00; base <= 0xC0; base += 0x20) {
      final response = await sendCommand(
        '01${pidHex(base)}',
        timeout: const Duration(seconds: 8),
      );
      final bytes = parseMode01Bytes(response, base);
      if (bytes.length < 4) break;
      final mask =
          (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
      for (var bit = 0; bit < 32; bit++) {
        if ((mask & (1 << (31 - bit))) != 0) result.add(base + bit + 1);
      }
      if (!result.contains(base + 0x20)) break;
    }
    return result;
  }

  Future<double?> _readPid(int pid) async {
    final response = await sendCommand('01${pidHex(pid)}');
    final bytes = parseMode01Bytes(response, pid);
    if (bytes.isEmpty) return null;
    final a = bytes[0];
    final b = bytes.length > 1 ? bytes[1] : 0;
    return switch (pid) {
      0x04 => a * 100 / 255,
      0x05 || 0x0F => a - 40,
      0x0C => ((a * 256) + b) / 4,
      0x0D => a.toDouble(),
      0x11 || 0x2F => a * 100 / 255,
      0x1F || 0x21 => ((a * 256) + b).toDouble(),
      0x42 => ((a * 256) + b) / 1000,
      0x5E => ((a * 256) + b) / 20,
      _ => null,
    };
  }

  Future<void> _pollAndStore() async {
    final sessionId = _activeSessionId;
    final bike = _motorcycle;
    if (sessionId == null || bike == null || !isConnected) return;
    try {
      final snapshot = await pollOnce();
      _activeAccumulator?.add(snapshot);
      await _repository.saveSnapshot(
        sessionId: sessionId,
        motorcycle: bike,
        snapshot: snapshot,
      );
    } catch (error) {
      errorMessage = _friendlyError(error);
      notifyListeners();
    }
  }

  void _startLiveDisplayPolling() {
    _liveDisplayTimer?.cancel();
    _liveDisplayTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      unawaited(_pollLiveDisplay());
    });
    unawaited(_pollLiveDisplay());
  }

  Future<void> _pollLiveDisplay() async {
    if (_liveDisplayBusy ||
        !isConnected ||
        _activeSessionId != null ||
        _monitorTimer?.isActive == true) {
      return;
    }
    _liveDisplayBusy = true;
    try {
      if (supportedPids.isEmpty) {
        supportedPids = await _readSupportedPids();
        if (supportedPids.isEmpty) {
          ecuAvailable = false;
          latestSnapshot = null;
          notifyListeners();
          return;
        }
      }
      await pollOnce();
    } catch (error) {
      if (_transportIsConnected) {
        ecuAvailable = false;
        latestSnapshot = null;
        errorMessage = _friendlyError(error);
        notifyListeners();
      }
    } finally {
      _liveDisplayBusy = false;
    }
  }

  void _onBytes(List<int> bytes) {
    _incoming.write(latin1.decode(bytes, allowInvalid: true));
    final text = _incoming.toString();
    final prompt = text.indexOf('>');
    if (prompt < 0) return;
    final response = text.substring(0, prompt);
    final remainder = text.substring(prompt + 1);
    _incoming
      ..clear()
      ..write(remainder);
    final completer = _responseCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(response);
    }
  }

  void _onConnectionError(Object error) {
    errorMessage = _friendlyError(error);
    _onConnectionClosed();
  }

  void _onConnectionClosed() {
    _liveDisplayTimer?.cancel();
    _liveDisplayTimer = null;
    _liveDisplayBusy = false;
    _connection = null;
    _bleDevice = null;
    _bleWriteCharacteristic = null;
    _bleNotifyCharacteristic = null;
    _clearLiveData();
    if (status != ElmConnectionStatus.unsupported) {
      _setStatus(ElmConnectionStatus.disconnected);
    }
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    final bike = _motorcycle;
    if (_manuallyDisconnected ||
        bike == null ||
        !bike.hasElmAdapter ||
        _reconnectTimer?.isActive == true) {
      return;
    }
    _reconnectAttempt++;
    final seconds = switch (_reconnectAttempt) {
      <= 1 => 5,
      <= 3 => 10,
      _ => 30,
    };
    _reconnectTimer = Timer(Duration(seconds: seconds), () {
      unawaited(connectToMotorcycle(bike, automatic: true));
    });
  }

  Future<void> _connectBle(String identifier) async {
    if (!await fbp.FlutterBluePlus.isSupported) {
      throw StateError('Bluetooth LE is not supported on this device.');
    }
    final adapterState = await fbp.FlutterBluePlus.adapterState
        .where((state) => state != fbp.BluetoothAdapterState.unknown)
        .first;
    if (adapterState != fbp.BluetoothAdapterState.on) {
      throw StateError('Turn on Bluetooth, then retry the connection.');
    }

    final device = fbp.BluetoothDevice.fromId(identifier);
    if (!device.isConnected) {
      await device.connect(timeout: const Duration(seconds: 12), mtu: null);
    }
    _bleDevice = device;
    final services = await device.discoverServices();
    final characteristics = services
        .expand((service) => service.characteristics)
        .toList(growable: false);
    final writable = characteristics
        .where(
          (characteristic) =>
              characteristic.properties.write ||
              characteristic.properties.writeWithoutResponse,
        )
        .toList(growable: false);
    final notifiable = characteristics
        .where(
          (characteristic) =>
              characteristic.properties.notify ||
              characteristic.properties.indicate,
        )
        .toList(growable: false);
    if (writable.isEmpty || notifiable.isEmpty) {
      throw StateError(
        'This Bluetooth LE device does not expose an ELM327 serial channel.',
      );
    }

    final preferred = <String>[
      'ffe1',
      '6e400002-b5a3-f393-e0a9-e50e24dcca9e',
      'fff1',
      'fff2',
      '49535343-1e4d-4bd9-ba61-23c647249616',
    ];
    fbp.BluetoothCharacteristic? choose(
      List<fbp.BluetoothCharacteristic> options,
    ) {
      for (final target in preferred) {
        for (final option in options) {
          if (option.uuid.toString().toLowerCase().contains(target)) {
            return option;
          }
        }
      }
      return options.firstOrNull;
    }

    final writeCharacteristic = choose(writable)!;
    var notifyCharacteristic = choose(notifiable)!;
    if (notifiable.contains(writeCharacteristic)) {
      notifyCharacteristic = writeCharacteristic;
    }
    _bleWriteCharacteristic = writeCharacteristic;
    _bleNotifyCharacteristic = notifyCharacteristic;
    await notifyCharacteristic.setNotifyValue(true);
    _bleInputSubscription = notifyCharacteristic.onValueReceived.listen(
      _onBytes,
      onError: _onConnectionError,
      cancelOnError: true,
    );
    _bleConnectionSubscription = device.connectionState.listen((state) {
      if (state == fbp.BluetoothConnectionState.disconnected &&
          identical(_bleDevice, device)) {
        _onConnectionClosed();
      }
    });
  }

  static bool _looksLikeElm(String name) {
    final lower = name.toLowerCase();
    return lower.contains('obd') ||
        lower.contains('elm') ||
        lower.contains('vlink') ||
        lower.contains('kingbolen');
  }

  static String _deviceKey(ElmTransport transport, String identifier) =>
      '${transport.databaseValue}:${identifier.toLowerCase()}';

  Future<void> _closeConnection() async {
    _liveDisplayTimer?.cancel();
    _liveDisplayTimer = null;
    _liveDisplayBusy = false;
    final subscription = _inputSubscription;
    _inputSubscription = null;
    await subscription?.cancel();
    final connection = _connection;
    _connection = null;
    if (connection?.isConnected == true) await connection!.close();
    final bleInputSubscription = _bleInputSubscription;
    _bleInputSubscription = null;
    await bleInputSubscription?.cancel();
    final bleConnectionSubscription = _bleConnectionSubscription;
    _bleConnectionSubscription = null;
    await bleConnectionSubscription?.cancel();
    final notifyCharacteristic = _bleNotifyCharacteristic;
    _bleNotifyCharacteristic = null;
    if (notifyCharacteristic?.isNotifying == true) {
      try {
        await notifyCharacteristic!.setNotifyValue(false);
      } catch (_) {
        // The peripheral may already have powered off.
      }
    }
    final bleDevice = _bleDevice;
    _bleDevice = null;
    _bleWriteCharacteristic = null;
    if (bleDevice?.isConnected == true) {
      try {
        await bleDevice!.disconnect();
      } catch (_) {
        // Treat an already-disconnected adapter as closed.
      }
    }
    final response = _responseCompleter;
    _responseCompleter = null;
    if (response != null && !response.isCompleted) {
      response.completeError(StateError('ELM327 disconnected.'));
    }
  }

  Future<bool> _requestBluetoothPermission() async {
    if (!isSupportedPlatform) return false;
    if (defaultTargetPlatform == TargetPlatform.iOS) return true;
    return await _permissionChannel.invokeMethod<bool>('request') ?? false;
  }

  void _setStatus(ElmConnectionStatus value) {
    status = value;
    notifyListeners();
  }

  void _clearLiveData() {
    ecuAvailable = false;
    latestSnapshot = null;
    latestTroubleCodes = const [];
    supportedPids = <int>{};
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !isConnected) {
      final bike = _motorcycle;
      if (bike?.hasElmAdapter == true) {
        unawaited(connectToMotorcycle(bike!, automatic: true));
      }
    }
  }

  static const _livePids = <int>[
    0x0C,
    0x0D,
    0x05,
    0x0F,
    0x11,
    0x04,
    0x2F,
    0x42,
    0x21,
    0x1F,
    0x5E,
  ];

  @visibleForTesting
  static String normalizeResponse(String raw, {String? command}) {
    final normalizedCommand = command?.replaceAll(' ', '').toUpperCase();
    return raw
        .replaceAll('\r', '\n')
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && line != '>')
        .where(
          (line) => line.replaceAll(' ', '').toUpperCase() != normalizedCommand,
        )
        .where((line) => !line.toUpperCase().startsWith('SEARCHING'))
        .join('\n');
  }

  @visibleForTesting
  static List<int> parseMode01Bytes(String response, int pid) {
    final compact = response.toUpperCase().replaceAll(RegExp(r'[^0-9A-F]'), '');
    final marker = '41${pidHex(pid)}';
    final index = compact.indexOf(marker);
    if (index < 0) return const [];
    final payload = compact.substring(index + marker.length);
    final bytes = <int>[];
    for (var i = 0; i + 1 < payload.length; i += 2) {
      final parsed = int.tryParse(payload.substring(i, i + 2), radix: 16);
      if (parsed == null) break;
      bytes.add(parsed);
    }
    return bytes;
  }

  @visibleForTesting
  static List<DiagnosticTroubleCode> parseTroubleCodes(
    String response, {
    String status = 'active',
  }) {
    if (response.toUpperCase().contains('NO DATA')) return const [];
    final compact = response.toUpperCase().replaceAll(RegExp(r'[^0-9A-F]'), '');
    final marker = compact.indexOf('43');
    if (marker < 0) return const [];
    final payload = compact.substring(marker + 2);
    final codes = <DiagnosticTroubleCode>[];
    for (var i = 0; i + 3 < payload.length; i += 4) {
      final first = int.tryParse(payload.substring(i, i + 2), radix: 16);
      final second = int.tryParse(payload.substring(i + 2, i + 4), radix: 16);
      if (first == null || second == null || (first == 0 && second == 0)) {
        continue;
      }
      final system = const ['P', 'C', 'B', 'U'][(first & 0xC0) >> 6];
      final code =
          '$system${(first & 0x30) >> 4}'
                  '${(first & 0x0F).toRadixString(16)}'
                  '${second.toRadixString(16).padLeft(2, '0')}'
              .toUpperCase();
      codes.add(
        DiagnosticTroubleCode(
          code: code,
          status: status,
          description: _commonDtcDescriptions[code],
          rawResponse: response,
        ),
      );
    }
    return codes;
  }

  @visibleForTesting
  static double? parseVoltage(String response) {
    final match = RegExp(
      r'([0-9]+(?:\.[0-9]+)?)\s*V',
      caseSensitive: false,
    ).firstMatch(response);
    return match == null ? null : double.tryParse(match.group(1)!);
  }

  (int, List<String>) evaluateCurrentHealth() =>
      score(latestSnapshot, latestTroubleCodes);

  @visibleForTesting
  static (int, List<String>) score(
    DiagnosticSnapshot? snapshot,
    List<DiagnosticTroubleCode> codes,
  ) {
    var value = 100;
    final issues = <String>[];
    if (codes.isNotEmpty) {
      value -= (codes.length * 15).clamp(0, 60);
      issues.add('${codes.length} active diagnostic trouble code(s) detected.');
    }
    final voltage = snapshot?.controlModuleVoltage;
    if (voltage != null && voltage < 11.8) {
      value -= 20;
      issues.add(
        'Control-module voltage is low (${voltage.toStringAsFixed(1)} V).',
      );
    }
    final coolant = snapshot?.coolantTemperatureC;
    if (coolant != null && coolant > 110) {
      value -= 25;
      issues.add(
        'Coolant temperature is high (${coolant.toStringAsFixed(0)} °C).',
      );
    }
    if (snapshot == null || !snapshot.hasAnyValue) {
      value = value.clamp(0, 50);
      issues.add('The ECU did not return supported live sensor data.');
    }
    return (value.clamp(0, 100), issues);
  }

  static String pidHex(int pid) =>
      pid.toRadixString(16).padLeft(2, '0').toUpperCase();

  static String? _firstUsefulLine(String response) {
    for (final line in response.split('\n')) {
      final value = line.trim();
      if (value.isNotEmpty &&
          value.toUpperCase() != 'OK' &&
          !value.toUpperCase().contains('NO DATA')) {
        return value;
      }
    }
    return null;
  }

  static String _friendlyError(Object error) {
    final text = error.toString().replaceFirst('Exception: ', '');
    if (text.contains('timeout') || text.contains('Timeout')) {
      return 'ELM327 did not respond. Check that the motorcycle is on.';
    }
    return text.replaceFirst('Bad state: ', '');
  }

  static const _commonDtcDescriptions = <String, String>{
    'P0100': 'Mass or volume air-flow circuit malfunction',
    'P0110': 'Intake-air temperature sensor circuit malfunction',
    'P0120': 'Throttle-position sensor circuit malfunction',
    'P0130': 'Oxygen sensor circuit malfunction',
    'P0171': 'System too lean',
    'P0172': 'System too rich',
    'P0300': 'Random or multiple-cylinder misfire detected',
    'P0335': 'Crankshaft-position sensor circuit malfunction',
    'P0420': 'Catalyst-system efficiency below threshold',
    'P0500': 'Vehicle-speed sensor malfunction',
    'P0560': 'System-voltage malfunction',
  };
}

class _SessionAccumulator {
  int sampleCount = 0;
  int speedSampleCount = 0;
  int rpmSampleCount = 0;
  double speedTotal = 0;
  double rpmTotal = 0;
  double? maximumSpeedKph;
  double? maximumEngineRpm;
  double? maximumCoolantTemperatureC;
  double? minimumControlModuleVoltage;
  double? endingFuelLevelPercent;
  double distanceKm = 0;
  double fuelConsumedLiters = 0;
  bool hasDistanceData = false;
  bool hasFuelConsumptionData = false;
  DiagnosticSnapshot? _previous;
  List<DiagnosticTroubleCode> troubleCodes = const [];

  DiagnosticSnapshot? get lastSnapshot => _previous;

  void add(DiagnosticSnapshot snapshot) {
    sampleCount++;
    final speed = snapshot.vehicleSpeedKph;
    if (speed != null) {
      speedTotal += speed;
      speedSampleCount++;
      maximumSpeedKph = maximumSpeedKph == null
          ? speed
          : math.max(maximumSpeedKph!, speed);
    }
    final rpm = snapshot.engineRpm;
    if (rpm != null) {
      rpmTotal += rpm;
      rpmSampleCount++;
      maximumEngineRpm = maximumEngineRpm == null
          ? rpm
          : math.max(maximumEngineRpm!, rpm);
    }
    final coolant = snapshot.coolantTemperatureC;
    if (coolant != null) {
      maximumCoolantTemperatureC = maximumCoolantTemperatureC == null
          ? coolant
          : math.max(maximumCoolantTemperatureC!, coolant);
    }
    final voltage = snapshot.controlModuleVoltage;
    if (voltage != null) {
      minimumControlModuleVoltage = minimumControlModuleVoltage == null
          ? voltage
          : math.min(minimumControlModuleVoltage!, voltage);
    }
    if (snapshot.fuelLevelPercent != null) {
      endingFuelLevelPercent = snapshot.fuelLevelPercent;
    }

    final previous = _previous;
    if (previous != null) {
      final elapsedSeconds =
          snapshot.recordedAt.difference(previous.recordedAt).inMilliseconds /
          1000;
      if (elapsedSeconds > 0 && elapsedSeconds <= 30) {
        final previousSpeed = previous.vehicleSpeedKph;
        if (speed != null && previousSpeed != null) {
          distanceKm += ((speed + previousSpeed) / 2) * elapsedSeconds / 3600;
          hasDistanceData = true;
        }
        final fuelRate = snapshot.fuelRateLitersPerHour;
        final previousFuelRate = previous.fuelRateLitersPerHour;
        if (fuelRate != null && previousFuelRate != null) {
          fuelConsumedLiters +=
              ((fuelRate + previousFuelRate) / 2) * elapsedSeconds / 3600;
          hasFuelConsumptionData = true;
        }
      }
    }
    _previous = snapshot;
  }

  DiagnosticSessionSummary summary(List<DiagnosticTroubleCode> troubleCodes) =>
      DiagnosticSessionSummary(
        sampleCount: sampleCount,
        troubleCodes: troubleCodes,
        distanceKm: hasDistanceData ? distanceKm : null,
        fuelConsumedLiters: hasFuelConsumptionData ? fuelConsumedLiters : null,
        averageSpeedKph: speedSampleCount == 0
            ? null
            : speedTotal / speedSampleCount,
        maximumSpeedKph: maximumSpeedKph,
        averageEngineRpm: rpmSampleCount == 0
            ? null
            : rpmTotal / rpmSampleCount,
        maximumEngineRpm: maximumEngineRpm,
        maximumCoolantTemperatureC: maximumCoolantTemperatureC,
        minimumControlModuleVoltage: minimumControlModuleVoltage,
        endingFuelLevelPercent: endingFuelLevelPercent,
      );
}
