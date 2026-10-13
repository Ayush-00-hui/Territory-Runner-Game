/// Strongly-typed leaderboard ranking entry returned by GET /v1/leaderboard.
class LeaderboardEntry {
  final int rank;
  final String userId;
  final String username;
  final String faction;
  final double totalAreaSqm;
  final int level;
  final int totalRuns;

  const LeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.username,
    required this.faction,
    required this.totalAreaSqm,
    required this.level,
    required this.totalRuns,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      userId: json['user_id'] as String? ?? '',
      username: json['username'] as String? ?? 'Anonymous',
      faction: json['faction'] as String? ?? 'Cyber Vanguard',
      totalAreaSqm: (json['total_area_sqm'] as num?)?.toDouble() ?? 0.0,
      level: (json['level'] as num?)?.toInt() ?? 1,
      totalRuns: (json['total_runs'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'rank': rank,
    'user_id': userId,
    'username': username,
    'faction': faction,
    'total_area_sqm': totalAreaSqm,
    'level': level,
    'total_runs': totalRuns,
  };
}
