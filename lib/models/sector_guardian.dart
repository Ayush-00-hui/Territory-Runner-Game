import 'package:latlong2/latlong.dart';

/// Asynchronous Ghost Boss representing the record-holding athlete of a city sector.
class SectorGuardian {
  final String sectorId;
  final String districtName;
  final String guardianName;
  final String faction;
  final double recordTimeSeconds;
  final double distanceKm;
  final double averagePaceMinPerKm;
  final List<LatLng> routePoints;

  const SectorGuardian({
    required this.sectorId,
    required this.districtName,
    required this.guardianName,
    required this.faction,
    required this.recordTimeSeconds,
    required this.distanceKm,
    required this.averagePaceMinPerKm,
    required this.routePoints,
  });

  String get recordTimeString {
    final minutes = (recordTimeSeconds / 60).floor();
    final seconds = (recordTimeSeconds % 60).round();
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String get paceString {
    final minutes = averagePaceMinPerKm.floor();
    final seconds = ((averagePaceMinPerKm - minutes) * 60).round();
    return '$minutes:${seconds.toString().padLeft(2, '0')}/km';
  }
}
