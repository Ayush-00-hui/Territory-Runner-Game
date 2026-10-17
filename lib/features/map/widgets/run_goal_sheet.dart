import 'package:flutter/material.dart';
import '../../../../models/run_goal.dart';
import '../../../../ui/ui.dart';

/// Modal bottom sheet allowing runners to configure conquest objectives
/// (Distance, Duration, or Area domain goals) before or during an active run.
class RunGoalSheet extends StatefulWidget {
  final RunGoal currentGoal;

  const RunGoalSheet({super.key, required this.currentGoal});

  static Future<RunGoal?> show(
    BuildContext context, {
    RunGoal currentGoal = RunGoal.none,
  }) {
    return showModalBottomSheet<RunGoal>(
      context: context,
      backgroundColor: AppColors.bgElevated,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => RunGoalSheet(currentGoal: currentGoal),
    );
  }

  @override
  State<RunGoalSheet> createState() => _RunGoalSheetState();
}

class _RunGoalSheetState extends State<RunGoalSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late GoalType _selectedType;
  late double _selectedValue;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.currentGoal.type;
    _selectedValue = widget.currentGoal.targetValue;

    int initialIndex = 0;
    if (_selectedType == GoalType.distance) {
      initialIndex = 0;
    } else if (_selectedType == GoalType.duration) {
      initialIndex = 1;
    } else if (_selectedType == GoalType.area) {
      initialIndex = 2;
    } else {
      initialIndex = 3;
    }

    _tabController = TabController(length: 4, vsync: this, initialIndex: initialIndex);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          switch (_tabController.index) {
            case 0:
              _selectedType = GoalType.distance;
              _selectedValue = 5.0;
              break;
            case 1:
              _selectedType = GoalType.duration;
              _selectedValue = 1800; // 30 min in sec
              break;
            case 2:
              _selectedType = GoalType.area;
              _selectedValue = 25000.0;
              break;
            case 3:
              _selectedType = GoalType.none;
              _selectedValue = 0.0;
              break;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(color: AppColors.borderSubtle, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: AppSpacing.s16),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  borderRadius: AppSpacing.br10,
                ),
                child: const Icon(Icons.flag_outlined, color: AppColors.accent, size: 22),
              ),
              const SizedBox(width: AppSpacing.s10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Run goal',
                    style: AppText.headingSmall.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'Set a target for your run',
                    style: AppText.label.copyWith(color: AppColors.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.s14),

          // Tab Bar
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppSpacing.br14,
              border: Border.all(color: AppColors.border),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: AppColors.accent,
                borderRadius: AppSpacing.br12,
              ),
              labelColor: AppColors.onAccent,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              tabs: const [
                Tab(text: 'Distance'),
                Tab(text: 'Time'),
                Tab(text: 'Territory'),
                Tab(text: 'Open'),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.s20),

          // Options based on selected tab
          if (_selectedType == GoalType.distance) ...[
            _buildDistanceGrid(),
          ] else if (_selectedType == GoalType.duration) ...[
            _buildDurationGrid(),
          ] else if (_selectedType == GoalType.area) ...[
            _buildAreaGrid(),
          ] else ...[
            _buildOpenRunCard(),
          ],

          const SizedBox(height: AppSpacing.s24),

          // Confirm CTA
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.onAccent,
                shape: RoundedRectangleBorder(borderRadius: AppSpacing.br14),
              ),
              onPressed: () {
                AppMotion.heavyBurst();
                final goal = RunGoal(type: _selectedType, targetValue: _selectedValue);
                Navigator.of(context).pop(goal);
              },
              child: Text(
                _selectedType == GoalType.none ? 'Start open run' : 'Set goal',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistanceGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildPresetCard('3.0 km', 'Quick Strike', 3.0, _selectedValue == 3.0)),
            const SizedBox(width: 10),
            Expanded(child: _buildPresetCard('5.0 km', 'Sector Patrol', 5.0, _selectedValue == 5.0)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildPresetCard('10.0 km', 'Endurance Sweep', 10.0, _selectedValue == 10.0)),
            const SizedBox(width: 10),
            Expanded(child: _buildPresetCard('21.1 km', 'Half-Marathon', 21.1, _selectedValue == 21.1)),
          ],
        ),
      ],
    );
  }

  Widget _buildDurationGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildPresetCard('15 min', 'Fast Burn', 900.0, _selectedValue == 900.0)),
            const SizedBox(width: 10),
            Expanded(child: _buildPresetCard('30 min', 'Standard Run', 1800.0, _selectedValue == 1800.0)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildPresetCard('45 min', 'Power Session', 2700.0, _selectedValue == 2700.0)),
            const SizedBox(width: 10),
            Expanded(child: _buildPresetCard('60 min', 'Full Campaign', 3600.0, _selectedValue == 3600.0)),
          ],
        ),
      ],
    );
  }

  Widget _buildAreaGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildPresetCard('10,000 m²', 'Perimeter Enclosure', 10000.0, _selectedValue == 10000.0)),
            const SizedBox(width: 10),
            Expanded(child: _buildPresetCard('25,000 m²', 'Sub-Sector Claim', 25000.0, _selectedValue == 25000.0)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildPresetCard('50,000 m²', 'District Dominion', 50000.0, _selectedValue == 50000.0)),
            const SizedBox(width: 10),
            Expanded(child: _buildPresetCard('100,000 m²', 'Imperial Sovereign', 100000.0, _selectedValue == 100000.0)),
          ],
        ),
      ],
    );
  }

  Widget _buildOpenRunCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppSpacing.br16,
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.8), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.explore_rounded, color: AppColors.accent, size: 20),
              const SizedBox(width: 8),
              Text(
                'No set target',
                style: AppText.headingSmall.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Explore the city freely at your own pace without distance or time constraints. Sovereign territories are claimed as you enclose loops.',
            style: AppText.bodySmall.copyWith(color: AppColors.textSecondary, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetCard(String title, String subtitle, double val, bool isSelected) {
    return GestureDetector(
      onTap: () {
        AppMotion.lightTick();
        setState(() {
          _selectedValue = val;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent.withValues(alpha: 0.12) : AppColors.surface,
          borderRadius: AppSpacing.br14,
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.borderSubtle,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: isSelected ? AppColors.accent : AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: isSelected ? AppColors.textSecondary : AppColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
