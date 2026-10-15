import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:latlong2/latlong.dart';
import '../gameplay/territory_service.dart';
import '../../models/runner_profile.dart';
import '../../models/territory.dart';
import '../../ui/ui.dart';
import 'widgets/history_run_card.dart';

enum HistoryTimeFilter {
  all,
  thisWeek,
  thisMonth,
}

enum HistorySortOption {
  newest,
  largestArea,
  longestDistance,
}

class RunHistoryScreen extends StatefulWidget {
  final List<Territory>? initialTerritories;
  final RunnerProfile? initialProfile;

  const RunHistoryScreen({
    super.key,
    this.initialTerritories,
    this.initialProfile,
  });

  @override
  State<RunHistoryScreen> createState() => _RunHistoryScreenState();
}

class _RunHistoryScreenState extends State<RunHistoryScreen> {
  final TerritoryService _territoryService = TerritoryService();
  HistoryTimeFilter _timeFilter = HistoryTimeFilter.all;
  HistorySortOption _sortOption = HistorySortOption.newest;

  double _estimateDistanceKm(List<LatLng> points) {
    if (points.length < 2) return 0.0;
    const distance = Distance();
    double meters = 0.0;
    for (int i = 0; i < points.length - 1; i++) {
      meters += distance(points[i], points[i + 1]);
    }
    meters += distance(points.last, points.first);
    return meters / 1000.0;
  }

  List<Territory> _filterAndSort(List<Territory> rawList) {
    final now = DateTime.now();

    final filtered = rawList.where((t) {
      switch (_timeFilter) {
        case HistoryTimeFilter.all:
          return true;
        case HistoryTimeFilter.thisWeek:
          return now.difference(t.capturedAt).inDays <= 7;
        case HistoryTimeFilter.thisMonth:
          return now.difference(t.capturedAt).inDays <= 30;
      }
    }).toList();

    filtered.sort((a, b) {
      switch (_sortOption) {
        case HistorySortOption.newest:
          return b.capturedAt.compareTo(a.capturedAt);
        case HistorySortOption.largestArea:
          return b.areaSqMeters.compareTo(a.areaSqMeters);
        case HistorySortOption.longestDistance:
          return _estimateDistanceKm(b.polygon).compareTo(_estimateDistanceKm(a.polygon));
      }
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: AppColors.bgDeep,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'CONQUEST ARCHIVE',
          style: AppText.headingSmall.copyWith(
            letterSpacing: 1.5,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
      ),
      body: widget.initialProfile != null
          ? _buildArchiveView(
              widget.initialProfile!,
              widget.initialTerritories ?? [],
            )
          : ValueListenableBuilder(
              valueListenable: Hive.box<RunnerProfile>('profile').listenable(),
              builder: (context, Box<RunnerProfile> profileBox, _) {
                final profile = _territoryService.getProfile();

                return ValueListenableBuilder(
                  valueListenable: Hive.box<Territory>('territories_v3').listenable(),
                  builder: (context, Box<Territory> territoryBox, _) {
                    final rawTerritories = _territoryService.getCapturedTerritoryObjects();
                    return _buildArchiveView(profile, rawTerritories);
                  },
                );
              },
            ),
    );
  }

  Widget _buildArchiveView(RunnerProfile profile, List<Territory> rawTerritories) {
    final territories = _filterAndSort(rawTerritories);

    // Compute aggregate stats
    double totalArea = 0.0;
    double totalDist = 0.0;
    for (final t in rawTerritories) {
      totalArea += t.areaSqMeters;
      totalDist += _estimateDistanceKm(t.polygon);
    }

              final totalAreaFormatted = totalArea >= 10000
                  ? '${(totalArea / 1000000.0).toStringAsFixed(2)} km²'
                  : '${totalArea.toStringAsFixed(0)} m²';

              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // Aggregate metrics summary banner
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s8, AppSpacing.s16, AppSpacing.s16),
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.s16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: AppSpacing.br20,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildSummaryMetric('TOTAL AREA', totalAreaFormatted, AppColors.accent),
                            Container(width: 1, height: 36, color: AppColors.border),
                            _buildSummaryMetric('CONQUESTS', '${rawTerritories.length}', Colors.white),
                            Container(width: 1, height: 36, color: AppColors.border),
                            _buildSummaryMetric('TOTAL DIST', '${totalDist.toStringAsFixed(1)} km', Colors.white),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Filter & Sort Pills
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Time filter row
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildFilterChip(HistoryTimeFilter.all, 'ALL RUNS'),
                                const SizedBox(width: AppSpacing.s8),
                                _buildFilterChip(HistoryTimeFilter.thisWeek, 'THIS WEEK'),
                                const SizedBox(width: AppSpacing.s8),
                                _buildFilterChip(HistoryTimeFilter.thisMonth, 'THIS MONTH'),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s12),

                          // Sort selector row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${territories.length} CONQUESTS FOUND',
                                style: AppText.label.copyWith(color: AppColors.textMuted, fontSize: 10.5),
                              ),
                              PopupMenuButton<HistorySortOption>(
                                initialValue: _sortOption,
                                color: AppColors.bgElevated,
                                shape: RoundedRectangleBorder(borderRadius: AppSpacing.br16),
                                onSelected: (opt) {
                                  AppMotion.lightTick();
                                  setState(() => _sortOption = opt);
                                },
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(
                                    value: HistorySortOption.newest,
                                    child: Text('Sort by Newest', style: AppText.body),
                                  ),
                                  const PopupMenuItem(
                                    value: HistorySortOption.largestArea,
                                    child: Text('Sort by Largest Area', style: AppText.body),
                                  ),
                                  const PopupMenuItem(
                                    value: HistorySortOption.longestDistance,
                                    child: Text('Sort by Longest Distance', style: AppText.body),
                                  ),
                                ],
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: AppSpacing.br8,
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.sort_rounded, size: 14, color: AppColors.accent),
                                      const SizedBox(width: 4),
                                      Text(
                                        _sortLabel(_sortOption),
                                        style: AppText.label.copyWith(color: AppColors.accent, fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.s12),
                        ],
                      ),
                    ),
                  ),

                  // List of runs
                  if (territories.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.s24),
                          child: EmptyState(
                            icon: Icons.history_toggle_off_rounded,
                            title: 'No Conquests In Range',
                            message: 'Try changing your filters or start a new run to capture sovereign loops.',
                            actionLabel: _timeFilter != HistoryTimeFilter.all ? 'RESET FILTERS' : null,
                            onAction: _timeFilter != HistoryTimeFilter.all
                                ? () => setState(() => _timeFilter = HistoryTimeFilter.all)
                                : null,
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.s16,
                        0,
                        AppSpacing.s16,
                        AppSpacing.s32,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final territory = territories[index];
                            return HistoryRunCard(
                              territory: territory,
                              callsign: profile.username,
                              faction: profile.faction,
                            );
                          },
                          childCount: territories.length,
                        ),
                      ),
                    ),
                ],
              );
  }

  String _sortLabel(HistorySortOption opt) {
    switch (opt) {
      case HistorySortOption.newest:
        return 'NEWEST';
      case HistorySortOption.largestArea:
        return 'LARGEST AREA';
      case HistorySortOption.longestDistance:
        return 'LONGEST';
    }
  }

  Widget _buildFilterChip(HistoryTimeFilter filter, String label) {
    final isSelected = _timeFilter == filter;
    return GestureDetector(
      onTap: () {
        AppMotion.lightTick();
        setState(() => _timeFilter = filter);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
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
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryMetric(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(
          label,
          style: AppText.label.copyWith(color: AppColors.textMuted, fontSize: 9.5),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppText.statSmall.copyWith(
            fontSize: 16,
            color: valueColor,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}
