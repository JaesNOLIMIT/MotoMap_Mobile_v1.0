import 'package:flutter_test/flutter_test.dart';
import 'package:motomap_mobile/models/ride_data.dart';
import 'package:motomap_mobile/services/routing_service.dart';

void main() {
  group('smart route prompt parser', () {
    test('extracts loop distance and scenic preference', () {
      final intent = RoutingService.instance.parsePrompt(
        'Make an 80 km scenic loop with mountain views',
      );

      expect(intent.isLoop, isTrue);
      expect(intent.distanceKm, 80);
      expect(intent.preference, RoutePreference.scenic);
      expect(intent.destinationQuery, isNull);
    });

    test('extracts a destination and curvy preference', () {
      final intent = RoutingService.instance.parsePrompt(
        'Ride to Tagaytay using curvy roads',
      );

      expect(intent.isLoop, isFalse);
      expect(intent.destinationQuery, 'Tagaytay');
      expect(intent.preference, RoutePreference.curvy);
    });
  });

  test('decodes an encoded route shape', () {
    final points = RoutingService.decodePolyline(
      r'_p~iF~ps|U_ulLnnqC_mqNvxq`@',
      precision: 5,
    );

    expect(points, hasLength(3));
    expect(points.first.latitude, closeTo(38.5, 0.00001));
    expect(points.first.longitude, closeTo(-120.2, 0.00001));
    expect(points.last.latitude, closeTo(43.252, 0.00001));
    expect(points.last.longitude, closeTo(-126.453, 0.00001));
  });
}
