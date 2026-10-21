import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:territory_runner/services/gps_quality_service.dart';

void main() {
  group('GpsQualityService Tests', () {
    test(
      'evaluateQuality returns optimal when accuracy <= 10m and fix is recent',
      () {
        final now = DateTime.now();
        final quality = GpsQualityService.evaluateQuality(
          accuracyMeters: 4.5,
          lastFixTimestamp: now.subtract(const Duration(seconds: 2)),
          now: now,
        );
        expect(quality, equals(GpsQuality.optimal));
      },
    );

    test(
      'evaluateQuality returns fair when accuracy is between 10m and 30m',
      () {
        final now = DateTime.now();
        final quality = GpsQualityService.evaluateQuality(
          accuracyMeters: 18.0,
          lastFixTimestamp: now.subtract(const Duration(seconds: 3)),
          now: now,
        );
        expect(quality, equals(GpsQuality.fair));
      },
    );

    test('evaluateQuality returns degraded when accuracy > 30m', () {
      final now = DateTime.now();
      final quality = GpsQualityService.evaluateQuality(
        accuracyMeters: 45.0,
        lastFixTimestamp: now.subtract(const Duration(seconds: 2)),
        now: now,
      );
      expect(quality, equals(GpsQuality.degraded));
    });

    test('evaluateQuality returns lost when fix is older than 15s timeout (tunnel/indoor)', () {
      final now = DateTime.now();
      final quality = GpsQualityService.evaluateQuality(
        accuracyMeters: 5.0,
        lastFixTimestamp: now.subtract(const Duration(seconds: 25)),
        now: now,
      );
      expect(quality, equals(GpsQuality.lost));
    });

    test(
      'isSignalGap accurately identifies intervals exceeding 15 seconds',
      () {
        final t1 = DateTime(2026, 10, 16, 12, 0, 0);
        final t2Normal = DateTime(2026, 10, 16, 12, 0, 5);
        final t2Gap = DateTime(2026, 10, 16, 12, 0, 25);

        expect(GpsQualityService.isSignalGap(t1, t2Normal), isFalse);
        expect(GpsQualityService.isSignalGap(t1, t2Gap), isTrue);
      },
    );

    test('isUnrealisticJump flags teleportation speeds across signal gaps', () {
      const p1 = LatLng(51.5000, -0.1200);
      // ~70m away in 20 seconds = ~12.6 km/h (realistic runner pace)
      const pNormal = LatLng(51.5005, -0.1205);
      expect(GpsQualityService.isUnrealisticJump(p1, pNormal, 20.0), isFalse);

      // ~1000m away in 10 seconds = ~360 km/h (teleportation/vehicle jump)
      const pTeleport = LatLng(51.5100, -0.1200);
      expect(GpsQualityService.isUnrealisticJump(p1, pTeleport, 10.0), isTrue);
    });

    test('isStationary correctly identifies low speeds (< 1.5 km/h) for auto-pause', () {
      expect(GpsQualityService.isStationary(0.2), isTrue);
      expect(GpsQualityService.isStationary(1.2), isTrue);
      expect(GpsQualityService.isStationary(2.5), isFalse);
      expect(GpsQualityService.isStationary(10.0), isFalse);
    });
  });
}
