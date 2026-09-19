import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class NearbyRunner {
  final String id;
  final String name;
  final LatLng position;
  final String pace;
  final int level;
  final String status;
  final String avatar;
  final Color color;

  NearbyRunner({
    required this.id,
    required this.name,
    required this.position,
    required this.pace,
    required this.level,
    required this.status,
    required this.avatar,
    required this.color,
  });

  String formattedDistanceTo(LatLng userPos) {
    final double distMeters = Geolocator.distanceBetween(
      userPos.latitude,
      userPos.longitude,
      position.latitude,
      position.longitude,
    );
    if (distMeters < 1000) {
      return '${distMeters.round()}m away';
    }
    return '${(distMeters / 1000).toStringAsFixed(1)} km away';
  }
}

/// Team & Nearby Runner Proximity Service (100% Free & Local + Firestore ready)
class TeamService {
  static final TeamService _instance = TeamService._internal();
  factory TeamService() => _instance;

  TeamService._internal();

  /// Gets dynamically situated nearby runners relative to user position
  List<NearbyRunner> getNearbyRunners(LatLng userPos) {
    // Generate realistic proximity offsets around user's coordinates
    final offsets = [
      {'dLat': 0.0028, 'dLng': 0.0019, 'name': 'Nova_Strider', 'pace': "5'12\"/km", 'lvl': 4, 'avatar': 'N', 'color': const Color(0xFF00F0FF), 'status': 'Running in your sector'},
      {'dLat': -0.0045, 'dLng': 0.0032, 'name': 'HexVeloCity', 'pace': "5'45\"/km", 'lvl': 6, 'avatar': 'H', 'color': const Color(0xFF8A2BE2), 'status': 'Conquered 3 hexes today'},
      {'dLat': 0.0075, 'dLng': -0.0062, 'name': 'AeroKnight', 'pace': "6'10\"/km", 'lvl': 2, 'avatar': 'A', 'color': const Color(0xFFFF0055), 'status': 'Active warm-up'},
      {'dLat': -0.0110, 'dLng': -0.0090, 'name': 'CyberPhantom', 'pace': "4'55\"/km", 'lvl': 9, 'avatar': 'C', 'color': const Color(0xFF00FF88), 'status': 'On a 7-day streak'},
    ];

    return offsets.map((data) {
      final double lat = userPos.latitude + (data['dLat'] as double);
      final double lng = userPos.longitude + (data['dLng'] as double);
      return NearbyRunner(
        id: data['name'] as String,
        name: data['name'] as String,
        position: LatLng(lat, lng),
        pace: data['pace'] as String,
        level: data['lvl'] as int,
        status: data['status'] as String,
        avatar: data['avatar'] as String,
        color: data['color'] as Color,
      );
    }).toList();
  }
}
