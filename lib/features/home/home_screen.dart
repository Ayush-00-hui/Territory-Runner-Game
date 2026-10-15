import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../gameplay/territory_service.dart';
import '../../ui/theme/app_colors.dart';

/// Home Screen - Sovereign Territory Dashboard
class HomeScreen extends StatefulWidget {
  final VoidCallback? onStartRun;

  const HomeScreen({super.key, this.onStartRun});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tabFilterIndex = 0; // 0 = Map, 1 = Stats, 2 = Achievements
  int _timeFilterIndex = 1; // 0 = Week, 1 = Month, 2 = Year
  int _hydrationMl = 1750;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    final territoryService = TerritoryService();
    final profile = territoryService.getProfile();
    final capturedTerritories = territoryService.getCapturedTerritoryObjects();
    final double totalAreaSqMeters = capturedTerritories.fold(0.0, (sum, t) => sum + t.areaSqMeters);
    final double totalAreaSqKm = totalAreaSqMeters / 1000000.0;

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(20, topPad + 12, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- TOP HEADER ROW (Your Territory & Level Badge) ---
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Your Territory',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Every run leaves a mark.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                // Level Crown Badge Capsule
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFD700), size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Level ${profile.level}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Level Progress Bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          width: 86,
                          height: 4,
                          child: LinearProgressIndicator(
                            value: (profile.xp % 250) / 250.0,
                            backgroundColor: AppColors.surface2,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Run to Lvl ${profile.level + 1}',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // --- FILTER CAPSULE BAR (Map | Stats | Achievements) ---
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  _buildTabPill(0, 'Map'),
                  _buildTabPill(1, 'Stats'),
                  _buildTabPill(2, 'Achievements'),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // --- TERRITORY MAP HERO CARD ---
            GestureDetector(
              onTap: widget.onStartRun,
              child: Container(
                height: 220,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _TerritoryHeroMapPainter(),
                      ),
                    ),
                    Positioned(
                      top: 16,
                      left: 18,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Territory',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            totalAreaSqKm > 0
                                ? '${totalAreaSqKm.toStringAsFixed(2)} km²'
                                : (totalAreaSqMeters > 0 ? '${totalAreaSqMeters.toStringAsFixed(0)} m²' : '0.00 km²'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              '↗ Sovereign Territory',
                              style: TextStyle(
                                color: AppColors.accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // --- TERRITORY CONQUEST ENGINE BANNER ---
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
                    ),
                    child: const Icon(Icons.terrain_rounded, color: AppColors.accent, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Territory Conquest Engine',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Run closed loops to enclose and claim ground',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 16),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // --- "YOUR STATS" SECTION ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Your Stats',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      _buildTimePill(0, 'Week'),
                      _buildTimePill(1, 'Month'),
                      _buildTimePill(2, 'Year'),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // 4 Stats Cards Grid
            Row(
              children: [
                Expanded(
                  child: _buildStatTile(
                    title: 'Runs',
                    icon: Icons.directions_run_rounded,
                    value: '${(profile.totalDistanceKm > 0 ? (profile.totalDistanceKm / 3.0).ceil() : 0)}',
                    delta: '+100%',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStatTile(
                    title: 'Distance',
                    icon: Icons.location_on_rounded,
                    value: '${profile.totalDistanceKm.toStringAsFixed(1)} km',
                    delta: 'Total',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStatTile(
                    title: 'Territory',
                    icon: Icons.map_rounded,
                    value: totalAreaSqKm > 0
                        ? '${totalAreaSqKm.toStringAsFixed(2)} km²'
                        : (totalAreaSqMeters > 0 ? '${totalAreaSqMeters.toStringAsFixed(0)} m²' : '0.0 km²'),
                    delta: '${capturedTerritories.length} polys',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStatTile(
                    title: 'Calories',
                    icon: Icons.local_fire_department_rounded,
                    value: '${(profile.totalDistanceKm * 65).round()}',
                    delta: 'kcal',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // --- MOTIVATIONAL COACHING TIP BANNER ---
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cyanThruster.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.cyanThruster.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.tips_and_updates_rounded, color: AppColors.cyanThruster, size: 18),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ATHLETIC COACH TIP',
                          style: TextStyle(color: AppColors.cyanThruster, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.1),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Maintaining 170–180 SPM cadence reduces joint impact stress by 22% during territory conquest.',
                          style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // --- QUICK-LOG HYDRATION TRACKER ---
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
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
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00B0FF).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.water_drop_rounded, color: Color(0xFF00B0FF), size: 20),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'DAILY HYDRATION',
                                style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.1),
                              ),
                              Text(
                                '$_hydrationMl / 2,500 mL',
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00B0FF).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF00B0FF).withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          '${((_hydrationMl / 2500.0) * 100).round()}% TARGET',
                          style: const TextStyle(color: Color(0xFF00B0FF), fontSize: 10, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (_hydrationMl / 2500.0).clamp(0.0, 1.0),
                      backgroundColor: Colors.white10,
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00B0FF)),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            setState(() {
                              _hydrationMl = (_hydrationMl + 250).clamp(0, 5000);
                            });
                          },
                          icon: const Icon(Icons.add_rounded, size: 16, color: Color(0xFF00B0FF)),
                          label: const Text('+250 mL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            backgroundColor: AppColors.surface2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            setState(() {
                              _hydrationMl = (_hydrationMl + 500).clamp(0, 5000);
                            });
                          },
                          icon: const Icon(Icons.local_drink_rounded, size: 16, color: Color(0xFF00B0FF)),
                          label: const Text('+500 mL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            backgroundColor: AppColors.surface2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _hydrationMl = 0;
                          });
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 18, color: AppColors.textMuted),
                        tooltip: 'Reset hydration',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // --- INSPIRATION STORY BANNER ---
            Container(
              height: 100,
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF1E2638),
                    AppColors.surface,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text(
                          'Bigger routes.\nBolder stories.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            height: 1.15,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Keep exploring.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabPill(int index, String label) {
    final isSelected = _tabFilterIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _tabFilterIndex = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.surface2 : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textMuted,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimePill(int index, String label) {
    final isSelected = _timeFilterIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _timeFilterIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surface2 : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textMuted,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _buildStatTile({
    required String title,
    required IconData icon,
    required String value,
    required String delta,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            delta,
            style: const TextStyle(
              color: AppColors.accent,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom Painter for the Territory Map Hero Card Preview
class _TerritoryHeroMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Dark Grid map background
    final gridPaint = Paint()
      ..color = const Color(0xFF1E2230)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    for (double x = 0; x < size.width; x += 28) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Territory 1 (Left Polygon)
    final poly1 = Path()
      ..moveTo(size.width * 0.15, size.height * 0.45)
      ..lineTo(size.width * 0.28, size.height * 0.35)
      ..lineTo(size.width * 0.38, size.height * 0.55)
      ..lineTo(size.width * 0.30, size.height * 0.80)
      ..lineTo(size.width * 0.18, size.height * 0.72)
      ..close();

    final fillPaint1 = Paint()
      ..color = const Color(0xFF00E676).withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    final strokePaint1 = Paint()
      ..color = const Color(0xFF00E676)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawPath(poly1, fillPaint1);
    canvas.drawPath(poly1, strokePaint1);

    // Territory 2 (Large Right Polygon - Conquered)
    final poly2 = Path()
      ..moveTo(size.width * 0.48, size.height * 0.30)
      ..lineTo(size.width * 0.65, size.height * 0.20)
      ..lineTo(size.width * 0.88, size.height * 0.32)
      ..lineTo(size.width * 0.82, size.height * 0.65)
      ..lineTo(size.width * 0.62, size.height * 0.75)
      ..lineTo(size.width * 0.45, size.height * 0.58)
      ..close();

    final fillPaint2 = Paint()
      ..color = const Color(0xFF00E676).withValues(alpha: 0.32)
      ..style = PaintingStyle.fill;
    final strokePaint2 = Paint()
      ..color = const Color(0xFF00E676)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    canvas.drawPath(poly2, fillPaint2);
    canvas.drawPath(poly2, strokePaint2);

    // Glowing Runner Waypoint Pin
    final runnerPos = Offset(size.width * 0.82, size.height * 0.65);
    final glowPaint = Paint()
      ..color = const Color(0xFF2979FF).withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(runnerPos, 14, glowPaint);

    final dotPaint = Paint()
      ..color = const Color(0xFF2979FF)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(runnerPos, 6, dotPaint);

    final dotBorder = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(runnerPos, 6, dotBorder);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
