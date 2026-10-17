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
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: AppSpacing.s16),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.15),
                  borderRadius: AppSpacing.br10,
                ),
                child: const Icon(Icons.flag_rounded, color: AppColors.gold, size: 22),
              ),
              const SizedBox(width: AppSpacing.s10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CAMPAIGN TARGET',
                    style: AppText.headingSmall.copyWith(fontSize: 15, fontWeight: FontWeight.w900),
                  ),
                  Text(
                    'CONQUEST OBJECTIVES & MILESTONES',
                    style: AppText.label.copyWith(color: AppColors.gold, fontSize: 9.5),
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
              labelColor: Colors.black,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
              tabs: const [
                Tab(text: 'DISTANCE'),
                Tab(text: 'TIME'),
                Tab(text: 'DOMAIN'),
                Tab(text: 'OPEN'),
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
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: AppSpacing.br14),
              ),
              onPressed: () {
                AppMotion.heavyBurst();
                final goal = RunGoal(type: _selectedType, targetValue: _selectedValue);
                Navigator.of(context).pop(goal);
              },
              child: Text(
                _selectedType == GoalType.none ? 'START OPEN EXPLORATION' : 'LOCK IN TARGET',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.8),
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
            Expanded(child: _buildPresetCard('3.0 KM', 'Quick Strike', 3.0, _selectedValue == 3.0)),
            const SizedBox(width: 10),
            Expanded(child: _buildPresetCard('5.0 KM', 'Sector Patrol', 5.0, _selectedValue == 5.0)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildPresetCard('10.0 KM', 'Endurance Sweep', 10.0, _selectedValue == 10.0)),
            const SizedBox(width: 10),
            Expanded(child: _buildPresetCard('21.1 KM', 'Half-Marathon', 21.1, _selectedValue == 21.1)),
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
            Expanded(child: _buildPresetCard('15 MIN', 'Fast Burn', 900.0, _selectedValue == 900.0)),
            const SizedBox(width: 10),
            Expanded(child: _buildPresetCard('30 MIN', 'Standard Run', 1800.0, _selectedValue == 1800.0)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildPresetCard('45 MIN', 'Power Session', 2700.0, _selectedValue == 2700.0)),
            const SizedBox(width: 10),
            Expanded(child: _buildPresetCard('60 MIN', 'Full Campaign', 3600.0, _selectedValue == 3600.0)),
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
                'NO SET TARGET',
                style: AppText.headingSmall.copyWith(fontSize: 14, fontWeight: FontWeight.bold),
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
            color: isSelected ? AppColors.accent : AppColors.border,
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: isSelected ? AppColors.accent : Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: isSelected ? Colors.white70 : AppColors.textMuted,
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
