import 'package:flutter/material.dart';

import '../../../models/faction_standing.dart';
import '../../../models/leaderboard_entry.dart';
import '../../../models/runner_profile.dart';
import '../../../models/territory.dart';
import '../../../services/api_client.dart';
import '../../../ui/ui.dart';

enum LeaderboardScope { global, city, local }

class FactionLeaderboard extends StatefulWidget {
  final RunnerProfile profile;
  final List<Territory> territories;
  final ApiClient? apiClient;
  final FactionStandingsResponse? initialStandings;
  final List<LeaderboardEntry>? initialLeaderboard;

  const FactionLeaderboard({
    super.key,
    required this.profile,
    required this.territories,
    this.apiClient,
    this.initialStandings,
    this.initialLeaderboard,
  });

  @override
  State<FactionLeaderboard> createState() => _FactionLeaderboardState();
}

class _FactionLeaderboardState extends State<FactionLeaderboard> {
  LeaderboardScope _scope = LeaderboardScope.global;
  late final ApiClient _apiClient;

  FactionStandingsResponse? _standings;
  List<LeaderboardEntry> _leaderboard = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _apiClient = widget.apiClient ?? ApiClient();

    if (widget.initialStandings != null || widget.initialLeaderboard != null) {
      _standings = widget.initialStandings;
      _leaderboard = widget.initialLeaderboard ?? [];
      _isLoading = false;
    } else {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _apiClient.getFactionStandings(),
        _apiClient.getLeaderboard(limit: 50),
      ]);

      if (!mounted) return;
      setState(() {
        _standings = results[0] as FactionStandingsResponse;
        _leaderboard = results[1] as List<LeaderboardEntry>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Using local territorial telemetry (offline).';
      });
    }
  }

  double _getUserClaimedAreaKm2() {
    final double sqM = widget.territories.fold(
      0.0,
      (sum, t) => sum + t.areaSqMeters,
    );
    return sqM / 1000000.0;
  }

  String _formatArea(double areaSqm) {
    if (areaSqm >= 1000000.0) {
      return '${(areaSqm / 1000000.0).toStringAsFixed(2)} km²';
    } else if (areaSqm > 0.0) {
      return '${areaSqm.toStringAsFixed(0)} m²';
    }
    return '0 m²';
  }

  @override
  Widget build(BuildContext context) {
    final userAreaKm2 = _getUserClaimedAreaKm2();
    final userAreaSqm = userAreaKm2 * 1000000.0;

    // Resolve faction stats either from server standings or local fallback
    FactionStanding vanguard;
    FactionStanding syndicate;
    FactionStanding nomads;

    if (_standings != null && _standings!.standings.isNotEmpty) {
      vanguard = _standings!.standings.firstWhere(
        (s) => s.faction.toLowerCase().contains('vanguard'),
        orElse: () => const FactionStanding(
          faction: 'Cyber Vanguard',
          totalAreaSqm: 0,
          memberCount: 0,
          percentage: 0,
        ),
      );
      syndicate = _standings!.standings.firstWhere(
        (s) => s.faction.toLowerCase().contains('syndicate'),
        orElse: () => const FactionStanding(
          faction: 'Iron Syndicate',
          totalAreaSqm: 0,
          memberCount: 0,
          percentage: 0,
        ),
      );
      nomads = _standings!.standings.firstWhere(
        (s) => s.faction.toLowerCase().contains('nomad'),
        orElse: () => const FactionStanding(
          faction: 'Neon Nomads',
          totalAreaSqm: 0,
          memberCount: 0,
          percentage: 0,
        ),
      );
    } else {
      // Local fallback based on verified territories
      final userFaction = widget.profile.faction.toLowerCase();
      vanguard = FactionStanding(
        faction: 'Cyber Vanguard',
        totalAreaSqm: userFaction.contains('vanguard') ? userAreaSqm : 0,
        memberCount: userFaction.contains('vanguard') ? 1 : 0,
        percentage: 0,
      );
      syndicate = FactionStanding(
        faction: 'Iron Syndicate',
        totalAreaSqm: userFaction.contains('syndicate') ? userAreaSqm : 0,
        memberCount: userFaction.contains('syndicate') ? 1 : 0,
        percentage: 0,
      );
      nomads = FactionStanding(
        faction: 'Neon Nomads',
        totalAreaSqm: userFaction.contains('nomad') ? userAreaSqm : 0,
        memberCount: userFaction.contains('nomad') ? 1 : 0,
        percentage: 0,
      );
    }

    final double totalAreaSqm =
        vanguard.totalAreaSqm + syndicate.totalAreaSqm + nomads.totalAreaSqm;

    int vanguardPct = 33;
    int syndicatePct = 33;
    int nomadsPct = 34;

    if (totalAreaSqm > 0) {
      vanguardPct = ((vanguard.totalAreaSqm / totalAreaSqm) * 100).round();
      syndicatePct = ((syndicate.totalAreaSqm / totalAreaSqm) * 100).round();
      nomadsPct = (100 - vanguardPct - syndicatePct).clamp(0, 100);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- FACTION DOMINANCE METER ---
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.s16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppSpacing.br20,
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.shield_rounded,
                          color: AppColors.accent,
                          size: 18,
                        ),
                        const SizedBox(width: AppSpacing.s8),
                        Flexible(
                          child: Text(
                            'Team Standings',
                            style: AppText.headingSmall.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accentContainer,
                      borderRadius: AppSpacing.br8,
                      border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      totalAreaSqm > 0 ? 'Contested' : 'Unclaimed',
                      style: AppText.labelSmall.copyWith(
                        color: AppColors.accent,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
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
                  height: 10,
                  child: Row(
                    children: [
                      Expanded(
                        flex: vanguardPct > 0 ? vanguardPct : 1,
                        child: Container(color: AppColors.accent),
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        flex: syndicatePct > 0 ? syndicatePct : 1,
                        child: Container(color: AppColors.warning),
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        flex: nomadsPct > 0 ? nomadsPct : 1,
                        child: Container(color: AppColors.info),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s14),

              // Faction Legend
              Row(
                children: [
                  Expanded(
                    child: _buildFactionLegend(
                      'Vanguard',
                      '$vanguardPct%',
                      _formatArea(vanguard.totalAreaSqm),
                      AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _buildFactionLegend(
                      'Syndicate',
                      '$syndicatePct%',
                      _formatArea(syndicate.totalAreaSqm),
                      AppColors.warning,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _buildFactionLegend(
                      'Nomads',
                      '$nomadsPct%',
                      _formatArea(nomads.totalAreaSqm),
                      AppColors.info,
                    ),
                  ),
                ],
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: AppSpacing.s8),
                Text(
                  _errorMessage!,
                  style: AppText.bodySmall.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.s20),

        // --- SCOPE SELECTOR ROW ---
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.s8,
          runSpacing: AppSpacing.s8,
          children: [
            Text(
              'Leaderboard',
              style: AppText.headingSmall.copyWith(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildScopeChip(LeaderboardScope.global, 'Global'),
                const SizedBox(width: AppSpacing.s6),
                _buildScopeChip(LeaderboardScope.city, 'City'),
                const SizedBox(width: AppSpacing.s6),
                _buildScopeChip(LeaderboardScope.local, 'Local'),
              ],
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.s12),

        // --- LEADERBOARD ENTRIES ---
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.s24),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accent,
                ),
              ),
            ),
          )
        else
          _buildLeaderboardContent(userAreaSqm),
      ],
    );
  }

  Widget _buildFactionLegend(
    String name,
    String percentage,
    String area,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                name,
                style: AppText.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                percentage,
                style: AppText.labelSmall.copyWith(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 14, top: 2),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              area,
              style: AppText.bodySmall.copyWith(
                color: AppColors.textMuted,
                fontSize: 10,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScopeChip(LeaderboardScope scope, String label) {
    final isSelected = _scope == scope;
    return Semantics(
      button: true,
      selected: isSelected,
      label: 'Scope: $label',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () {
          AppMotion.selectionTick();
          setState(() => _scope = scope);
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: AppMotion.duration(context, AppMotion.fast),
          curve: AppMotion.easeOut,
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accentContainer : AppColors.surface,
            borderRadius: AppSpacing.brFull,
            border: Border.all(
              color: isSelected ? AppColors.accent : AppColors.border,
              width: 1.0,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: AppText.labelSmall.copyWith(
                color: isSelected ? AppColors.accent : AppColors.textMuted,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeaderboardContent(double userAreaSqm) {
    final currentUsername = widget.profile.username.isNotEmpty
        ? widget.profile.username.toUpperCase()
        : 'YOU';

    // If server has entries, check if user is in top entries
    final entries = List<LeaderboardEntry>.from(_leaderboard);
    final userIdx = entries.indexWhere(
      (e) =>
          e.userId == widget.profile.id ||
          e.username.toUpperCase() == currentUsername,
    );

    // If user has local territories and is not in list, add user
    if (userIdx == -1 && (userAreaSqm > 0 || entries.isEmpty)) {
      entries.add(
        LeaderboardEntry(
          rank: entries.length + 1,
          userId: widget.profile.id,
          username: currentUsername,
          faction: widget.profile.faction,
          totalAreaSqm: userAreaSqm,
          level: widget.profile.level,
          totalRuns: widget.profile.totalHexesClaimed,
        ),
      );
    }

    if (entries.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.s24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppSpacing.br16,
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.emoji_events_outlined,
              color: AppColors.textMuted,
              size: 36,
            ),
            const SizedBox(height: AppSpacing.s10),
            Text(
              'No leaderboard entries yet',
              style: AppText.headingSmall.copyWith(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              'Claim your first territory to rank on the leaderboard.',
              textAlign: TextAlign.center,
              style: AppText.bodySmall.copyWith(
                color: AppColors.textMuted,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: entries.map((entry) {
        final isUser =
            entry.userId == widget.profile.id ||
            entry.username.toUpperCase() == currentUsername;
        return _buildLeaderCard(entry, isUser);
      }).toList(),
    );
  }

  Widget _buildLeaderCard(LeaderboardEntry entry, bool isUser) {
    Color rankColor;
    Widget rankIcon;

    if (entry.rank == 1) {
      rankColor = AppColors.gold;
      rankIcon = const Icon(
        Icons.emoji_events_rounded,
        color: AppColors.gold,
        size: 18,
      );
    } else if (entry.rank == 2) {
      rankColor = AppColors.silver;
      rankIcon = const Icon(
        Icons.emoji_events_rounded,
        color: AppColors.silver,
        size: 18,
      );
    } else if (entry.rank == 3) {
      rankColor = AppColors.bronze;
      rankIcon = const Icon(
        Icons.emoji_events_rounded,
        color: AppColors.bronze,
        size: 18,
      );
    } else {
      rankColor = AppColors.textMuted;
      rankIcon = Text(
        '#${entry.rank}',
        style: AppText.statSmall.copyWith(
          fontSize: 12,
          color: rankColor,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s10),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s14,
        vertical: AppSpacing.s12,
      ),
      decoration: BoxDecoration(
        color: isUser ? AppColors.accentContainer : AppColors.surface,
        borderRadius: AppSpacing.br16,
        border: Border.all(
          color: isUser ? AppColors.accent : AppColors.border,
          width: 1.0,
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
              border: Border.all(
                color: rankColor.withValues(alpha: 0.3),
                width: 1,
              ),
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
                        entry.username,
                        style: AppText.bodyMedium.copyWith(
                          fontSize: 13,
                          color: isUser
                              ? AppColors.accent
                              : AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isUser) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: AppSpacing.br8,
                        ),
                        child: const Text(
                          'You',
                          style: TextStyle(
                            color: AppColors.onAccent,
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
                  '${entry.faction} • Lvl ${entry.level}',
                  style: AppText.bodySmall.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 11,
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
                _formatArea(entry.totalAreaSqm),
                style: AppText.statSmall.copyWith(
                  fontSize: 13,
                  color: isUser ? AppColors.accent : AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Controlled',
                style: AppText.labelSmall.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
