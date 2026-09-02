import 'package:latlong2/latlong.dart';

class RunnerProfile {
  String id;
  String username;
  double totalDistanceKm;
  int xp;
  int level;
  List<String> badges;

  RunnerProfile({
    required this.id,
    required this.username,
    this.totalDistanceKm = 0.0,
    this.xp = 0,
    this.level = 1,
    this.badges = const [],
  });

  void addXp(int amount) {
    xp += amount;
    // Simple level up logic
    if (xp > level * 1000) {
      level++;
    }
  }
}
