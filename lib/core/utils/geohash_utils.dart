import 'package:latlong2/latlong.dart';

/// Standard Geohash precision and spatial cell utilities for client-side viewport subscription.
class GeohashUtils {
  static const String base32Alphabet = '0123456789bcdefghjkmnpqrstuvwxyz';

  /// Encodes latitude and longitude into a standard base32 geohash string.
  static String encode(double latitude, double longitude, [int precision = 6]) {
    if (precision <= 0) return '';
    double minLat = -90.0, maxLat = 90.0;
    double minLng = -180.0, maxLng = 180.0;

    final buffer = StringBuffer();
    bool isLng = true;
    int ch = 0;
    int bit = 0;

    while (buffer.length < precision) {
      if (isLng) {
        final mid = (minLng + maxLng) / 2.0;
        if (longitude >= mid) {
          ch |= 1 << (4 - bit);
          minLng = mid;
        } else {
          maxLng = mid;
        }
      } else {
        final mid = (minLat + maxLat) / 2.0;
        if (latitude >= mid) {
          ch |= 1 << (4 - bit);
          minLat = mid;
        } else {
          maxLat = mid;
        }
      }
      isLng = !isLng;
      bit++;

      if (bit == 5) {
        buffer.write(base32Alphabet[ch]);
        bit = 0;
        ch = 0;
      }
    }

    return buffer.toString();
  }

  /// Calculates the 8 surrounding neighbor cells for a given geohash.
  static List<String> neighbors(String hash) {
    if (hash.isEmpty) return const [];
    final bounds = decodeBounds(hash);
    final centerLat = (bounds.minLat + bounds.maxLat) / 2.0;
    final centerLng = (bounds.minLng + bounds.maxLng) / 2.0;
    final latSpan = bounds.maxLat - bounds.minLat;
    final lngSpan = bounds.maxLng - bounds.minLng;
    final precision = hash.length;

    final offsets = [
      [latSpan, 0.0],
      [-latSpan, 0.0],
      [0.0, lngSpan],
      [0.0, -lngSpan],
      [latSpan, lngSpan],
      [latSpan, -lngSpan],
      [-latSpan, lngSpan],
      [-latSpan, -lngSpan],
    ];

    final result = <String>[];
    final seen = <String>{};

    for (final offset in offsets) {
      double nLat = centerLat + offset[0];
      double nLng = centerLng + offset[1];

      if (nLat > 90.0) nLat = 90.0;
      if (nLat < -90.0) nLat = -90.0;
      while (nLng > 180.0) {
        nLng -= 360.0;
      }
      while (nLng < -180.0) {
        nLng += 360.0;
      }

      final neighborHash = encode(nLat, nLng, precision);
      if (neighborHash != hash && !seen.contains(neighborHash)) {
        seen.add(neighborHash);
        result.add(neighborHash);
      }
    }

    return result;
  }

  /// Decodes bounding box for a geohash.
  static ({double minLat, double maxLat, double minLng, double maxLng}) decodeBounds(String hash) {
    double minLat = -90.0, maxLat = 90.0;
    double minLng = -180.0, maxLng = 180.0;
    bool isLng = true;

    for (int i = 0; i < hash.length; i++) {
      final val = base32Alphabet.indexOf(hash[i]);
      if (val < 0) continue;

      for (int bit = 4; bit >= 0; bit--) {
        final mask = 1 << bit;
        if (isLng) {
          final mid = (minLng + maxLng) / 2.0;
          if ((val & mask) != 0) {
            minLng = mid;
          } else {
            maxLng = mid;
          }
        } else {
          final mid = (minLat + maxLat) / 2.0;
          if ((val & mask) != 0) {
            minLat = mid;
          } else {
            maxLat = mid;
          }
        }
        isLng = !isLng;
      }
    }

    return (minLat: minLat, maxLat: maxLat, minLng: minLng, maxLng: maxLng);
  }

  /// Computes precision 6 cells covering a viewport center and its immediate perimeter.
  static List<String> computeViewportCells(LatLng center) {
    final centerCell = encode(center.latitude, center.longitude, 6);
    final n = neighbors(centerCell);
    return [centerCell, ...n];
  }
}
