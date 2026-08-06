import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';

import '../models/motorcycle.dart';
import '../models/ride_data.dart';
import 'elm327_service.dart';
import 'motorcycle_service.dart';
import 'ride_repository.dart';
import 'routing_service.dart';

enum RideRecorderStatus {
  idle,
  starting,
  recording,
  paused,
  finishing,
  completed,
}

class RideRecorderService extends ChangeNotifier {
  RideRecorderService._();

  static final instance = RideRecorderService._();
  final RideRepository _repository = RideRepository.instance;
  final FlutterTts _tts = FlutterTts();

  RideRecorderStatus status = RideRecorderStatus.idle;
  RoutePlan? plan;
  Motorcycle? motorcycle;
  RideRecord? ride;
  MapPoint? currentLocation;
  double currentSpeedKph = 0;
  double distanceKm = 0;
  double maximumSpeedKph = 0;
  double? averageSpeedKph;
  double? fuelConsumedLiters;
  bool fuelIsEstimated = false;
  bool voiceMuted = false;
  bool reachedDestination = false;
  int ridingScore = 0;
  int? motorcycleHealthScore;
  Map<String, dynamic> scoreDetails = const {};
  String? errorMessage;

  StreamSubscription<Position>? _positionSubscription;
  Timer? _clockTimer;
  DateTime? _startedAt;
  DateTime? _lastPointAt;
  DateTime? _pausedAt;
  Duration _pausedDuration = Duration.zero;
  Duration _movingDuration = Duration.zero;
  Position? _lastPosition;
  int _sequence = 0;
  int _speedSampleCount = 0;
  double _speedTotal = 0;
  double _actualFuelLiters = 0;
  bool _hasActualFuel = false;
  int _hardAccelerationCount = 0;
  int _hardBrakingCount = 0;
  int _idleSeconds = 0;
  double? _lastSpeedKph;
  String? _activePauseId;
  final List<RidePointSample> _pointBatch = [];
  final List<MapPoint> traveledCoordinates = [];
  List<MapPoint> navigationCoordinates = const [];
  List<RouteManeuver> navigationManeuvers = const [];
  int _closestRouteIndex = 0;
  int _activeManeuverIndex = 0;
  int _offRouteSamples = 0;
  bool _rerouting = false;
  bool _finishInProgress = false;
  final Set<String> _spokenPrompts = {};

  bool get isActive => switch (status) {
    RideRecorderStatus.starting ||
    RideRecorderStatus.recording ||
    RideRecorderStatus.paused ||
    RideRecorderStatus.finishing => true,
    _ => false,
  };

  bool get isPaused => status == RideRecorderStatus.paused;

  Duration get elapsedDuration {
    final startedAt = _startedAt;
    if (startedAt == null) return Duration.zero;
    return DateTime.now().difference(startedAt);
  }

  Duration get pausedDuration =>
      _pausedDuration +
      (_pausedAt == null
          ? Duration.zero
          : DateTime.now().difference(_pausedAt!));

  Duration get movingDuration => _movingDuration;

  double get completionPercent {
    if (navigationCoordinates.length < 2) return 0;
    return (_closestRouteIndex / (navigationCoordinates.length - 1) * 100)
        .clamp(0, 100)
        .toDouble();
  }

  RouteManeuver? get currentManeuver => navigationManeuvers.isEmpty
      ? null
      : navigationManeuvers[_activeManeuverIndex.clamp(
          0,
          navigationManeuvers.length - 1,
        )];

  double? get distanceToNextManeuverMeters {
    final location = currentLocation;
    final maneuver = currentManeuver;
    if (location == null || maneuver == null || navigationCoordinates.isEmpty) {
      return null;
    }
    final index = maneuver.beginShapeIndex.clamp(
      0,
      navigationCoordinates.length - 1,
    );
    return _distanceMeters(location, navigationCoordinates[index]);
  }

  Future<void> start(RoutePlan selectedPlan) async {
    if (isActive) throw StateError('A ride is already active.');
    status = RideRecorderStatus.starting;
    errorMessage = null;
    plan = selectedPlan;
    navigationCoordinates = List.of(selectedPlan.coordinates);
    navigationManeuvers = List.of(selectedPlan.maneuvers);
    notifyListeners();

    try {
      await _ensureLocationReady();
      final bike =
          Elm327Service.instance.motorcycle ??
          await MotorcycleService.instance.fetchReconnectMotorcycle();
      if (bike == null) {
        throw StateError('Add a motorcycle before starting a ride.');
      }
      motorcycle = bike;
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          timeLimit: Duration(seconds: 20),
        ),
      );
      currentLocation = MapPoint(position.latitude, position.longitude);
      _resetRuntime(position);

      try {
        await Elm327Service.instance.startLiveMonitoring();
      } catch (_) {
        // GPS recording remains available when an adapter or ECU is offline.
      }
      ride = await _repository.startRide(
        motorcycle: bike,
        title: selectedPlan.title,
        plan: selectedPlan,
        diagnosticSessionId: Elm327Service.instance.activeSessionId,
        start: currentLocation,
      );
      await _configureVoice();
      _positionSubscription =
          Geolocator.getPositionStream(
            locationSettings: _backgroundLocationSettings(),
          ).listen(
            _onPosition,
            onError: (Object error) {
              errorMessage = 'GPS update failed: $error';
              notifyListeners();
            },
          );
      _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (status == RideRecorderStatus.recording || isPaused) {
          notifyListeners();
        }
      });
      status = RideRecorderStatus.recording;
      notifyListeners();
      unawaited(
        _speak('Ride recording started. Follow the highlighted route.'),
      );
    } catch (error) {
      status = RideRecorderStatus.idle;
      errorMessage = _friendlyError(error);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> pause() async {
    if (status != RideRecorderStatus.recording || ride == null) return;
    status = RideRecorderStatus.paused;
    _pausedAt = DateTime.now();
    _activePauseId = await _repository.startPause(
      rideId: ride!.id,
      motorcycle: motorcycle!,
      pausedAt: _pausedAt!,
    );
    await _repository.setRideStatus(ride!.id, RideStatus.paused);
    notifyListeners();
    unawaited(_speak('Ride paused. Elapsed time will continue.'));
  }

  Future<void> resume() async {
    if (status != RideRecorderStatus.paused || ride == null) return;
    final now = DateTime.now();
    if (_pausedAt != null) _pausedDuration += now.difference(_pausedAt!);
    _pausedAt = null;
    await _repository.resumePause(_activePauseId, now);
    _activePauseId = null;
    status = RideRecorderStatus.recording;
    await _repository.setRideStatus(ride!.id, RideStatus.recording);
    notifyListeners();
    unawaited(_speak('Ride resumed.'));
  }

  Future<void> finish({bool destinationReached = false}) async {
    if (!isActive || ride == null || _finishInProgress) return;
    _finishInProgress = true;
    status = RideRecorderStatus.finishing;
    notifyListeners();
    final endedAt = DateTime.now();
    try {
      if (_pausedAt != null) {
        _pausedDuration += endedAt.difference(_pausedAt!);
        _pausedAt = null;
        await _repository.resumePause(_activePauseId, endedAt);
        _activePauseId = null;
      }
      await _positionSubscription?.cancel();
      _positionSubscription = null;
      _clockTimer?.cancel();
      _clockTimer = null;
      await _flushPoints();
      try {
        await Elm327Service.instance.stopLiveMonitoring();
      } catch (_) {
        // The GPS ride result must still be saved if diagnostic sync fails.
      }

      reachedDestination = destinationReached || reachedDestination;
      if (_hasActualFuel) {
        fuelConsumedLiters = _actualFuelLiters;
        fuelIsEstimated = false;
      } else if (distanceKm > 0) {
        fuelConsumedLiters = distanceKm * _estimatedLitersPer100Km() / 100;
        fuelIsEstimated = true;
      }
      averageSpeedKph = _speedSampleCount == 0
          ? null
          : _speedTotal / _speedSampleCount;
      final diagnostic = Elm327Service.instance.evaluateCurrentHealth();
      motorcycleHealthScore = Elm327Service.instance.ecuAvailable
          ? diagnostic.$1
          : null;
      ridingScore = _calculateRidingScore();
      scoreDetails = {
        'scoring_version': 'ride-rules-v1',
        'ai_generated': false,
        'hard_accelerations': _hardAccelerationCount,
        'hard_braking_events': _hardBrakingCount,
        'idle_seconds': _idleSeconds,
        'route_completion_percent': completionPercent,
        'reached_destination': reachedDestination,
        'fuel_notice': fuelConsumedLiters == null
            ? 'Fuel unavailable.'
            : fuelIsEstimated
            ? 'Estimated from GPS distance and motorcycle engine/type; no real ECU fuel-rate data was available.'
            : 'Calculated from real ECU Mode 01 PID 5E fuel-rate data.',
        'health_issues': diagnostic.$2,
        'explanation': _scoreExplanation(),
      };
      await _repository.finishRide(
        rideId: ride!.id,
        endedAt: endedAt,
        elapsedSeconds: elapsedDuration.inSeconds,
        movingSeconds: movingDuration.inSeconds,
        pausedSeconds: pausedDuration.inSeconds,
        end: currentLocation,
        reachedDestination: reachedDestination,
        distanceKm: distanceKm,
        averageSpeedKph: averageSpeedKph,
        maximumSpeedKph: maximumSpeedKph == 0 ? null : maximumSpeedKph,
        fuelConsumedLiters: fuelConsumedLiters,
        fuelIsEstimated: fuelIsEstimated,
        completionPercent: completionPercent,
        ridingScore: ridingScore,
        motorcycleHealthScore: motorcycleHealthScore,
        scoreDetails: scoreDetails,
        routeCoordinates: traveledCoordinates,
        routePlanId: plan?.id,
      );
      status = RideRecorderStatus.completed;
      notifyListeners();
      unawaited(_speak('Ride complete. Your route and results were saved.'));
    } finally {
      _finishInProgress = false;
    }
  }

  void reset() {
    if (isActive) return;
    status = RideRecorderStatus.idle;
    plan = null;
    motorcycle = null;
    ride = null;
    errorMessage = null;
    notifyListeners();
  }

  void setVoiceMuted(bool value) {
    voiceMuted = value;
    if (value) unawaited(_tts.stop());
    notifyListeners();
  }

  Future<void> _onPosition(Position position) async {
    if (!isActive || status == RideRecorderStatus.finishing) return;
    if (position.accuracy > 100) return;
    final point = MapPoint(position.latitude, position.longitude);
    final recordedAt = position.timestamp;
    final previousPosition = _lastPosition;
    final previousAt = _lastPointAt;
    final seconds = previousAt == null
        ? 0.0
        : recordedAt.difference(previousAt).inMilliseconds / 1000;
    final segmentMeters = previousPosition == null
        ? 0.0
        : Geolocator.distanceBetween(
            previousPosition.latitude,
            previousPosition.longitude,
            position.latitude,
            position.longitude,
          );
    final gpsSpeed = position.speed.isFinite && position.speed >= 0
        ? position.speed * 3.6
        : seconds > 0
        ? segmentMeters / seconds * 3.6
        : 0.0;
    final elmSnapshot = Elm327Service.instance.ecuAvailable
        ? Elm327Service.instance.latestSnapshot
        : null;
    final bestSpeed = elmSnapshot?.vehicleSpeedKph ?? gpsSpeed;

    currentLocation = point;
    currentSpeedKph = bestSpeed.clamp(0, 500).toDouble();
    if (!isPaused && previousPosition != null && seconds > 0) {
      final impliedSpeed = segmentMeters / seconds * 3.6;
      if (segmentMeters < 1000 && impliedSpeed < 250) {
        distanceKm += segmentMeters / 1000;
      }
      if (bestSpeed > 1 || segmentMeters > 2) {
        _movingDuration += Duration(milliseconds: (seconds * 1000).round());
      }
      maximumSpeedKph = math.max(maximumSpeedKph, bestSpeed);
      _speedTotal += bestSpeed;
      _speedSampleCount++;
      final previousSpeed = _lastSpeedKph;
      if (previousSpeed != null) {
        final acceleration = ((bestSpeed - previousSpeed) / 3.6) / seconds;
        if (acceleration > 3.5) _hardAccelerationCount++;
        if (acceleration < -4.5) _hardBrakingCount++;
      }
      if (bestSpeed < 1 && (elmSnapshot?.engineRpm ?? 0) > 500) {
        _idleSeconds += seconds.round();
      }
      final fuelRate = elmSnapshot?.fuelRateLitersPerHour;
      if (fuelRate != null) {
        _actualFuelLiters += fuelRate * seconds / 3600;
        _hasActualFuel = true;
      }
      _lastSpeedKph = bestSpeed;
      traveledCoordinates.add(point);
    }

    final sample = RidePointSample(
      sequenceNumber: _sequence++,
      recordedAt: recordedAt,
      location: point,
      isPaused: isPaused,
      altitudeM: position.altitude,
      accuracyM: position.accuracy,
      bearingDegrees: position.heading >= 0 ? position.heading : null,
      gpsSpeedKph: gpsSpeed,
      engineRpm: elmSnapshot?.engineRpm,
      ecuSpeedKph: elmSnapshot?.vehicleSpeedKph,
      coolantTemperatureC: elmSnapshot?.coolantTemperatureC,
      fuelLevelPercent: elmSnapshot?.fuelLevelPercent,
      fuelRateLph: elmSnapshot?.fuelRateLitersPerHour,
      controlModuleVoltage: elmSnapshot?.controlModuleVoltage,
    );
    _pointBatch.add(sample);
    _lastPosition = position;
    _lastPointAt = recordedAt;
    _updateNavigation(point);
    if (_pointBatch.length >= 10) await _flushPoints();
    notifyListeners();
  }

  void _updateNavigation(MapPoint location) {
    if (navigationCoordinates.isEmpty) return;
    final oldIndex = _closestRouteIndex;
    final start = math.max(0, oldIndex - 30);
    final end = math.min(navigationCoordinates.length, oldIndex + 600);
    var closest = oldIndex.clamp(0, navigationCoordinates.length - 1);
    var closestDistance = double.infinity;
    for (var index = start; index < end; index++) {
      final distance = _distanceMeters(location, navigationCoordinates[index]);
      if (distance < closestDistance) {
        closestDistance = distance;
        closest = index;
      }
    }
    if (closest >= oldIndex || closestDistance < 35) {
      _closestRouteIndex = closest;
    }
    while (_activeManeuverIndex < navigationManeuvers.length - 1 &&
        navigationManeuvers[_activeManeuverIndex].endShapeIndex <
            _closestRouteIndex) {
      _activeManeuverIndex++;
    }
    _announceManeuver();

    if (closestDistance > 120 && !isPaused) {
      _offRouteSamples++;
      if (_offRouteSamples >= 3 && !_rerouting && plan != null) {
        unawaited(_reroute(location));
      }
    } else {
      _offRouteSamples = 0;
    }

    final destinationDistance = _distanceMeters(location, plan!.destination);
    if (!_finishInProgress &&
        completionPercent >= 85 &&
        distanceKm >= 0.1 &&
        destinationDistance <= 80) {
      reachedDestination = true;
      unawaited(finish(destinationReached: true));
    }
  }

  Future<void> _reroute(MapPoint location) async {
    _rerouting = true;
    try {
      final route = await RoutingService.instance.reroute(
        current: location,
        destination: plan!.destination,
        preference: plan!.preference,
      );
      navigationCoordinates = route.coordinates;
      navigationManeuvers = route.maneuvers;
      _closestRouteIndex = 0;
      _activeManeuverIndex = 0;
      _spokenPrompts.clear();
      _offRouteSamples = 0;
      unawaited(_speak('Route updated.'));
      notifyListeners();
    } catch (_) {
      _offRouteSamples = 0;
    } finally {
      _rerouting = false;
    }
  }

  void _announceManeuver() {
    final maneuver = currentManeuver;
    final distance = distanceToNextManeuverMeters;
    if (maneuver == null || distance == null) return;
    final stage = distance <= 90
        ? 'near'
        : distance <= 450
        ? 'approach'
        : null;
    if (stage == null) return;
    final key = '$_activeManeuverIndex:$stage';
    if (_spokenPrompts.add(key)) {
      final prefix = stage == 'near'
          ? 'In ${distance.round()} meters, '
          : 'In ${(distance / 50).round() * 50} meters, ';
      unawaited(_speak('$prefix${maneuver.voiceInstruction}'));
    }
  }

  Future<void> _flushPoints() async {
    if (_pointBatch.isEmpty || ride == null || motorcycle == null) return;
    final batch = List<RidePointSample>.from(_pointBatch);
    _pointBatch.clear();
    await _repository.savePoints(
      rideId: ride!.id,
      motorcycle: motorcycle!,
      points: batch,
    );
  }

  void _resetRuntime(Position initial) {
    _startedAt = DateTime.now();
    _lastPointAt = initial.timestamp;
    _lastPosition = initial;
    _pausedAt = null;
    _pausedDuration = Duration.zero;
    _movingDuration = Duration.zero;
    _sequence = 0;
    _speedSampleCount = 0;
    _speedTotal = 0;
    _actualFuelLiters = 0;
    _hasActualFuel = false;
    _hardAccelerationCount = 0;
    _hardBrakingCount = 0;
    _idleSeconds = 0;
    _lastSpeedKph = null;
    _activePauseId = null;
    _pointBatch.clear();
    traveledCoordinates
      ..clear()
      ..add(MapPoint(initial.latitude, initial.longitude));
    _closestRouteIndex = 0;
    _activeManeuverIndex = 0;
    _offRouteSamples = 0;
    _spokenPrompts.clear();
    distanceKm = 0;
    maximumSpeedKph = 0;
    averageSpeedKph = null;
    fuelConsumedLiters = null;
    fuelIsEstimated = false;
    reachedDestination = false;
    ridingScore = 0;
    motorcycleHealthScore = null;
    scoreDetails = const {};
  }

  Future<void> _ensureLocationReady() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw StateError('Turn on Location Services before starting the ride.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError(
          'Precise location permission is required to record and navigate rides.',
        );
      }
      if (!kIsWeb && permission == LocationPermission.whileInUse) {
        permission = await Geolocator.requestPermission();
        if (permission != LocationPermission.always) {
          throw StateError(
            'Set MotoMap Location permission to “Allow all the time” so an '
            'active ride continues when the screen is locked. Open phone '
            'Settings, update the permission, then press Start again.',
          );
        }
      }
    } on MissingPluginException {
      throw StateError(
        'The location component was not loaded. Fully close MotoMap and install '
        'the latest app build; hot reload cannot add a native plugin.',
      );
    }
  }

  LocationSettings _backgroundLocationSettings() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
        intervalDuration: const Duration(seconds: 2),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'MotoMap ride recording',
          notificationText: 'GPS route and motorcycle data are being recorded.',
          enableWakeLock: true,
        ),
      );
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        activityType: ActivityType.automotiveNavigation,
        distanceFilter: 5,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 5,
    );
  }

  Future<void> _configureVoice() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.48);
    await _tts.setVolume(1);
    await _tts.awaitSpeakCompletion(false);
  }

  Future<void> _speak(String text) async {
    if (voiceMuted || text.trim().isEmpty) return;
    await _tts.stop();
    await _tts.speak(text);
  }

  int _calculateRidingScore() {
    var score = 100;
    score -= math.min(20, _hardAccelerationCount * 2);
    score -= math.min(25, _hardBrakingCount * 3);
    score -= math.min(15, (_idleSeconds / 120).floor() * 2);
    if (plan != null && completionPercent < 80) score -= 10;
    if (Elm327Service.instance.latestTroubleCodes.isNotEmpty) score -= 10;
    return score.clamp(0, 100);
  }

  List<String> _scoreExplanation() {
    final items = <String>[];
    items.add(
      _hardAccelerationCount == 0
          ? 'Acceleration was smooth in recorded GPS/ECU samples.'
          : '$_hardAccelerationCount hard acceleration event(s) reduced the score.',
    );
    items.add(
      _hardBrakingCount == 0
          ? 'No hard braking was detected.'
          : '$_hardBrakingCount hard braking event(s) reduced the score.',
    );
    if (_idleSeconds > 0) {
      items.add('${_idleSeconds}s of engine idling was detected.');
    }
    items.add(
      fuelIsEstimated
          ? 'Fuel is an estimate because the ECU did not provide PID 5E.'
          : 'Fuel used real ECU fuel-rate readings when available.',
    );
    return items;
  }

  double _estimatedLitersPer100Km() {
    final bike = motorcycle;
    if (bike == null) return 4;
    final displacement = bike.engineDisplacementCc;
    if (bike.type == 'scooter') return 2.5;
    if (displacement == null) return 4;
    if (displacement <= 250) return 3;
    if (displacement <= 500) return 4;
    if (displacement <= 1000) return 5;
    return 6.5;
  }

  static double _distanceMeters(MapPoint first, MapPoint second) =>
      Geolocator.distanceBetween(
        first.latitude,
        first.longitude,
        second.latitude,
        second.longitude,
      );

  static String _friendlyError(Object error) {
    final text = error.toString();
    return text.startsWith('Bad state: ') ? text.substring(11) : text;
  }
}
