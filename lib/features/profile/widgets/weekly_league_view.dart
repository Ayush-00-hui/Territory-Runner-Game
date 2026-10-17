import 'dart:async';
import 'package:flutter/material.dart';
import '../../../models/league_standing.dart';
import '../../../services/api_client.dart';
import '../../../ui/ui.dart';

class WeeklyLeagueView extends StatefulWidget {
  final ApiClient? apiClient;
  final LeagueStanding? initialStanding;

  const WeeklyLeagueView({
    super.key,
    this.apiClient,
    this.initialStanding,
  });

  @override
  State<WeeklyLeagueView> createState() => _WeeklyLeagueViewState();
}

class _WeeklyLeagueViewState extends State<WeeklyLeagueView> {
  late final ApiClient _apiClient;
  LeagueStanding? _standing;
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _countdownTimer;
  int _remainingSeconds = 0;

  @override
  void initState() {
    super.initState();
    _apiClient = widget.apiClient ?? ApiClient();
    if (widget.initialStanding != null) {
      _standing = widget.initialStanding;
      _remainingSeconds = widget.initialStanding!.secondsUntilReset;
      _startCountdown();
    } else {
      _fetchLeagueStandings();
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _fetchLeagueStandings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final standing = await _apiClient.getCurrentLeague();
      if (!mounted) return;
      setState(() {
        _standing = standing;
        _remainingSeconds = standing.secondsUntilReset;
        _isLoading = false;
      });
      _startCountdown();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Offline: unable to fetch league standings';
      });
    }
  }

  String _formatCountdown(int seconds) {
    if (seconds <= 0) return 'RESETTING...';
    final days = seconds ~/ 86400;
    final hours = (seconds % 86400) ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (days > 0) {
      return '${days}D ${hours}H ${minutes}M';
    }
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Color _getTierColor(String tier) {
    switch (tier.toLowerCase()) {
      case 'diamond':
        return const Color(0xFF5C85FF); // Slate Blue
      case 'gold':
        return AppColors.warning; // Amber
      case 'silver':
        return const Color(0xFFC0C0C0);
      case 'bronze':
      default:
        return const Color(0xFFCD7F32);
    }
  }

  IconData _getTierIcon(String tier) {
    switch (tier.toLowerCase()) {
      case 'diamond':
        return Icons.diamond_rounded;
      case 'gold':
        return Icons.military_tech_rounded;
      case 'silver':
        return Icons.shield_rounded;
      case 'bronze':
      default:
        return Icons.workspace_premium_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.s48),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2),
        ),
      );
    }

    if (_errorMessage != null && _standing == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.s20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppSpacing.br16,
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            const Icon(Icons.cloud_off_rounded, color: AppColors.textSecondary, size: 36),
            const SizedBox(height: AppSpacing.s8),
            Text(
              _errorMessage!,
              style: AppText.body.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s16),
            PrimaryButton(
              label: 'RETRY',
              onPressed: _fetchLeagueStandings,
            ),
          ],
        ),
      );
    }

    final standing = _standing!;
    final tierColor = _getTierColor(standing.tier);
    final tierIcon = _getTierIcon(standing.tier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- LEAGUE HEADER CARD ---
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.s20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppSpacing.br24,
            border: Border.all(color: AppColors.border),
            boxShadow: AppSpacing.subtleElevation,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.s8),
                        decoration: BoxDecoration(
                          color: tierColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: tierColor.withValues(alpha: 0.4)),
                        ),
                        child: Icon(tierIcon, color: tierColor, size: 24),
                      ),
                      const SizedBox(width: AppSpacing.s12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${standing.tier.toUpperCase()} DIVISION',
                            style: AppText.label.copyWith(
                              color: tierColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Rank #${standing.rank} of ${standing.totalParticipants}',
                            style: AppText.caption.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Countdown timer badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.bgDeep,
                      borderRadius: AppSpacing.brFull,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.timer_outlined, color: AppColors.accent, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          _formatCountdown(_remainingSeconds),
                          style: AppText.caption.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.s16),
              const Divider(color: AppColors.border, height: 1),
              const SizedBox(height: AppSpacing.s16),

              // Metrics Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatTile(
                    label: 'WEEKLY AREA',
                    value: '${(standing.weeklyAreaSqm / 1000).toStringAsFixed(1)}k',
                    unit: 'm²',
                  ),
                  Container(width: 1, height: 32, color: AppColors.border),
                  _buildStatTile(
                    label: 'CONQUEST RUNS',
                    value: '${standing.weeklyRuns}',
                    unit: 'sessions',
                  ),
                  Container(width: 1, height: 32, color: AppColors.border),
                  _buildStatTile(
                    label: 'LEAGUE STATUS',
                    value: _getZoneLabel(standing),
                    unit: '',
                    valueColor: _getZoneColor(standing),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.s24),

        // --- SECTION HEADER ---
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'DIVISION STANDINGS',
              style: AppText.label.copyWith(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            Text(
              'RESETS MONDAY 00:00 UTC',
              style: AppText.caption.copyWith(
                color: AppColors.textMuted,
                fontSize: 10,
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.s12),

        // --- STANDINGS TABLE ---
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppSpacing.br16,
            border: Border.all(color: AppColors.border),
            boxShadow: AppSpacing.subtleElevation,
          ),
          child: ClipRRect(
            borderRadius: AppSpacing.br16,
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: standing.standings.length,
              separatorBuilder: (context, index) {
                final currentRank = standing.standings[index].rank;

                // Promotion zone threshold line
                if (standing.promotionRankCutoff > 0 && currentRank == standing.promotionRankCutoff) {
                  return _buildThresholdLine('PROMOTION ZONE', AppColors.accent);
                }

                // Relegation zone threshold line
                if (standing.relegationRankCutoff > 0 && currentRank == standing.relegationRankCutoff) {
                  return _buildThresholdLine('RELEGATION ZONE', AppColors.rival);
                }

                return const Divider(color: AppColors.border, height: 1);
              },
              itemBuilder: (context, index) {
                final participant = standing.standings[index];
                return _buildParticipantRow(participant);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildThresholdLine(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: color.withValues(alpha: 0.08),
      child: Row(
        children: [
          Expanded(child: Container(height: 1, color: color.withValues(alpha: 0.6))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Expanded(child: Container(height: 1, color: color.withValues(alpha: 0.6))),
        ],
      ),
    );
  }

  Widget _buildParticipantRow(LeagueParticipant participant) {
    final isMe = participant.isCurrentUser;
    Color rankColor;
    if (participant.rank == 1) {
      rankColor = AppColors.gold;
    } else if (participant.rank == 2) {
      rankColor = AppColors.silver;
    } else if (participant.rank == 3) {
      rankColor = AppColors.bronze;
    } else {
      rankColor = isMe ? AppColors.accent : AppColors.textSecondary;
    }

    return Container(
      color: isMe ? AppColors.accentContainer : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
      child: Row(
        children: [
          // Rank Badge
          SizedBox(
            width: 28,
            child: Text(
              '#${participant.rank}',
              style: AppText.caption.copyWith(
                color: rankColor,
                fontWeight: isMe || participant.rank <= 3 ? FontWeight.w900 : FontWeight.bold,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s8),

          // User Call Sign and Faction
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      participant.username,
                      style: AppText.body.copyWith(
                        color: isMe ? AppColors.accent : AppColors.textPrimary,
                        fontWeight: isMe ? FontWeight.w900 : FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'YOU',
                          style: TextStyle(
                            color: AppColors.onAccent,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  participant.faction,
                  style: AppText.caption.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          // Metric Area Claimed
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${participant.weeklyAreaSqm.toStringAsFixed(0)} m²',
                style: AppText.caption.copyWith(
                  color: isMe ? AppColors.accent : AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                '${participant.weeklyRuns} runs',
                style: AppText.caption.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 10,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile({
    required String label,
    required String value,
    required String unit,
    Color valueColor = AppColors.textPrimary,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: AppText.caption.copyWith(
            color: AppColors.textMuted,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: AppText.headingSmall.copyWith(
                color: valueColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (unit.isNotEmpty) ...[
              const SizedBox(width: 2),
              Text(
                unit,
                style: AppText.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  String _getZoneLabel(LeagueStanding s) {
    if (s.promotionRankCutoff > 0 && s.rank <= s.promotionRankCutoff) {
      return 'PROMOTION';
    }
    if (s.relegationRankCutoff > 0 && s.rank > s.relegationRankCutoff) {
      return 'RELEGATION';
    }
    return 'SAFE ZONE';
  }

  Color _getZoneColor(LeagueStanding s) {
    if (s.promotionRankCutoff > 0 && s.rank <= s.promotionRankCutoff) {
      return AppColors.accent;
    }
    if (s.relegationRankCutoff > 0 && s.rank > s.relegationRankCutoff) {
      return AppColors.rival;
    }
    return AppColors.textSecondary;
  }
}
