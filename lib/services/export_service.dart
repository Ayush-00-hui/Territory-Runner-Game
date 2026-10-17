import 'dart:convert';
import 'dart:io';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/territory.dart';
import 'privacy_zone_service.dart';

/// Service responsible for generating industry-standard GPX 1.1 and GeoJSON files
/// for runs and captured territories, including automatic privacy zone redaction.
class ExportService {
  static final ExportService _instance = ExportService._internal();
  factory ExportService() => _instance;

  ExportService._internal();

  final PrivacyZoneService _privacyService = PrivacyZoneService();

  /// Generates a valid GPX 1.1 XML string from GPS points.
  /// When [applyPrivacyRedaction] is true, coordinates within active privacy zones are excluded.
  String generateGpx({
    required String runTitle,
    required List<LatLng> coordinates,
    List<DateTime>? timestamps,
    List<double>? elevations,
    bool applyPrivacyRedaction = true,
  }) {
    List<LatLng> effectivePoints = coordinates;
    if (applyPrivacyRedaction) {
      effectivePoints = _privacyService.filterGpsTrack(coordinates);
    }

    final buffer = StringBuffer();
    final nowIso = DateTime.now().toUtc().toIso8601String();

    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<gpx version="1.1" creator="Territory Runner" xmlns="http://www.topografix.com/GPX/1/1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">');
    buffer.writeln('  <metadata>');
    buffer.writeln('    <name>${_escapeXml(runTitle)}</name>');
    buffer.writeln('    <time>$nowIso</time>');
    buffer.writeln('  </metadata>');
    buffer.writeln('  <trk>');
    buffer.writeln('    <name>${_escapeXml(runTitle)}</name>');
    buffer.writeln('    <type>running</type>');
    buffer.writeln('    <trkseg>');

    for (int i = 0; i < effectivePoints.length; i++) {
      final pt = effectivePoints[i];
      buffer.write('      <trkpt lat="${pt.latitude.toStringAsFixed(7)}" lon="${pt.longitude.toStringAsFixed(7)}">');

      if (elevations != null && i < elevations.length) {
        buffer.write('<ele>${elevations[i].toStringAsFixed(1)}</ele>');
      }

      if (timestamps != null && i < timestamps.length) {
        buffer.write('<time>${timestamps[i].toUtc().toIso8601String()}</time>');
      }

      buffer.writeln('</trkpt>');
    }

    buffer.writeln('    </trkseg>');
    buffer.writeln('  </trk>');
    buffer.writeln('</gpx>');

    return buffer.toString();
  }

  /// Generates a valid RFC 7946 GeoJSON FeatureCollection containing polygons for territories
  /// and an optional LineString for the run path.
  String generateGeoJson({
    required List<Territory> territories,
    List<LatLng>? runTrack,
    bool applyPrivacyRedaction = true,
  }) {
    List<Territory> effectiveTerritories = territories;
    List<LatLng>? effectiveTrack = runTrack;

    if (applyPrivacyRedaction) {
      effectiveTerritories = _privacyService.filterTerritories(territories);
      if (runTrack != null) {
        effectiveTrack = _privacyService.filterGpsTrack(runTrack);
      }
    }

    final List<Map<String, dynamic>> features = [];

    // Add each territory polygon
    for (final territory in effectiveTerritories) {
      if (territory.polygon.length < 3) continue;

      // Ensure ring is closed in GeoJSON specification
      final ring = territory.polygon.map((p) => [p.longitude, p.latitude]).toList();
      if (ring.first[0] != ring.last[0] || ring.first[1] != ring.last[1]) {
        ring.add([ring.first[0], ring.first[1]]);
      }

      features.add({
        'type': 'Feature',
        'id': territory.id,
        'properties': {
          'id': territory.id,
          'owner_id': territory.ownerId,
          'area_sq_meters': territory.areaSqMeters,
          'captured_at': territory.capturedAt.toUtc().toIso8601String(),
          'color_hex': '#${territory.color.toARGB32().toRadixString(16).padLeft(8, '0')}',
        },
        'geometry': {
          'type': 'Polygon',
          'coordinates': [ring],
        },
      });
    }

    // Add run track if present
    if (effectiveTrack != null && effectiveTrack.isNotEmpty) {
      features.add({
        'type': 'Feature',
        'properties': {
          'name': 'GPS Run Track',
          'type': 'run_track',
          'point_count': effectiveTrack.length,
        },
        'geometry': {
          'type': 'LineString',
          'coordinates': effectiveTrack.map((p) => [p.longitude, p.latitude]).toList(),
        },
      });
    }

    final geoJsonMap = {
      'type': 'FeatureCollection',
      'generator': 'Territory Runner',
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'features': features,
    };

    return const JsonEncoder.withIndent('  ').convert(geoJsonMap);
  }

  /// Exports GPX string to a file and opens system share dialog
  Future<File> exportAndShareGpx({
    required String runTitle,
    required List<LatLng> coordinates,
    List<DateTime>? timestamps,
    List<double>? elevations,
    bool applyPrivacyRedaction = true,
  }) async {
    final gpxContent = generateGpx(
      runTitle: runTitle,
      coordinates: coordinates,
      timestamps: timestamps,
      elevations: elevations,
      applyPrivacyRedaction: applyPrivacyRedaction,
    );

    final tempDir = await getTemporaryDirectory();
    final fileName = 'territory_run_${DateTime.now().millisecondsSinceEpoch}.gpx';
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsString(gpxContent, flush: true);

    final xFile = XFile(file.path, mimeType: 'application/gpx+xml');
    await SharePlus.instance.share(
      ShareParams(
        files: [xFile],
        text: 'Exported GPX track for "$runTitle" from Territory Runner',
      ),
    );

    return file;
  }

  /// Exports GeoJSON string to a file and opens system share dialog
  Future<File> exportAndShareGeoJson({
    required List<Territory> territories,
    List<LatLng>? runTrack,
    bool applyPrivacyRedaction = true,
  }) async {
    final geoJsonContent = generateGeoJson(
      territories: territories,
      runTrack: runTrack,
      applyPrivacyRedaction: applyPrivacyRedaction,
    );

    final tempDir = await getTemporaryDirectory();
    final fileName = 'territories_${DateTime.now().millisecondsSinceEpoch}.geojson';
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsString(geoJsonContent, flush: true);

    final xFile = XFile(file.path, mimeType: 'application/geo+json');
    await SharePlus.instance.share(
      ShareParams(
        files: [xFile],
        text: 'Exported territories and GPS boundaries from Territory Runner',
      ),
    );

    return file;
  }

  String _escapeXml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
