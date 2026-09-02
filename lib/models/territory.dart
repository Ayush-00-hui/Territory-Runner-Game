import 'package:latlong2/latlong.dart';
import 'package:flutter/material.dart';

class Territory {
  String id;
  String ownerId;
  List<LatLng> polygon;
  double areaSqMeters;
  Color color;

  Territory({
    required this.id,
    required this.ownerId,
    required this.polygon,
    required this.areaSqMeters,
    required this.color,
  });
}
