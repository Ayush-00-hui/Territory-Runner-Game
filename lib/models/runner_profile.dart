import 'package:hive/hive.dart';

class RunnerProfile {
  String id;
  String username;
  String faction;
  double totalDistanceKm;
  int xp;
  int level;
  List<String> badges;
  int totalHexesClaimed;
  int currentStreak;

  RunnerProfile({
    required this.id,
    required this.username,
    this.faction = 'Cyber Vanguard',
    this.totalDistanceKm = 0.0,
    this.xp = 0,
    this.level = 1,
    this.badges = const ['Cyber Rookie'],
    this.totalHexesClaimed = 0,
    this.currentStreak = 1,
  });

  /// Adds XP and computes dynamic leveling logic
  bool addXp(int amount) {
    xp += amount;
    int neededForNext = level * 250;
    bool leveledUp = false;
    while (xp >= neededForNext) {
      xp -= neededForNext;
      level++;
      leveledUp = true;
      neededForNext = level * 250;
      _evaluateBadges();
    }
    return leveledUp;
  }

  /// Adds run distance in km
  void addDistance(double km) {
    totalDistanceKm += km;
    _evaluateBadges();
  }

  /// Increments claimed hexes/territories and awards XP with optional flight multiplier
  bool claimHex({double multiplier = 1.0}) {
    totalHexesClaimed++;
    _evaluateBadges();
    final int awardedXp = (10 * multiplier).round();
    return addXp(awardedXp);
  }

  /// Claims an arbitrary enclosed polygon territory and awards dynamic XP scaled to area: max(100, round(Area / 20)) * multiplier
  int claimPolygonArea(double areaSqMeters, {double multiplier = 1.0}) {
    totalHexesClaimed++;
    _evaluateBadges();
    final int baseAward = (areaSqMeters / 20.0).round();
    final int effectiveBase = baseAward < 100 ? 100 : baseAward;
    final int awardedXp = (effectiveBase * multiplier).round();
    addXp(awardedXp);
    return awardedXp;
  }

  void _evaluateBadges() {
    final List<String> current = List.from(badges);
    if (totalHexesClaimed >= 1 && !current.contains('First Conquest')) {
      current.add('First Conquest');
    }
    if (totalHexesClaimed >= 25 && !current.contains('Sector Commander')) {
      current.add('Sector Commander');
    }
    if (totalHexesClaimed >= 100 && !current.contains('Hex Grid Overlord')) {
      current.add('Hex Grid Overlord');
    }
    if (totalDistanceKm >= 10.0 && !current.contains('10K Centurion')) {
      current.add('10K Centurion');
    }
    if (level >= 5 && !current.contains('Veteran Strider')) {
      current.add('Veteran Strider');
    }
    badges = current;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'faction': faction,
    'totalDistanceKm': totalDistanceKm,
    'xp': xp,
    'level': level,
    'badges': badges,
    'totalHexesClaimed': totalHexesClaimed,
    'currentStreak': currentStreak,
  };

  factory RunnerProfile.fromJson(Map<String, dynamic> json) {
    return RunnerProfile(
      id: json['id'] as String? ?? 'local_user',
      username: json['username'] as String? ?? 'CyberRunner',
      faction: json['faction'] as String? ?? 'Cyber Vanguard',
      totalDistanceKm: (json['totalDistanceKm'] as num?)?.toDouble() ?? 0.0,
      xp: json['xp'] as int? ?? 0,
      level: json['level'] as int? ?? 1,
      badges: (json['badges'] as List?)?.map((e) => e.toString()).toList() ?? const ['Cyber Rookie'],
      totalHexesClaimed: json['totalHexesClaimed'] as int? ?? 0,
      currentStreak: json['currentStreak'] as int? ?? 1,
    );
  }
}

/// Hive TypeAdapter for [RunnerProfile]
class RunnerProfileAdapter extends TypeAdapter<RunnerProfile> {
  @override
  final int typeId = 1;

  @override
  RunnerProfile read(BinaryReader reader) {
    final int numOfFields = reader.readByte();
    final Map<int, dynamic> fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    return RunnerProfile(
      id: fields[0] as String,
      username: fields[1] as String,
      faction: (fields[8] as String?) ?? 'Cyber Vanguard',
      totalDistanceKm: (fields[2] as num).toDouble(),
      xp: fields[3] as int,
      level: fields[4] as int,
      badges: (fields[5] as List).cast<String>(),
      totalHexesClaimed: (fields[6] as int?) ?? 0,
      currentStreak: (fields[7] as int?) ?? 1,
    );
  }

  @override
  void write(BinaryWriter writer, RunnerProfile obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.username)
      ..writeByte(2)
      ..write(obj.totalDistanceKm)
      ..writeByte(3)
      ..write(obj.xp)
      ..writeByte(4)
      ..write(obj.level)
      ..writeByte(5)
      ..write(obj.badges)
      ..writeByte(6)
      ..write(obj.totalHexesClaimed)
      ..writeByte(7)
      ..write(obj.currentStreak)
      ..writeByte(8)
      ..write(obj.faction);
  }
}
