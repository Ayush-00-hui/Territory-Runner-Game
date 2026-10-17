import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:latlong2/latlong.dart';
import '../ui/theme/app_colors.dart';

class Territory {
  final String id;
  final String ownerId;
  final List<LatLng> polygon;
  final List<List<LatLng>> polygons;
  final double areaSqMeters;
  final DateTime capturedAt;
  final DateTime lastDefendedAt;
  final double strength; // 0.0 - 100.0
  final Color color;
  final bool isPendingReview;

  /// Retention & Decay Mechanics Constants
  static const double defaultInitialStrength = 100.0;
  static const double decayPerDay = 15.0; // Loses 15.0 points per 24 hours since last defended
  static const double weakThreshold = 30.0; // Below this threshold, rivals take weak territory with bonus XP

  Territory({
    required this.id,
    required this.ownerId,
    required this.polygon,
    List<List<LatLng>>? polygons,
    required this.areaSqMeters,
    required this.capturedAt,
    DateTime? lastDefendedAt,
    double? strength,
    this.color = AppColors.mine,
    this.isPendingReview = false,
  })  : polygons = polygons ?? (polygon.isNotEmpty ? [polygon] : []),
        lastDefendedAt = lastDefendedAt ?? capturedAt,
        strength = (strength ?? defaultInitialStrength).clamp(0.0, 100.0);

  /// Computes real-time dynamic strength factoring in elapsed days since last defense
  double computeCurrentStrength({DateTime? now}) {
    final currentTime = now ?? DateTime.now();
    final diff = currentTime.difference(lastDefendedAt);
    if (diff.isNegative) return strength.clamp(0.0, 100.0);
    final days = diff.inMilliseconds / (1000.0 * 60 * 60 * 24);
    final decayed = strength - (days * decayPerDay);
    return decayed.clamp(0.0, 100.0);
  }

  /// Returns true if dynamic strength has fallen below the weak fortification threshold
  bool isWeak({DateTime? now}) => computeCurrentStrength(now: now) < weakThreshold;

  Territory copyWith({
    String? id,
    String? ownerId,
    List<LatLng>? polygon,
    List<List<LatLng>>? polygons,
    double? areaSqMeters,
    DateTime? capturedAt,
    DateTime? lastDefendedAt,
    double? strength,
    Color? color,
    bool? isPendingReview,
  }) {
    return Territory(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      polygon: polygon ?? this.polygon,
      polygons: polygons ?? this.polygons,
      areaSqMeters: areaSqMeters ?? this.areaSqMeters,
      capturedAt: capturedAt ?? this.capturedAt,
      lastDefendedAt: lastDefendedAt ?? this.lastDefendedAt,
      strength: strength ?? this.strength,
      color: color ?? this.color,
      isPendingReview: isPendingReview ?? this.isPendingReview,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'ownerId': ownerId,
    'polygon': polygon.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList(),
    'polygons': polygons.map((poly) => poly.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList()).toList(),
    'areaSqMeters': areaSqMeters,
    'capturedAt': capturedAt.toIso8601String(),
    'lastDefendedAt': lastDefendedAt.toIso8601String(),
    'strength': strength,
    'color': color.toARGB32(),
    'isPendingReview': isPendingReview,
  };

  factory Territory.fromJson(Map<String, dynamic> json) {
    final rawPolygon = json['polygon'] as List<dynamic>? ?? [];
    final List<LatLng> points = rawPolygon.map((p) {
      final map = p as Map<String, dynamic>;
      return LatLng((map['lat'] as num).toDouble(), (map['lng'] as num).toDouble());
    }).toList();

    final rawPolygons = json['polygons'] as List<dynamic>?;
    List<List<LatLng>> multiPolys = [];
    if (rawPolygons != null) {
      multiPolys = rawPolygons.map((polyList) {
        final list = polyList as List<dynamic>;
        return list.map((p) {
          final map = p as Map<String, dynamic>;
          return LatLng((map['lat'] as num).toDouble(), (map['lng'] as num).toDouble());
        }).toList();
      }).toList();
    } else if (points.isNotEmpty) {
      multiPolys = [points];
    }

    final captured = json['capturedAt'] != null
        ? DateTime.parse(json['capturedAt'] as String)
        : DateTime.now();
    final defended = json['lastDefendedAt'] != null
        ? DateTime.parse(json['lastDefendedAt'] as String)
        : captured;
    final parsedStrength = (json['strength'] as num?)?.toDouble() ?? defaultInitialStrength;

    return Territory(
      id: json['id'] as String,
      ownerId: json['ownerId'] as String? ?? 'anonymous_runner',
      polygon: points.isNotEmpty ? points : (multiPolys.isNotEmpty ? multiPolys.first : []),
      polygons: multiPolys,
      areaSqMeters: (json['areaSqMeters'] as num?)?.toDouble() ?? 15047.0,
      capturedAt: captured,
      lastDefendedAt: defended,
      strength: parsedStrength,
      color: json['color'] != null ? Color(json['color'] as int) : AppColors.mine,
      isPendingReview: json['isPendingReview'] as bool? ?? false,
    );
  }
}

/// Hive TypeAdapter for [Territory] with backward compatibility for legacy schemas
class TerritoryAdapter extends TypeAdapter<Territory> {
  @override
  final int typeId = 0;

  @override
  Territory read(BinaryReader reader) {
    final int numOfFields = reader.readByte();
    final Map<int, dynamic> fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    final List<dynamic> rawPoly = (fields[2] as List?) ?? [];
    final List<LatLng> polyPoints = rawPoly.map((p) {
      if (p is Map) {
        return LatLng((p['lat'] as num).toDouble(), (p['lng'] as num).toDouble());
      }
      return const LatLng(0, 0);
    }).toList();

    final capturedAt = DateTime.fromMillisecondsSinceEpoch(fields[4] as int);
    final lastDefendedAt = fields[7] != null
        ? DateTime.fromMillisecondsSinceEpoch(fields[7] as int)
        : capturedAt;
    final strength = (fields[8] as num?)?.toDouble() ?? Territory.defaultInitialStrength;

    return Territory(
      id: fields[0] as String,
      ownerId: fields[1] as String,
      polygon: polyPoints,
      areaSqMeters: (fields[3] as num).toDouble(),
      capturedAt: capturedAt,
      lastDefendedAt: lastDefendedAt,
      strength: strength,
      color: Color(fields[5] as int),
      isPendingReview: (fields[6] as bool?) ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, Territory obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.ownerId)
      ..writeByte(2)
      ..write(obj.polygon.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList())
      ..writeByte(3)
      ..write(obj.areaSqMeters)
      ..writeByte(4)
      ..write(obj.capturedAt.millisecondsSinceEpoch)
      ..writeByte(5)
      ..write(obj.color.toARGB32())
      ..writeByte(6)
      ..write(obj.isPendingReview)
      ..writeByte(7)
      ..write(obj.lastDefendedAt.millisecondsSinceEpoch)
      ..writeByte(8)
      ..write(obj.strength);
  }
}
