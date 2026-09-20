import 'dart:math' as math;
import 'dart:ui' as ui;
import 'profile_page.dart';
import 'features/map/map_screen.dart';
import 'features/gameplay/territory_service.dart';
import 'models/territory.dart';
import 'models/runner_profile.dart';
import 'services/firebase_service.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(TerritoryAdapter());
  Hive.registerAdapter(RunnerProfileAdapter());
  await Hive.openBox<Territory>('territories_v2');
  await Hive.openBox<RunnerProfile>('profile');
  await FirebaseService().initialize();
  runApp(const TerritoryApp());
}

abstract final class AppColors {
  static const Color bgDeep = Color(0xFF0B0C10); // Matte carbon black
  static const Color bgElevated = Color(0xFF12141A); // Deep card surface
  static const Color surface = Color(0xFF16181F); // Premium athletic plate
  static const Color surface2 = Color(0xFF1E212B); // High-contrast pill/metric card
  static const Color border = Color(0x1FFFFFFF); // Subtle athletic border (12% white)
  static const Color textPrimary = Color(0xFFFFFFFF); // Crisp pure white text
  static const Color textSecondary = Color(0xFF94A3B8); // Muted athletic slate text
  static const Color textMuted = Color(0xFF64748B); // Low-emphasis text
  static const Color accent = Color(0xFF00E676); // Neon Emerald Green (matching reference)
  static const Color accentSecondary = Color(0xFFFF5722); // Solar Sprint Orange
  static const Color secondary = Color(0xFFFF5722); // Solar Orange alias
  static const Color accentGlow = Color(0x3300E676); // Neon glow
  static const Color positiveGreen = Color(0xFF00E676); // +XX% delta green chip
  static const Color actionRed = Color(0xFFFF3366); // Action Red
  static const Color cyanThruster = Color(0xFF00F0FF); // Cyan Thruster
  static const Color amberStreak = Color(0xFFFFB800); // Amber Streak
}

Path _runPreviewPath(Size size) {
  final p = Path();

  final start = Offset(size.width * 0.10, size.height * 0.68);
  final c1 = Offset(size.width * 0.28, size.height * 0.82);
  final mid1 = Offset(size.width * 0.42, size.height * 0.52);

  final c2 = Offset(size.width * 0.56, size.height * 0.28);
  final mid2 = Offset(size.width * 0.68, size.height * 0.60);

  final c3 = Offset(size.width * 0.80, size.height * 0.78);
  final end = Offset(size.width * 0.90, size.height * 0.40);

  p.moveTo(start.dx, start.dy);
  p.cubicTo(c1.dx, c1.dy, mid1.dx, mid1.dy, mid1.dx, mid1.dy);
  p.cubicTo(c2.dx, c2.dy, mid2.dx, mid2.dy, mid2.dx, mid2.dy);
  p.cubicTo(c3.dx, c3.dy, end.dx, end.dy, end.dx, end.dy);

  return p;
}

void showRunStartAnimation(BuildContext context) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.78),
    transitionDuration: const Duration(milliseconds: 300),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
          child: child,
        ),
      );
    },
    pageBuilder: (context, _, _) => const _RunStartOverlay(),
  );
}

class _RunStartOverlay extends StatefulWidget {
  const _RunStartOverlay();

  @override
  State<_RunStartOverlay> createState() => _RunStartOverlayState();
}

class _RunStartOverlayState extends State<_RunStartOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static ui.Tangent? _tangentAt(ui.PathMetric metric, double t) {
    final len = metric.length;
    if (len <= 0) return null;
    return metric.getTangentForOffset(t.clamp(0.0, 1.0) * len);
  }

  Widget _runnerStack(ui.PathMetric metric, double pathT) {
    const lags = [0.048, 0.032, 0.018];
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (var k = 3; k >= 0; k--)
          _runnerAt(metric, pathT, k == 0 ? 0.0 : lags[k - 1], k),
      ],
    );
  }

  Widget _runnerAt(ui.PathMetric metric, double pathT, double lag, int layer) {
    final t = (pathT - lag).clamp(0.0, 1.0);
    final tan = _tangentAt(metric, t);
    if (tan == null) return const SizedBox.shrink();

    final bob = math.sin(t * math.pi * 2 * 5) * 3.5;
    final angle = math.atan2(tan.vector.dy, tan.vector.dx);
    final opacity = layer == 0 ? 1.0 : [0.12, 0.22, 0.34][layer - 1];
    final size = layer == 0 ? 38.0 : 32.0 - layer * 2.0;

    return Positioned(
      left: tan.position.dx - size * 0.55,
      top: tan.position.dy - size * 0.6 + bob,
      child: Transform.rotate(
        angle: angle - math.pi / 2,
        child: Opacity(
          opacity: opacity,
          child: layer == 0
              ? Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                      child: Icon(
                        Icons.directions_run_rounded,
                        size: 44,
                        color: AppColors.accent.withValues(alpha: 0.45),
                      ),
                    ),
                    const Icon(
                      Icons.directions_run_rounded,
                      size: 38,
                      color: AppColors.accent,
                      shadows: [
                        Shadow(
                          color: AppColors.accent,
                          blurRadius: 14,
                        ),
                      ],
                    ),
                  ],
                )
              : Icon(
                  Icons.directions_run_rounded,
                  size: size,
                  color: AppColors.accent,
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 320,
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: AppColors.border,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 32,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'START CONQUEST',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.0,
                        color: AppColors.accent,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20, color: Colors.white70),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 150,
                  width: double.infinity,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      return CustomPaint(
                        painter: _RunOverlayTrackPainter(
                          progress: _controller.value,
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final size = constraints.biggest;
                            final path = _runPreviewPath(size);
                            final metrics = path.computeMetrics().toList();
                            if (metrics.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return _runnerStack(metrics.first, _controller.value);
                          },
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Acquiring GPS lock & starting sector capture...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Ready • Hit The Grid',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RunOverlayTrackPainter extends CustomPainter {
  _RunOverlayTrackPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _runPreviewPath(size);

    final bgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, bgPaint);

    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final m = metrics.first;
    final len = m.length;
    final head = progress.clamp(0.0, 1.0) * len;
    final tail = (head - 72).clamp(0.0, len);

    if (head > tail) {
      final seg = m.extractPath(tail, head);
      final trailPaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(size.width * 0.1, size.height * 0.5),
          Offset(size.width * 0.9, size.height * 0.5),
          [
            AppColors.accent.withValues(alpha: 0.15),
            AppColors.accent,
          ],
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(seg, trailPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RunOverlayTrackPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class TerritoryApp extends StatelessWidget {
  const TerritoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Territory Runner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.bgDeep,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.accent,
          secondary: AppColors.accentSecondary,
          surface: AppColors.surface,
        ),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const HomeScreen(),
    const MapScreenFeature(),
    const ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: KeyedSubtree(
          key: ValueKey(_selectedIndex),
          child: _pages[_selectedIndex],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.bgDeep,
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.home_rounded, 'Home'),
                _buildNavItem(1, Icons.explore_rounded, 'Explore'),
                _buildNavItem(2, Icons.person_rounded, 'Profile'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 24,
            color: isSelected ? AppColors.accent : AppColors.textMuted,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
              color: isSelected ? Colors.white : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Home Screen - Implements Right Screen from user reference image with precision
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

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
    final territoriesCount = territoryService.getCapturedTerritories().length;
    final totalAreaSqKm = (territoriesCount * 0.015047).clamp(0.0, 999.0);

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
                // Level 6 Crown Badge Capsule
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
                        'Run 12 km to Lvl ${profile.level + 1}',
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
              onTap: () {
                // Navigate to Map / Explore tab
                final mainState = context.findAncestorStateOfType<_MainScreenState>();
                mainState?.setState(() {
                  mainState._selectedIndex = 1;
                });
              },
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
                    // Mock Vector Polygon Map Graphic
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _TerritoryHeroMapPainter(),
                      ),
                    ),

                    // Top Left Territory Stats Overlay
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
                            totalAreaSqKm > 0 ? '${totalAreaSqKm.toStringAsFixed(1)} km²' : '12.4 km²',
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
                              '↗ +23% this month',
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

            // --- "NEW AREA UNLOCKED!" BANNER ---
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
                          'New area unlocked!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Riverside South Sector',
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
                // Week | Month | Year Pill Toggle
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
                    value: '${(profile.totalDistanceKm / 4).round().clamp(1, 99)}',
                    delta: '+33%',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStatTile(
                    title: 'Distance',
                    icon: Icons.location_on_rounded,
                    value: '${profile.totalDistanceKm.toStringAsFixed(1)} km',
                    delta: '+21%',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStatTile(
                    title: 'Territory',
                    icon: Icons.map_rounded,
                    value: totalAreaSqKm > 0 ? '${totalAreaSqKm.toStringAsFixed(1)} km²' : '12.4 km²',
                    delta: '+40%',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStatTile(
                    title: 'Calories',
                    icon: Icons.local_fire_department_rounded,
                    value: '${(profile.totalDistanceKm * 65).round().clamp(150, 99999)}',
                    delta: '+18%',
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

            // --- INTERACTIVE QUICK-LOG HYDRATION TRACKER ---
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

            // --- INSPIRATION STORY BANNER ("Bigger routes. Bolder stories.") ---
            Container(
              height: 100,
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF1E2638),
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
