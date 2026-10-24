import 'package:hive/hive.dart';

import 'faction_standing.dart';

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

  static const Map<String, String> badgeAliases = {
    'Territory Sovereign': 'Territory Master',
    'First Conquest': 'First Claim',
    'Sector Commander': 'Area Leader',
    'Hex Grid Overlord': 'Grid Leader',
    'Cyber Rookie': 'Rookie Runner',
  };

  static const Map<String, String> factionAliases = {
    'Cyber Vanguard': 'Vanguard',
    'Iron Syndicate': 'Syndicate',
    'Neon Nomads': 'Nomads',
  };

  static String canonicalBadge(String name) => badgeAliases[name] ?? name;

  String get displayFaction => FactionStanding.canonicalFaction(faction);

  bool hasBadge(String name) {
    final canon = canonicalBadge(name);
    for (final b in badges) {
      if (canonicalBadge(b) == canon || b == name) {
        return true;
      }
    }
    return false;
  }

  RunnerProfile({
    required this.id,
    required this.username,
    this.faction = FactionStanding.defaultFaction,
    this.totalDistanceKm = 0.0,
    this.xp = 0,
    this.level = 1,
    this.badges = const ['Rookie Runner', 'Cyber Rookie'],
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
    if (totalHexesClaimed >= 1) {
      if (!current.contains('First Claim')) {
        current.add('First Claim');
      }
      if (!current.contains('First Conquest')) {
        current.add('First Conquest');
      }
      if (!current.contains('Territory Master')) {
        current.add('Territory Master');
      }
      if (!current.contains('Territory Sovereign')) {
        current.add('Territory Sovereign');
      }
    }
    if (totalHexesClaimed >= 25) {
      if (!current.contains('Area Leader')) {
        current.add('Area Leader');
      }
      if (!current.contains('Sector Commander')) {
        current.add('Sector Commander');
      }
    }
    if (totalHexesClaimed >= 100) {
      if (!current.contains('Grid Leader')) {
        current.add('Grid Leader');
      }
      if (!current.contains('Hex Grid Overlord')) {
        current.add('Hex Grid Overlord');
      }
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
    final rawBadges =
        (json['badges'] as List?)?.map((e) => e.toString()).toList() ??
        const ['Rookie Runner', 'Cyber Rookie'];
    final migratedBadges = <String>[...rawBadges];
    for (final b in rawBadges) {
      final canon = badgeAliases[b];
      if (canon != null && !migratedBadges.contains(canon)) {
        migratedBadges.add(canon);
      }
    }
    return RunnerProfile(
      id: json['id'] as String? ?? 'local_user',
      username: json['username'] as String? ?? 'Runner',
      faction: FactionStanding.canonicalFaction(json['faction'] as String?),
      totalDistanceKm: (json['totalDistanceKm'] as num?)?.toDouble() ?? 0.0,
      xp: json['xp'] as int? ?? 0,
      level: json['level'] as int? ?? 1,
      badges: migratedBadges,
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

    final rawBadges = (fields[5] as List).cast<String>();
    final migratedBadges = <String>[...rawBadges];
    for (final b in rawBadges) {
      final canon = RunnerProfile.badgeAliases[b];
      if (canon != null && !migratedBadges.contains(canon)) {
        migratedBadges.add(canon);
      }
    }

    return RunnerProfile(
      id: fields[0] as String,
      username: fields[1] as String,
      faction: FactionStanding.canonicalFaction(fields[8] as String?),
      totalDistanceKm: (fields[2] as num).toDouble(),
      xp: fields[3] as int,
      level: fields[4] as int,
      badges: migratedBadges,
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
