/// Model representing territory dominance by athletic faction
class FactionStanding {
  final String faction;
  final double totalAreaSqm;
  final int memberCount;
  final double percentage;

  const FactionStanding({
    required this.faction,
    required this.totalAreaSqm,
    required this.memberCount,
    required this.percentage,
  });

  factory FactionStanding.fromJson(Map<String, dynamic> json) {
    return FactionStanding(
      faction: json['faction'] as String? ?? 'Cyber Vanguard',
      totalAreaSqm: (json['total_area_sqm'] as num?)?.toDouble() ?? 0.0,
      memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 33.3,
    );
  }

  Map<String, dynamic> toJson() => {
        'faction': faction,
        'total_area_sqm': totalAreaSqm,
        'member_count': memberCount,
        'percentage': percentage,
      };
}

/// Global turf war statistics response from GET /v1/factions/standings
class FactionStandingsResponse {
  final double totalAreaSqm;
  final List<FactionStanding> standings;

  const FactionStandingsResponse({
    required this.totalAreaSqm,
    required this.standings,
  });

  factory FactionStandingsResponse.fromJson(Map<String, dynamic> json) {
    final list = (json['standings'] as List<dynamic>?)
            ?.map((e) => FactionStanding.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return FactionStandingsResponse(
      totalAreaSqm: (json['total_area_sqm'] as num?)?.toDouble() ?? 0.0,
      standings: list,
    );
  }

  Map<String, dynamic> toJson() => {
        'total_area_sqm': totalAreaSqm,
        'standings': standings.map((s) => s.toJson()).toList(),
      };
}
