import 'package:flutter/foundation.dart';

@immutable
class LeagueParticipant {
  final int rank;
  final String userId;
  final String username;
  final String faction;
  final String tier;
  final double weeklyAreaSqm;
  final int weeklyRuns;
  final bool isCurrentUser;

  const LeagueParticipant({
    required this.rank,
    required this.userId,
    required this.username,
    required this.faction,
    required this.tier,
    required this.weeklyAreaSqm,
    required this.weeklyRuns,
    required this.isCurrentUser,
  });

  factory LeagueParticipant.fromJson(Map<String, dynamic> json) {
    return LeagueParticipant(
      rank: (json['rank'] as num?)?.toInt() ?? 1,
      userId: json['user_id'] as String? ?? '',
      username: json['username'] as String? ?? 'Runner',
      faction: json['faction'] as String? ?? 'Cyber Vanguard',
      tier: json['tier'] as String? ?? 'Bronze',
      weeklyAreaSqm: (json['weekly_area_sqm'] as num?)?.toDouble() ?? 0.0,
      weeklyRuns: (json['weekly_runs'] as num?)?.toInt() ?? 0,
      isCurrentUser: json['is_current_user'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'rank': rank,
    'user_id': userId,
    'username': username,
    'faction': faction,
    'tier': tier,
    'weekly_area_sqm': weeklyAreaSqm,
    'weekly_runs': weeklyRuns,
    'is_current_user': isCurrentUser,
  };
}

@immutable
class LeagueStanding {
  final String userId;
  final String username;
  final String faction;
  final String tier;
  final int rank;
  final int totalParticipants;
  final double weeklyAreaSqm;
  final int weeklyRuns;
  final int promotionRankCutoff;
  final int relegationRankCutoff;
  final DateTime resetAt;
  final int secondsUntilReset;
  final List<LeagueParticipant> standings;

  const LeagueStanding({
    required this.userId,
    required this.username,
    required this.faction,
    required this.tier,
    required this.rank,
    required this.totalParticipants,
    required this.weeklyAreaSqm,
    required this.weeklyRuns,
    required this.promotionRankCutoff,
    required this.relegationRankCutoff,
    required this.resetAt,
    required this.secondsUntilReset,
    required this.standings,
  });

  factory LeagueStanding.fromJson(Map<String, dynamic> json) {
    final rawStandings = json['standings'] as List<dynamic>? ?? [];
    return LeagueStanding(
      userId: json['user_id'] as String? ?? '',
      username: json['username'] as String? ?? 'Runner',
      faction: json['faction'] as String? ?? 'Cyber Vanguard',
      tier: json['tier'] as String? ?? 'Bronze',
      rank: (json['rank'] as num?)?.toInt() ?? 1,
      totalParticipants: (json['total_participants'] as num?)?.toInt() ?? 0,
      weeklyAreaSqm: (json['weekly_area_sqm'] as num?)?.toDouble() ?? 0.0,
      weeklyRuns: (json['weekly_runs'] as num?)?.toInt() ?? 0,
      promotionRankCutoff:
          (json['promotion_rank_cutoff'] as num?)?.toInt() ?? 0,
      relegationRankCutoff:
          (json['relegation_rank_cutoff'] as num?)?.toInt() ?? 0,
      resetAt: json['reset_at'] != null
          ? DateTime.tryParse(json['reset_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      secondsUntilReset: (json['seconds_until_reset'] as num?)?.toInt() ?? 0,
      standings: rawStandings
          .map((e) => LeagueParticipant.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'username': username,
    'faction': faction,
    'tier': tier,
    'rank': rank,
    'total_participants': totalParticipants,
    'weekly_area_sqm': weeklyAreaSqm,
    'weekly_runs': weeklyRuns,
    'promotion_rank_cutoff': promotionRankCutoff,
    'relegation_rank_cutoff': relegationRankCutoff,
    'reset_at': resetAt.toIso8601String(),
    'seconds_until_reset': secondsUntilReset,
    'standings': standings.map((e) => e.toJson()).toList(),
  };
}
