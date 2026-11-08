/// Season model representing monthly competitive territorial periods.
class Season {
  final String id;
  final String name;
  final DateTime startsAt;
  final DateTime endsAt;
  final DateTime createdAt;

  const Season({
    required this.id,
    required this.name,
    required this.startsAt,
    required this.endsAt,
    required this.createdAt,
  });

  factory Season.fromJson(Map<String, dynamic> json) => Season(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    startsAt:
        DateTime.tryParse(json['starts_at'] as String? ?? '')?.toUtc() ??
        DateTime.now().toUtc(),
    endsAt:
        DateTime.tryParse(json['ends_at'] as String? ?? '')?.toUtc() ??
        DateTime.now().toUtc(),
    createdAt:
        DateTime.tryParse(json['created_at'] as String? ?? '')?.toUtc() ??
        DateTime.now().toUtc(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'starts_at': startsAt.toIso8601String(),
    'ends_at': endsAt.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
  };
}

/// Runner standing in the active season.
class SeasonUserStanding {
  final String seasonId;
  final String userId;
  final String username;
  final String faction;
  final int seasonRank;
  final double totalAreaSqm;
  final double totalDistanceM;
  final int xp;
  final DateTime updatedAt;

  const SeasonUserStanding({
    required this.seasonId,
    required this.userId,
    this.username = '',
    required this.faction,
    required this.seasonRank,
    required this.totalAreaSqm,
    required this.totalDistanceM,
    required this.xp,
    required this.updatedAt,
  });

  factory SeasonUserStanding.fromJson(Map<String, dynamic> json) =>
      SeasonUserStanding(
        seasonId: json['season_id'] as String? ?? '',
        userId: json['user_id'] as String? ?? '',
        username: json['username'] as String? ?? '',
        faction: json['faction'] as String? ?? '',
        seasonRank: (json['season_rank'] as num?)?.toInt() ?? 0,
        totalAreaSqm: (json['total_area_sqm'] as num?)?.toDouble() ?? 0.0,
        totalDistanceM: (json['total_distance_m'] as num?)?.toDouble() ?? 0.0,
        xp: (json['xp'] as num?)?.toInt() ?? 0,
        updatedAt:
            DateTime.tryParse(json['updated_at'] as String? ?? '')?.toUtc() ??
            DateTime.now().toUtc(),
      );

  Map<String, dynamic> toJson() => {
    'season_id': seasonId,
    'user_id': userId,
    'username': username,
    'faction': faction,
    'season_rank': seasonRank,
    'total_area_sqm': totalAreaSqm,
    'total_distance_m': totalDistanceM,
    'xp': xp,
    'updated_at': updatedAt.toIso8601String(),
  };
}

/// Faction aggregate standing in the active season.
class SeasonFactionStanding {
  final String faction;
  final double totalAreaSqm;
  final double totalDistanceM;
  final int runnerCount;

  const SeasonFactionStanding({
    required this.faction,
    required this.totalAreaSqm,
    required this.totalDistanceM,
    required this.runnerCount,
  });

  factory SeasonFactionStanding.fromJson(Map<String, dynamic> json) =>
      SeasonFactionStanding(
        faction: json['faction'] as String? ?? '',
        totalAreaSqm: (json['total_area_sqm'] as num?)?.toDouble() ?? 0.0,
        totalDistanceM: (json['total_distance_m'] as num?)?.toDouble() ?? 0.0,
        runnerCount: (json['runner_count'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
    'faction': faction,
    'total_area_sqm': totalAreaSqm,
    'total_distance_m': totalDistanceM,
    'runner_count': runnerCount,
  };
}

/// Encapsulates current season status, countdown, user standing, and faction standings.
class CurrentSeasonData {
  final Season season;
  final int timeRemainingSeconds;
  final SeasonUserStanding? userStanding;
  final List<SeasonFactionStanding> factionStandings;

  const CurrentSeasonData({
    required this.season,
    required this.timeRemainingSeconds,
    this.userStanding,
    required this.factionStandings,
  });

  factory CurrentSeasonData.fromJson(Map<String, dynamic> json) =>
      CurrentSeasonData(
        season: Season.fromJson(json['season'] as Map<String, dynamic>? ?? {}),
        timeRemainingSeconds:
            (json['time_remaining_seconds'] as num?)?.toInt() ?? 0,
        userStanding: json['user_standing'] != null
            ? SeasonUserStanding.fromJson(
                json['user_standing'] as Map<String, dynamic>,
              )
            : null,
        factionStandings:
            (json['faction_standings'] as List<dynamic>?)
                ?.map(
                  (e) =>
                      SeasonFactionStanding.fromJson(e as Map<String, dynamic>),
                )
                .toList() ??
            const [],
      );

  Map<String, dynamic> toJson() => {
    'season': season.toJson(),
    'time_remaining_seconds': timeRemainingSeconds,
    if (userStanding != null) 'user_standing': userStanding!.toJson(),
    'faction_standings': factionStandings.map((e) => e.toJson()).toList(),
  };
}
