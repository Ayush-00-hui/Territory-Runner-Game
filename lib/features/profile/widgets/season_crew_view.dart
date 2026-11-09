import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/team_validation.dart';
import '../../../models/crew.dart';
import '../../../models/season.dart';
import '../../../services/crew_season_service.dart';
import '../../../ui/ui.dart';

/// Season standings and crew weekly goals view.
class SeasonCrewView extends StatefulWidget {
  final CrewSeasonService? service;

  const SeasonCrewView({super.key, this.service});

  @override
  State<SeasonCrewView> createState() => _SeasonCrewViewState();
}

class _SeasonCrewViewState extends State<SeasonCrewView> {
  late final CrewSeasonService _service;
  Timer? _countdownTicker;
  int _remainingSeconds = 0;
  bool _isActionLoading = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? CrewSeasonService.instance;
    _initData();
  }

  Future<void> _initData() async {
    await _service.loadCachedData();
    _updateCountdownFromService();
    _startCountdownTimer();
    await _service.refresh();
    if (mounted) {
      _updateCountdownFromService();
    }
  }

  void _updateCountdownFromService() {
    final season = _service.currentSeason.value;
    if (season != null) {
      final now = DateTime.now().toUtc();
      final diff = season.season.endsAt.difference(now).inSeconds;
      setState(() {
        _remainingSeconds = diff > 0 ? diff : 0;
      });
    }
  }

  void _startCountdownTimer() {
    _countdownTicker?.cancel();
    _countdownTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      }
    });
  }

  @override
  void dispose() {
    _countdownTicker?.cancel();
    super.dispose();
  }

  String _formatCountdown(int seconds) {
    if (seconds <= 0) return 'Season completed';
    final days = seconds ~/ 86400;
    final hours = (seconds % 86400) ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (days > 0) {
      return '${days}d ${hours}h ${minutes}m left';
    } else if (hours > 0) {
      return '${hours}h ${minutes}m ${secs}s left';
    } else {
      return '${minutes}m ${secs}s left';
    }
  }

  String _formatLocalDate(DateTime utcDate) {
    final local = utcDate.toLocal();
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final m = months[local.month - 1];
    final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final amPm = local.hour >= 12 ? 'PM' : 'AM';
    final minutePadded = local.minute.toString().padLeft(2, '0');
    return '$m ${local.day}, $hour12:$minutePadded $amPm';
  }

  void _showCreateCrewDialog() {
    final controller = TextEditingController();
    String? validationError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: AppSpacing.br20,
            side: const BorderSide(color: AppColors.border),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.group_add_rounded,
                color: AppColors.accent,
                size: 22,
              ),
              const SizedBox(width: AppSpacing.s8),
              Text(
                'Create Runner Crew',
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
                'Create a crew for up to 10 runners. You will become the crew leader.',
                style: AppText.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppSpacing.s16),
              TextField(
                controller: controller,
                autofocus: true,
                style: AppText.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                maxLength: 24,
                onChanged: (val) {
                  setDialogState(() {
                    validationError = TeamNameValidator.validate(val);
                  });
                },
                decoration: InputDecoration(
                  labelText: 'Crew name',
                  labelStyle: const TextStyle(color: AppColors.textMuted),
                  errorText: validationError,
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
            SecondaryButton(
              label: 'Cancel',
              onPressed: () => Navigator.pop(ctx),
            ),
            PrimaryButton(
              label: 'Create',
              isLoading: _isActionLoading,
              onPressed: () async {
                final error = TeamNameValidator.validate(controller.text);
                if (error != null) {
                  setDialogState(() => validationError = error);
                  return;
                }

                Navigator.pop(ctx);
                setState(() => _isActionLoading = true);
                try {
                  await _service.createCrew(controller.text.trim());
                  AppToast.showGlobal(
                    'Crew created successfully!',
                    type: AppToastType.success,
                  );
                } catch (e) {
                  AppToast.showGlobal(
                    'Could not create crew: $e',
                    type: AppToastType.error,
                  );
                } finally {
                  if (mounted) setState(() => _isActionLoading = false);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showJoinCrewDialog() {
    final controller = TextEditingController();

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
            const Icon(
              Icons.vpn_key_rounded,
              color: AppColors.accent,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.s8),
            Text(
              'Join with Code',
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
              'Enter the 6-character crew invite code (e.g. CRW-A7X9):',
              style: AppText.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              style: AppText.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
              maxLength: 10,
              decoration: InputDecoration(
                labelText: 'Join code',
                hintText: 'CRW-XXXX',
                labelStyle: const TextStyle(color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.surface2,
                border: OutlineInputBorder(
                  borderRadius: AppSpacing.br12,
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
          ],
        ),
        actions: [
          SecondaryButton(label: 'Cancel', onPressed: () => Navigator.pop(ctx)),
          PrimaryButton(
            label: 'Join Crew',
            isLoading: _isActionLoading,
            onPressed: () async {
              final code = controller.text.trim().toUpperCase();
              if (code.isEmpty) return;

              Navigator.pop(ctx);
              setState(() => _isActionLoading = true);
              try {
                await _service.joinCrew(code);
                AppToast.showGlobal(
                  'Joined crew successfully!',
                  type: AppToastType.success,
                );
              } catch (e) {
                AppToast.showGlobal(
                  'Could not join crew: $e',
                  type: AppToastType.error,
                );
              } finally {
                if (mounted) setState(() => _isActionLoading = false);
              }
            },
          ),
        ],
      ),
    );
  }

  void _showSetGoalDialog() {
    String selectedType = 'distance';
    final controller = TextEditingController(text: '50');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: AppSpacing.br20,
            side: const BorderSide(color: AppColors.border),
          ),
          title: Row(
            children: [
              const Icon(Icons.flag_rounded, color: AppColors.accent, size: 22),
              const SizedBox(width: AppSpacing.s8),
              Text(
                'Set Weekly Crew Target',
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
                'Weekly targets reset every Monday 00:00 UTC. Choose whether your crew tracks distance or claimed area.',
                style: AppText.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppSpacing.s16),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Distance (km)'),
                      selected: selectedType == 'distance',
                      onSelected: (selected) {
                        if (selected) {
                          setDialogState(() {
                            selectedType = 'distance';
                            controller.text = '50';
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Area (m²)'),
                      selected: selectedType == 'area',
                      onSelected: (selected) {
                        if (selected) {
                          setDialogState(() {
                            selectedType = 'area';
                            controller.text = '25000';
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                style: AppText.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  labelText: selectedType == 'distance'
                      ? 'Target Distance (km)'
                      : 'Target Area (m²)',
                  labelStyle: const TextStyle(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.surface2,
                  border: OutlineInputBorder(
                    borderRadius: AppSpacing.br12,
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            SecondaryButton(
              label: 'Cancel',
              onPressed: () => Navigator.pop(ctx),
            ),
            PrimaryButton(
              label: 'Save Goal',
              isLoading: _isActionLoading,
              onPressed: () async {
                final val = double.tryParse(controller.text.trim());
                if (val == null || val <= 0) return;

                // Distance is converted to meters for API consistency if entered in km
                final target = selectedType == 'distance' ? val * 1000.0 : val;

                Navigator.pop(ctx);
                setState(() => _isActionLoading = true);
                try {
                  await _service.setCrewGoal(selectedType, target);
                  AppToast.showGlobal(
                    'Weekly goal updated!',
                    type: AppToastType.success,
                  );
                } catch (e) {
                  AppToast.showGlobal(
                    'Could not set goal: $e',
                    type: AppToastType.error,
                  );
                } finally {
                  if (mounted) setState(() => _isActionLoading = false);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _service.isOffline,
      builder: (context, offline, _) {
        return ValueListenableBuilder<CurrentSeasonData?>(
          valueListenable: _service.currentSeason,
          builder: (context, seasonData, _) {
            return ValueListenableBuilder<MyCrewData?>(
              valueListenable: _service.currentCrew,
              builder: (context, crewData, _) {
                return RefreshIndicator(
                  onRefresh: () async {
                    await _service.refresh();
                    if (mounted) _updateCountdownFromService();
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s16,
                      vertical: AppSpacing.s12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (offline) ...[
                          _buildOfflineBanner(),
                          const SizedBox(height: AppSpacing.s16),
                        ],
                        _buildSeasonSection(seasonData),
                        const SizedBox(height: AppSpacing.s24),
                        _buildCrewSection(crewData),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s12,
        vertical: AppSpacing.s8,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: AppSpacing.br12,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 16, color: AppColors.rival),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Text(
              'Offline • Showing cached season and crew standings',
              style: AppText.caption.copyWith(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeasonSection(CurrentSeasonData? seasonData) {
    final season = seasonData?.season;
    final standing = seasonData?.userStanding;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s20),
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  'ACTIVE SEASON',
                  style: AppText.label.copyWith(
                    color: AppColors.accent,
                    letterSpacing: 1.0,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: AppSpacing.brFull,
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.timer_outlined,
                      size: 13,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatCountdown(_remainingSeconds),
                      style: AppText.caption.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            season?.name ?? 'Monthly Season',
            style: AppText.headingSmall.copyWith(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          if (season != null) ...[
            const SizedBox(height: 4),
            Text(
              'Ends ${_formatLocalDate(season.endsAt)} (Local time)',
              style: AppText.caption.copyWith(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.s16),
          // Runner standing card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.s12),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: AppSpacing.br12,
              border: Border.all(color: AppColors.border),
            ),
            child: standing != null
                ? Row(
                    children: [
                      Expanded(
                        child: _buildStatCol(
                          'Rank',
                          standing.seasonRank > 0
                              ? '#${standing.seasonRank}'
                              : '-',
                        ),
                      ),
                      Expanded(
                        child: _buildStatCol(
                          'Area',
                          '${standing.totalAreaSqm.toStringAsFixed(0)} m²',
                        ),
                      ),
                      Expanded(
                        child: _buildStatCol(
                          'Distance',
                          '${(standing.totalDistanceM / 1000).toStringAsFixed(1)} km',
                        ),
                      ),
                      Expanded(child: _buildStatCol('XP', '${standing.xp}')),
                    ],
                  )
                : Text(
                    'No season activity recorded yet. Run and capture territory this month to claim your standing.',
                    style: AppText.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
          ),
          if (seasonData != null && seasonData.factionStandings.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s16),
            Text(
              'Faction Standings',
              style: AppText.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.s8),
            ...seasonData.factionStandings.map((f) => _buildFactionRow(f)),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCol(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: AppText.bodyLarge.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppText.caption.copyWith(
            color: AppColors.textMuted,
            fontSize: 11,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildFactionRow(SeasonFactionStanding faction) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              faction.faction,
              style: AppText.bodySmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          Flexible(
            flex: 4,
            child: Text(
              '${faction.runnerCount} runners • ${faction.totalAreaSqm.toStringAsFixed(0)} m²',
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption.copyWith(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCrewSection(MyCrewData? crewData) {
    final crew = crewData?.crew;

    if (crew == null) {
      return _buildNoCrewCard();
    }

    final isLeader = crewData?.isLeader ?? false;
    final goal = crewData?.activeGoal;
    final members = crewData?.members ?? [];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s20),
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  'YOUR CREW',
                  style: AppText.label.copyWith(
                    color: AppColors.accent,
                    letterSpacing: 1.0,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              Semantics(
                button: true,
                label: 'Copy crew join code ${crew.joinCode}',
                child: InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: crew.joinCode));
                    AppToast.showGlobal(
                      'Join code ${crew.joinCode} copied to clipboard',
                      type: AppToastType.info,
                    );
                  },
                  borderRadius: AppSpacing.brFull,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: AppSpacing.brFull,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          crew.joinCode,
                          style: AppText.caption.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.copy_rounded,
                          size: 12,
                          color: AppColors.textMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            crew.name,
            style: AppText.headingSmall.copyWith(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.s20),

          // Weekly goal card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.s16),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: AppSpacing.br16,
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.s8,
                  runSpacing: AppSpacing.s4,
                  children: [
                    Text(
                      'WEEKLY CREW GOAL',
                      style: AppText.labelSmall.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (isLeader)
                      SecondaryButton(
                        label: goal != null ? 'Edit Target' : 'Set Target',
                        onPressed: _showSetGoalDialog,
                        isFullWidth: false,
                        height: 38,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s8),
                if (goal != null) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          goal.goalType == 'distance'
                              ? '${(goal.currentValue / 1000).toStringAsFixed(1)} / ${(goal.targetValue / 1000).toStringAsFixed(1)} km'
                              : '${goal.currentValue.toStringAsFixed(0)} / ${goal.targetValue.toStringAsFixed(0)} m²',
                          style: AppText.bodyMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s8),
                      Text(
                        '${goal.progressPercent.toStringAsFixed(0)}%',
                        style: AppText.bodySmall.copyWith(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  ClipRRect(
                    borderRadius: AppSpacing.brFull,
                    child: LinearProgressIndicator(
                      value: (goal.progressPercent / 100.0).clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: AppColors.surface,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.accent,
                      ),
                    ),
                  ),
                ] else ...[
                  Text(
                    isLeader
                        ? 'Set a weekly distance or area target for your crew.'
                        : 'No weekly goal active yet. Ask your crew leader to set one.',
                    style: AppText.bodySmall.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s20),

          // Member roster
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Members (${members.length}/10)',
                  style: AppText.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              Flexible(
                child: Text(
                  'Weekly contribution',
                  style: AppText.caption.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          ...members.map((m) => _buildMemberRow(m)),
        ],
      ),
    );
  }

  Widget _buildMemberRow(CrewMember member) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: member.isLeader
                ? AppColors.accent.withValues(alpha: 0.2)
                : AppColors.surface2,
            child: Icon(
              member.isLeader ? Icons.star_rounded : Icons.person_outline,
              size: 15,
              color: member.isLeader ? AppColors.accent : AppColors.textMuted,
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    member.username,
                    style: AppText.bodySmall.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (member.isLeader) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      borderRadius: AppSpacing.brFull,
                    ),
                    child: Text(
                      'Leader',
                      style: AppText.caption.copyWith(
                        color: AppColors.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          Flexible(
            flex: 2,
            child: Text(
              '${(member.weeklyDistanceM / 1000).toStringAsFixed(1)} km • ${member.weeklyAreaSqm.toStringAsFixed(0)} m²',
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption.copyWith(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoCrewCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppSpacing.br20,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.s12),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(
              Icons.group_work_outlined,
              size: 28,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          Text(
            'Crew Weekly Goals',
            style: AppText.headingSmall.copyWith(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Join or create a crew to tackle weekly distance and area goals together. Each runner can belong to one crew of up to 10 members.',
            textAlign: TextAlign.center,
            style: AppText.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.s20),
          PrimaryButton(label: 'Create Crew', onPressed: _showCreateCrewDialog),
          const SizedBox(height: AppSpacing.s12),
          SecondaryButton(
            label: 'Join with Code',
            onPressed: _showJoinCrewDialog,
          ),
        ],
      ),
    );
  }
}
