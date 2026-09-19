import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:latlong2/latlong.dart';

class Territory {
  final String id;
  final String ownerId;
  final List<LatLng> polygon;
  final double areaSqMeters;
  final DateTime capturedAt;
  final Color color;
  final bool isPendingReview;

  Territory({
    required this.id,
    required this.ownerId,
    required this.polygon,
    required this.areaSqMeters,
    required this.capturedAt,
    this.color = const Color(0xFF00F0FF),
    this.isPendingReview = false,
  });

  Territory copyWith({
    String? id,
    String? ownerId,
    List<LatLng>? polygon,
    double? areaSqMeters,
    DateTime? capturedAt,
    Color? color,
    bool? isPendingReview,
  }) {
    return Territory(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      polygon: polygon ?? this.polygon,
      areaSqMeters: areaSqMeters ?? this.areaSqMeters,
      capturedAt: capturedAt ?? this.capturedAt,
      color: color ?? this.color,
      isPendingReview: isPendingReview ?? this.isPendingReview,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'ownerId': ownerId,
    'polygon': polygon.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList(),
    'areaSqMeters': areaSqMeters,
    'capturedAt': capturedAt.toIso8601String(),
    'color': color.toARGB32(),
    'isPendingReview': isPendingReview,
  };

  factory Territory.fromJson(Map<String, dynamic> json) {
    final rawPolygon = json['polygon'] as List<dynamic>? ?? [];
    final List<LatLng> points = rawPolygon.map((p) {
      final map = p as Map<String, dynamic>;
      return LatLng((map['lat'] as num).toDouble(), (map['lng'] as num).toDouble());
    }).toList();

    return Territory(
      id: json['id'] as String,
      ownerId: json['ownerId'] as String? ?? 'anonymous_runner',
      polygon: points,
      areaSqMeters: (json['areaSqMeters'] as num?)?.toDouble() ?? 15047.0,
      capturedAt: json['capturedAt'] != null
          ? DateTime.parse(json['capturedAt'] as String)
          : DateTime.now(),
      color: json['color'] != null ? Color(json['color'] as int) : const Color(0xFF00F0FF),
      isPendingReview: json['isPendingReview'] as bool? ?? false,
    );
  }
}

/// Hive TypeAdapter for [Territory]
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

    return Territory(
      id: fields[0] as String,
      ownerId: fields[1] as String,
      polygon: polyPoints,
      areaSqMeters: (fields[3] as num).toDouble(),
      capturedAt: DateTime.fromMillisecondsSinceEpoch(fields[4] as int),
      color: Color(fields[5] as int),
      isPendingReview: (fields[6] as bool?) ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, Territory obj) {
    writer
      ..writeByte(7)
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
      ..write(obj.isPendingReview);
  }
}
