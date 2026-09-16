import 'package:hive_flutter/hive_flutter.dart';

class TerritoryService {
  static final TerritoryService _instance = TerritoryService._internal();
  factory TerritoryService() => _instance;

  late final Box<String> _box;

  TerritoryService._internal() {
    _box = Hive.box<String>('territories');
  }

  /// Returns all currently captured hex IDs
  List<String> getCapturedTerritories() {
    return _box.values.toList();
  }

  /// Capture a new territory hex
  /// Returns true if it was newly captured, false if it was already owned
  Future<bool> captureTerritory(String hexId) async {
    if (_box.values.contains(hexId)) {
      return false; // Already captured
    }
    await _box.add(hexId);
    return true;
  }

  /// Wipe all territories (e.g. for testing)
  Future<void> resetTerritories() async {
    await _box.clear();
  }

  /// Listen to changes in territories to update UI in real-time
  Stream<BoxEvent> get territoryStream => _box.watch();
}
