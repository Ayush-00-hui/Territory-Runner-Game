import 'package:flutter/material.dart';
import '../../../models/runner_profile.dart';
import '../../../models/territory.dart';
import '../../../ui/ui.dart';

enum LeaderboardScope { global, city, local }

class FactionLeaderboard extends StatefulWidget {
  final RunnerProfile profile;
  final List<Territory> territories;

  const FactionLeaderboard({
    super.key,
    required this.profile,
    required this.territories,
  });

  @override
  State<FactionLeaderboard> createState() => _FactionLeaderboardState();
}

class _FactionLeaderboardState extends State<FactionLeaderboard> {
  LeaderboardScope _scope = LeaderboardScope.global;

  double _getUserClaimedAreaKm2() {
    final double sqM = widget.territories.fold(0.0, (sum, t) => sum + t.areaSqMeters);
    return sqM / 1000000.0;
  }

  @override
  Widget build(BuildContext context) {
    final userAreaKm2 = _getUserClaimedAreaKm2();

    // Dynamic faction territorial calculations
    final double vanguardArea = 184.2 + userAreaKm2;
    const double syndicateArea = 142.5;
    const double nomadsArea = 98.4;
    final double totalArea = vanguardArea + syndicateArea + nomadsArea;

    final int vanguardPct = ((vanguardArea / totalArea) * 100).round();
    final int syndicatePct = ((syndicateArea / totalArea) * 100).round();
    final int nomadsPct = 100 - vanguardPct - syndicatePct;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- FACTION DOMINANCE METER ---
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.s16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppSpacing.br24,
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.shield_rounded, color: AppColors.accent, size: 18),
                      const SizedBox(width: AppSpacing.s8),
                      Text(
                        'TURF WAR DOMINANCE',
                        style: AppText.headingSmall.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      borderRadius: AppSpacing.br8,
                      border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      'CONTESTED',
                      style: AppText.label.copyWith(
                        color: AppColors.accent,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s14),

              // Multi-segment territory split bar
              ClipRRect(
                borderRadius: AppSpacing.br8,
                child: SizedBox(
                  height: 12,
                  child: Row(
                    children: [
                      Expanded(
                        flex: vanguardPct,
                        child: Container(color: AppColors.accent),
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        flex: syndicatePct,
                        child: Container(color: AppColors.rival),
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        flex: nomadsPct,
                        child: Container(color: const Color(0xFF00E5FF)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s14),

              // Faction Legend
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildFactionLegend('VANGUARD', '$vanguardPct%', AppColors.accent),
                  _buildFactionLegend('SYNDICATE', '$syndicatePct%', AppColors.rival),
                  _buildFactionLegend('NOMADS', '$nomadsPct%', const Color(0xFF00E5FF)),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.s20),

        // --- SCOPE SELECTOR ROW ---
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'CONQUEROR RANKINGS',
              style: AppText.label.copyWith(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            Row(
              children: [
                _buildScopeChip(LeaderboardScope.global, 'GLOBAL'),
                const SizedBox(width: AppSpacing.s6),
                _buildScopeChip(LeaderboardScope.city, 'CITY'),
                const SizedBox(width: AppSpacing.s6),
                _buildScopeChip(LeaderboardScope.local, 'LOCAL'),
              ],
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.s12),

        // --- LEADERBOARD ENTRIES ---
        _buildLeaderboardList(userAreaKm2),
      ],
    );
  }

  Widget _buildFactionLegend(String name, String percentage, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          name,
          style: AppText.label.copyWith(color: Colors.white70, fontSize: 9.5),
        ),
        const SizedBox(width: 4),
        Text(
          percentage,
          style: AppText.statSmall.copyWith(fontSize: 11, color: color, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }

  Widget _buildScopeChip(LeaderboardScope scope, String label) {
    final isSelected = _scope == scope;
    return GestureDetector(
      onTap: () {
        AppMotion.lightTick();
        setState(() => _scope = scope);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent.withValues(alpha: 0.18) : AppColors.surface,
          borderRadius: AppSpacing.brFull,
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.border,
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: AppText.label.copyWith(
            color: isSelected ? AppColors.accent : AppColors.textMuted,
            fontSize: 9.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _buildLeaderboardList(double userAreaKm2) {
    final currentUsername = widget.profile.username.isNotEmpty ? widget.profile.username.toUpperCase() : 'YOU';
    final userFormattedArea = userAreaKm2 >= 0.01
        ? '${userAreaKm2.toStringAsFixed(2)} km²'
        : '${(userAreaKm2 * 1000000).toStringAsFixed(0)} m²';

    final leaders = [
      _LeaderboardEntry(rank: 1, callsign: 'KAI_VALKYRIE', faction: 'Cyber Vanguard', area: '184.2 km²', dist: '84.5 km', isUser: false),
      _LeaderboardEntry(rank: 2, callsign: 'IRON_TITAN', faction: 'Iron Syndicate', area: '142.5 km²', dist: '68.1 km', isUser: false),
      _LeaderboardEntry(rank: 3, callsign: 'NEON_GHOST', faction: 'Neon Nomads', area: '118.0 km²', dist: '54.4 km', isUser: false),
      _LeaderboardEntry(rank: 4, callsign: currentUsername, faction: widget.profile.faction, area: userFormattedArea, dist: '${widget.profile.totalDistanceKm.toStringAsFixed(1)} km', isUser: true),
      _LeaderboardEntry(rank: 5, callsign: 'CIRCUIT_BLUR', faction: 'Cyber Vanguard', area: '94.6 km²', dist: '41.2 km', isUser: false),
    ];

    return Column(
      children: leaders.map((entry) => _buildLeaderCard(entry)).toList(),
    );
  }

  Widget _buildLeaderCard(_LeaderboardEntry entry) {
    Color rankColor;
    Widget rankIcon;

    if (entry.rank == 1) {
      rankColor = const Color(0xFFFFD700); // Gold
      rankIcon = const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFD700), size: 18);
    } else if (entry.rank == 2) {
      rankColor = const Color(0xFFC0C0C0); // Silver
      rankIcon = const Icon(Icons.emoji_events_rounded, color: Color(0xFFC0C0C0), size: 18);
    } else if (entry.rank == 3) {
      rankColor = const Color(0xFFCD7F32); // Bronze
      rankIcon = const Icon(Icons.emoji_events_rounded, color: Color(0xFFCD7F32), size: 18);
    } else {
      rankColor = Colors.white54;
      rankIcon = Text(
        '#${entry.rank}',
        style: AppText.statSmall.copyWith(fontSize: 13, color: rankColor),
      );
    }

    final isUser = entry.isUser;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s10),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s14, vertical: AppSpacing.s12),
      decoration: BoxDecoration(
        color: isUser ? AppColors.accent.withValues(alpha: 0.12) : AppColors.surface,
        borderRadius: AppSpacing.br16,
        border: Border.all(
          color: isUser ? AppColors.accent : AppColors.border,
          width: isUser ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          // Rank Badge
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: rankColor.withValues(alpha: 0.12),
              border: Border.all(color: rankColor.withValues(alpha: 0.3), width: 1),
            ),
            child: Center(child: rankIcon),
          ),
          const SizedBox(width: AppSpacing.s10),

          // Athlete Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.callsign,
                        style: AppText.bodyBold.copyWith(
                          fontSize: 13,
                          color: isUser ? AppColors.accent : Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isUser) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: AppSpacing.br8,
                        ),
                        child: const Text(
                          'YOU',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${entry.faction} • ${entry.dist}',
                  style: AppText.bodySmall.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),

          // Area Controlled
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                entry.area,
                style: AppText.statSmall.copyWith(
                  fontSize: 13,
                  color: isUser ? AppColors.accent : Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'CONTROLLED',
                style: AppText.label.copyWith(color: AppColors.textMuted, fontSize: 8),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LeaderboardEntry {
  final int rank;
  final String callsign;
  final String faction;
  final String area;
  final String dist;
  final bool isUser;

  const _LeaderboardEntry({
    required this.rank,
    required this.callsign,
    required this.faction,
    required this.area,
    required this.dist,
    required this.isUser,
  });
}
