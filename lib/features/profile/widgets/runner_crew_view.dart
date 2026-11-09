import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/team_validation.dart';
import '../../../models/crew.dart';
import '../../../services/crew_season_service.dart';
import '../../../ui/ui.dart';

/// Runner Team and Crew management view.
/// Allows runners to create teams of up to 10 athletes, join with invite codes,
/// monitor weekly team goals, and track member contributions.
class RunnerCrewView extends StatefulWidget {
  final CrewSeasonService? service;

  const RunnerCrewView({super.key, this.service});

  @override
  State<RunnerCrewView> createState() => _RunnerCrewViewState();
}

class _RunnerCrewViewState extends State<RunnerCrewView> {
  late final CrewSeasonService _service;
  bool _isActionLoading = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? CrewSeasonService.instance;
    _loadData();
  }

  Future<void> _loadData() async {
    await _service.loadCachedData();
    if (mounted) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    try {
      await _service.refresh();
    } catch (_) {
      // Offline fallback already loaded from cache
    }
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
                'Create Runner Team',
                style: AppText.titleSmall.copyWith(
                  color: AppColors.textPrimary,
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
                'Create a team for up to 10 runners. You will become the team leader and can invite fellow athletes.',
                style: AppText.bodySmall.copyWith(
                  color: AppColors.textSecondary,
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
                  labelText: 'Team name',
                  hintText: 'e.g. Apex Sprinters',
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
              isFullWidth: false,
              onPressed: () => Navigator.pop(ctx),
            ),
            PrimaryButton(
              label: 'Create Team',
              isFullWidth: false,
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
                    'Team created successfully! Invite teammates with your code.',
                    type: AppToastType.success,
                  );
                } catch (e) {
                  AppToast.showGlobal(
                    'Could not create team: $e',
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
              'Join Team with Code',
              style: AppText.titleSmall.copyWith(
                color: AppColors.textPrimary,
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
              'Enter the team invite code (e.g. CRW-A7X9) provided by your team leader:',
              style: AppText.bodySmall.copyWith(
                color: AppColors.textSecondary,
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
                labelText: 'Invite code',
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
          SecondaryButton(
            label: 'Cancel',
            isFullWidth: false,
            onPressed: () => Navigator.pop(ctx),
          ),
          PrimaryButton(
            label: 'Join Team',
            isFullWidth: false,
            isLoading: _isActionLoading,
            onPressed: () async {
              final code = controller.text.trim().toUpperCase();
              if (code.isEmpty) return;

              Navigator.pop(ctx);
              setState(() => _isActionLoading = true);
              try {
                await _service.joinCrew(code);
                AppToast.showGlobal(
                  'Joined team successfully!',
                  type: AppToastType.success,
                );
              } catch (e) {
                AppToast.showGlobal(
                  'Could not join team: $e',
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
                'Set Weekly Team Target',
                style: AppText.titleSmall.copyWith(
                  color: AppColors.textPrimary,
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
                'Weekly targets reset every Monday 00:00 UTC. Choose whether your team tracks total distance or claimed area.',
                style: AppText.bodySmall.copyWith(
                  color: AppColors.textSecondary,
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
              isFullWidth: false,
              onPressed: () => Navigator.pop(ctx),
            ),
            PrimaryButton(
              label: 'Save Target',
              isFullWidth: false,
              isLoading: _isActionLoading,
              onPressed: () async {
                final val = double.tryParse(controller.text.trim());
                if (val == null || val <= 0) return;

                final target = selectedType == 'distance' ? val * 1000.0 : val;

                Navigator.pop(ctx);
                setState(() => _isActionLoading = true);
                try {
                  await _service.setCrewGoal(selectedType, target);
                  AppToast.showGlobal(
                    'Weekly target updated!',
                    type: AppToastType.success,
                  );
                } catch (e) {
                  AppToast.showGlobal(
                    'Could not set target: $e',
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
    return ValueListenableBuilder<MyCrewData?>(
      valueListenable: _service.currentCrew,
      builder: (context, crewData, _) {
        if (crewData?.crew == null) {
          return _buildNoCrewCard();
        }
        return _buildCrewSection(crewData!);
      },
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
              size: 32,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          Text(
            'Runner Teams & Crews',
            style: AppText.headingSmall.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Team up with up to 10 runners to claim territory and achieve weekly distance or area goals together.',
            textAlign: TextAlign.center,
            style: AppText.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.s24),
          PrimaryButton(
            label: 'Create Team',
            icon: Icons.group_add_rounded,
            onPressed: _showCreateCrewDialog,
          ),
          const SizedBox(height: AppSpacing.s12),
          SecondaryButton(
            label: 'Join Team with Code',
            icon: Icons.vpn_key_rounded,
            onPressed: _showJoinCrewDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildCrewSection(MyCrewData crewData) {
    final crew = crewData.crew!;
    final isLeader = crewData.isLeader;
    final goal = crewData.activeGoal;
    final members = crewData.members;

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
          // Header: YOUR TEAM + Role + Copy Code
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'YOUR TEAM',
                    style: AppText.labelSmall.copyWith(
                      color: AppColors.accent,
                      letterSpacing: 1.0,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isLeader
                          ? AppColors.accentContainer
                          : AppColors.surface2,
                      borderRadius: AppSpacing.brFull,
                      border: Border.all(
                        color: isLeader
                            ? AppColors.accent
                            : AppColors.borderSubtle,
                      ),
                    ),
                    child: Text(
                      isLeader ? 'Leader' : 'Member',
                      style: AppText.caption.copyWith(
                        color: isLeader
                            ? AppColors.accent
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              Semantics(
                button: true,
                label: 'Copy team join code ${crew.joinCode}',
                child: InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: crew.joinCode));
                    AppToast.showGlobal(
                      'Invite code ${crew.joinCode} copied to clipboard! Share it with friends.',
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
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.copy_rounded,
                          size: 12,
                          color: AppColors.accent,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            crew.name,
            style: AppText.headingMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.s20),

          // Weekly Goal Card
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'WEEKLY TEAM TARGET',
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
                        height: 34,
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
                        ? 'Set a weekly distance or area target for your team.'
                        : 'No weekly target active yet. Ask your team leader to set one.',
                    style: AppText.bodySmall.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s20),

          // Member roster header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Members (${members.length}/10)',
                style: AppText.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Weekly contribution',
                style: AppText.caption.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          ...members.map((m) => _buildMemberTile(m)),
        ],
      ),
    );
  }

  Widget _buildMemberTile(CrewMember member) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s8),
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
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.surface,
            child: Text(
              member.username.isNotEmpty
                  ? member.username[0].toUpperCase()
                  : 'R',
              style: AppText.caption.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
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
                if (member.role == 'leader') ...[
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.star_rounded,
                    size: 14,
                    color: AppColors.accent,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          Text(
            '${(member.weeklyDistanceM / 1000).toStringAsFixed(1)} km • ${member.weeklyAreaSqm.toStringAsFixed(0)} m²',
            style: AppText.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
