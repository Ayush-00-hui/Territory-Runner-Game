import '../../../models/faction_standing.dart';

import 'package:flutter/material.dart';

import '../../../core/utils/team_validation.dart';
import '../../gameplay/territory_service.dart';
import '../../../models/runner_profile.dart';
import '../../../services/api_client.dart';
import '../../../ui/ui.dart';

void showEditCallsignDialog(
  BuildContext context,
  RunnerProfile profile,
  TerritoryService territoryService,
  VoidCallback onUpdated,
) {
  final controller = TextEditingController(text: profile.username);
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppSpacing.br20,
        side: const BorderSide(color: AppColors.border),
      ),
      title: Row(
        children: [
          const Icon(Icons.badge_rounded, color: AppColors.accent, size: 20),
          const SizedBox(width: AppSpacing.s8),
          Text(
            'Edit Runner Name',
            style: AppText.headingSmall.copyWith(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose your runner name displayed on leaderboards and team standings:',
            style: AppText.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          TextField(
            controller: controller,
            style: AppText.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            maxLength: 20,
            decoration: InputDecoration(
              labelText: 'Runner name',
              labelStyle: const TextStyle(color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.surface2,
              border: OutlineInputBorder(
                borderRadius: AppSpacing.br12,
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppSpacing.br12,
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppSpacing.br12,
                borderSide: const BorderSide(
                  color: AppColors.accent,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        SecondaryButton(label: 'Cancel', onPressed: () => Navigator.pop(ctx)),
        PrimaryButton(
          label: 'Save Name',
          onPressed: () async {
            final newName = controller.text.trim();
            if (newName.isNotEmpty) {
              profile.username = newName;
              await territoryService.saveProfile(profile);
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
              onUpdated();
              if (context.mounted) {
                AppToast.show(context, 'Runner name updated to "$newName"');
              }
            }
          },
        ),
      ],
    ),
  );
}

void showFactionSelectionDialog(
  BuildContext context,
  RunnerProfile profile,
  TerritoryService territoryService,
  VoidCallback onUpdated,
) {
  AppSheet.show(
    context: context,
    builder: (ctx) => AppSheet(
      title: 'Teams',
      child: TeamSelectionSheet(
        profile: profile,
        territoryService: territoryService,
        onUpdated: onUpdated,
      ),
    ),
  );
}

class TeamSelectionSheet extends StatefulWidget {
  final RunnerProfile profile;
  final TerritoryService territoryService;
  final VoidCallback onUpdated;

  const TeamSelectionSheet({
    super.key,
    required this.profile,
    required this.territoryService,
    required this.onUpdated,
  });

  @override
  State<TeamSelectionSheet> createState() => _TeamSelectionSheetState();
}

class _TeamSelectionSheetState extends State<TeamSelectionSheet> {
  final TextEditingController _customTeamController = TextEditingController();
  List<FactionStanding> _serverTeams = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTeams();
  }

  @override
  void dispose() {
    _customTeamController.dispose();
    super.dispose();
  }

  Future<void> _loadTeams() async {
    try {
      final resp = await ApiClient().getFactionStandings();
      if (mounted) {
        setState(() {
          _serverTeams =
              resp?.standings
                  .where((s) => s.faction.trim().isNotEmpty)
                  .toList() ??
              [];
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _serverTeams = [];
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _setTeam(String teamName) async {
    final trimmed = teamName.trim();
    if (trimmed.isNotEmpty) {
      final validationError = TeamNameValidator.validate(teamName);
      if (validationError != null) {
        setState(() => _errorMessage = validationError);
        AppToast.showGlobal(validationError);
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final sanitized = TeamNameValidator.sanitize(teamName);
      try {
        await ApiClient().updateUserFaction(sanitized);
      } on ApiException catch (e) {
        // If server responded with a meaningful rejection detail, surface it to runner
        if (e.message.isNotEmpty && e.code != 'UNKNOWN') {
          if (!mounted) return;
          setState(() {
            _isSubmitting = false;
            _errorMessage = e.message;
          });
          AppToast.showGlobal(e.message);
          return;
        }
      } catch (_) {
        // Offline / network failure: allow local persistence for offline-first resilience
      }

      widget.profile.faction = sanitized;
      await widget.territoryService.saveProfile(widget.profile);
      if (!mounted) return;
      Navigator.pop(context);
      widget.onUpdated();
      AppToast.showGlobal(
        sanitized.isEmpty
            ? 'Left team (Independent)'
            : 'Team set to $sanitized',
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
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
    final currentFaction = widget.profile.faction.trim();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Join an active team or create your own:',
          style: AppText.bodySmall.copyWith(
            color: AppColors.textSecondary,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: AppSpacing.s16),

        if (_isLoading)
          const AppLoadingView(
            label: 'Loading running teams...',
            painterSize: 44,
          )
        else if (_serverTeams.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s16),
            alignment: Alignment.center,
            child: Text(
              'No teams currently active.\nCreate a team below to get started!',
              textAlign: TextAlign.center,
              style: AppText.bodySmall.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          )
        else
          ..._serverTeams.map((team) {
            final isSelected =
                currentFaction.isNotEmpty && currentFaction == team.faction;

            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s10),
              child: GestureDetector(
                onTap: () => _setTeam(team.faction),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.s14),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.accent.withValues(alpha: 0.12)
                        : AppColors.surface2,
                    borderRadius: AppSpacing.br14,
                    border: Border.all(
                      color: isSelected ? AppColors.accent : AppColors.border,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.16),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.shield_outlined,
                          color: AppColors.accent,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              team.faction,
                              style: AppText.bodyMedium.copyWith(
                                color: isSelected
                                    ? AppColors.accent
                                    : AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${team.memberCount} ${team.memberCount == 1 ? "member" : "members"} • ${_formatArea(team.totalAreaSqm)}',
                              style: AppText.labelSmall.copyWith(
                                color: AppColors.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.2),
                            borderRadius: AppSpacing.br8,
                          ),
                          child: Text(
                            'Active',
                            style: AppText.labelSmall.copyWith(
                              color: AppColors.accent,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),

        const SizedBox(height: AppSpacing.s16),
        Text(
          'Create or enter team name:',
          style: AppText.labelSmall.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _customTeamController,
                maxLength: 24,
                enabled: !_isSubmitting,
                onChanged: (val) {
                  if (_errorMessage != null) {
                    setState(() => _errorMessage = null);
                  }
                },
                style: AppText.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: 'e.g. Morning Striders',
                  hintStyle: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                  errorText: _errorMessage,
                  errorMaxLines: 2,
                  errorStyle: const TextStyle(
                    color: AppColors.rival,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  counterText: '',
                  filled: true,
                  fillColor: AppColors.surface2,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s12,
                    vertical: AppSpacing.s10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: AppSpacing.br12,
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: AppSpacing.br12,
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: AppSpacing.br12,
                    borderSide: const BorderSide(
                      color: AppColors.accent,
                      width: 1.5,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: AppSpacing.br12,
                    borderSide: const BorderSide(
                      color: AppColors.rival,
                      width: 1.0,
                    ),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: AppSpacing.br12,
                    borderSide: const BorderSide(
                      color: AppColors.rival,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            PrimaryButton(
              label: 'Save',
              isLoading: _isSubmitting,
              isFullWidth: false,
              height: 48,
              onPressed: () {
                final name = _customTeamController.text.trim();
                if (name.isEmpty) {
                  setState(() => _errorMessage = 'Team name cannot be empty');
                  AppToast.showGlobal('Team name cannot be empty');
                  return;
                }
                _setTeam(name);
              },
            ),
          ],
        ),

        if (currentFaction.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s12),
          SecondaryButton(
            label: 'Leave Team (Run Independent)',
            onPressed: () => _setTeam(''),
          ),
        ],
      ],
    );
  }
}

void showStatDetailModal(
  BuildContext context, {
  required String title,
  required String value,
  required String description,
  required List<Map<String, String>> metrics,
}) {
  AppSheet.show(
    context: context,
    builder: (ctx) => AppSheet(
      title: title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Stats Summary',
                style: AppText.labelSmall.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                value,
                style: AppText.headlineSmall.copyWith(
                  color: AppColors.accent,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          Text(
            description,
            style: AppText.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          Container(
            padding: const EdgeInsets.all(AppSpacing.s16),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: AppSpacing.br16,
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: metrics.map((m) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        m['label'] ?? '',
                        style: AppText.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        m['val'] ?? '',
                        style: AppText.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: AppSpacing.s20),
          PrimaryButton(label: 'Close', onPressed: () => Navigator.pop(ctx)),
        ],
      ),
    ),
  );
}

void showBadgeDetailModal(
  BuildContext context, {
  required String title,
  required String subtitle,
  required bool unlocked,
  required String criteria,
  required String reward,
}) {
  final Color badgeColor = unlocked ? AppColors.gold : AppColors.disabled;

  AppSheet.show(
    context: context,
    builder: (ctx) => AppSheet(
      title: 'Achievement',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  unlocked
                      ? Icons.emoji_events_rounded
                      : Icons.lock_outline_rounded,
                  color: badgeColor,
                  size: 26,
                ),
              ),
              const SizedBox(width: AppSpacing.s14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppText.headlineMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: unlocked
                            ? AppColors.gold.withValues(alpha: 0.16)
                            : AppColors.surface2,
                        borderRadius: AppSpacing.br8,
                        border: Border.all(
                          color: unlocked
                              ? AppColors.gold.withValues(alpha: 0.3)
                              : AppColors.border,
                        ),
                      ),
                      child: Text(
                        unlocked ? 'Unlocked' : 'Locked',
                        style: AppText.labelSmall.copyWith(
                          color: unlocked
                              ? AppColors.gold
                              : AppColors.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s16),
          Container(
            padding: const EdgeInsets.all(AppSpacing.s16),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: AppSpacing.br16,
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Criteria',
                  style: AppText.labelSmall.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  criteria,
                  style: AppText.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const Divider(color: AppColors.border, height: 20),
                Text(
                  'Reward',
                  style: AppText.labelSmall.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  reward,
                  style: AppText.bodyMedium.copyWith(
                    color: AppColors.accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s20),
          PrimaryButton(
            label: unlocked ? 'Done' : 'Close',
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    ),
  );
}
