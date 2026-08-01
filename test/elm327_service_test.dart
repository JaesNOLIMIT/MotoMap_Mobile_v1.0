import 'package:flutter_test/flutter_test.dart';
import 'package:motomap_mobile/models/diagnostic_data.dart';
import 'package:motomap_mobile/services/elm327_service.dart';

void main() {
  group('ELM327 response parsing', () {
    test('normalizes command echo and prompt', () {
      expect(
        Elm327Service.normalizeResponse(
          '010C\r41 0C 1A F8\r>\r',
          command: '010C',
        ),
        '41 0C 1A F8',
      );
    });

    test('parses mode 01 PID bytes', () {
      expect(Elm327Service.parseMode01Bytes('41 0C 1A F8', 0x0C), [0x1A, 0xF8]);
    });

    test('parses powertrain trouble codes', () {
      final codes = Elm327Service.parseTroubleCodes('43 01 71 03 00 00 00');
      expect(codes.map((code) => code.code), ['P0171', 'P0300']);
    });

    test('parses adapter voltage', () {
      expect(Elm327Service.parseVoltage('12.7V'), 12.7);
    });
  });

  group('pre-ride scoring', () {
    test('penalizes low voltage and active DTCs', () {
      final result = Elm327Service.score(
        DiagnosticSnapshot(
          recordedAt: DateTime.utc(2026, 8, 1),
          controlModuleVoltage: 11.2,
          engineRpm: 1200,
        ),
        const [DiagnosticTroubleCode(code: 'P0560', status: 'active')],
      );

      expect(result.$1, 65);
      expect(result.$2, hasLength(2));
    });
  });

  group('stored diagnostic summaries', () {
    test('keeps unsupported fuel and distance values unavailable', () {
      final summary = DiagnosticSessionSummary.fromSnapshot(
        DiagnosticSnapshot(
          recordedAt: DateTime.utc(2026, 8, 2),
          engineRpm: 1500,
          fuelLevelPercent: 72,
        ),
        const [],
      );

      expect(summary.distanceKm, isNull);
      expect(summary.fuelConsumedLiters, isNull);
      expect(summary.averageEngineRpm, 1500);
      expect(summary.endingFuelLevelPercent, 72);
    });

    test('totals only recorded rides with available measurements', () {
      final history = [
        DiagnosticHistoryEntry(
          id: 'ride-1',
          type: 'ride',
          startedAt: DateTime.utc(2026, 8, 2),
          scoreDetails: const {},
          sampleCount: 3,
          troubleCodeCount: 0,
          troubleCodes: const [],
          distanceKm: 12.5,
          fuelConsumedLiters: 0.6,
        ),
        DiagnosticHistoryEntry(
          id: 'check-1',
          type: 'pre_ride',
          startedAt: DateTime.utc(2026, 8, 2),
          scoreDetails: const {},
          sampleCount: 1,
          troubleCodeCount: 0,
          troubleCodes: const [],
          distanceKm: 99,
        ),
      ];

      final usage = MotorcycleUsageSummary.fromHistory(history);
      expect(usage.recordedRideCount, 1);
      expect(usage.totalDistanceKm, 12.5);
      expect(usage.totalFuelConsumedLiters, 0.6);
    });
  });
}
