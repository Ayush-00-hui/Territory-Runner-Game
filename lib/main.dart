import 'dart:math' as math;
import 'dart:ui' as ui;
import 'profile_page.dart';
import 'features/map/map_screen.dart';
import 'features/teams/run_club_modal.dart';
import 'models/territory.dart';
import 'models/runner_profile.dart';
import 'services/firebase_service.dart';

import 'package:flutter/material.dart';
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
  static const Color bgDeep = Color(0xFF090A0F); // Deep space background
  static const Color bgElevated = Color(0xFF14151F); // Elevated dark surface
  static const Color surface = Color(0xFF1C1D2A); // Glassmorphism base surface
  static const Color surface2 = Color(0xFF26283A); // Slightly lighter surface
  static const Color border = Color(0xFF3B3E52); // Subtle cyber borders
  static const Color textPrimary = Color(0xFFF8FAFC); // Crisp white text
  static const Color textSecondary = Color(0xFFA0AEC0); // Muted slate text
  static const Color textMuted = Color(0xFF718096); // Very muted text
  static const Color accent = Color(0xFF00F0FF); // Neon Cyan
  static const Color accentSecondary = Color(0xFF8A2BE2); // Electric Violet
  static const Color accentGlow = Color(0x3300F0FF); // Cyan glow
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
                color: AppColors.border.withValues(alpha: 0.65),
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
                Text(
                  'STARTING RUN',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.2,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Preview route',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 160,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      final raw = _controller.value;
                      final pathT = Curves.easeInOutCubic.transform(raw);
                      return LayoutBuilder(
                        builder: (context, c) {
                          final sz = Size(c.maxWidth, c.maxHeight);
                          final path = _runPreviewPath(sz);
                          final metrics = path.computeMetrics().toList();
                          if (metrics.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          final m = metrics.first;
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              CustomPaint(
                                size: sz,
                                painter: _DottedRoutePainter(
                                  path: path,
                                  progress: pathT,
                                  flowT: raw,
                                ),
                              ),
                              _runnerStack(m, pathT),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Tap outside to close',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
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

class _DottedRoutePainter extends CustomPainter {
  _DottedRoutePainter({
    required this.path,
    required this.progress,
    required this.flowT,
  });

  final Path path;
  final double progress;
  final double flowT;

  @override
  void paint(Canvas canvas, Size size) {
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;

    final metric = metrics.first;
    final pathLen = metric.length;
    final runnerD = progress * pathLen;

    final softGlow = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    final mainLine = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;

    final highlightLine = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.2
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawPath(path, softGlow);
    canvas.drawPath(path, highlightLine);
    canvas.drawPath(path, mainLine);

    const tailLength = 90.0;

    for (double d = 0; d < pathLen; d += 4.0) {
      final tan = metric.getTangentForOffset(d);
      if (tan == null) continue;

      final behind = runnerD - d;
      if (behind < 0 || behind > tailLength) continue;

      final t = behind / tailLength;
      final pulse = 0.5 + 0.5 * math.sin(flowT * math.pi * 2 - d * 0.03);

      final radius = (1 - t) * 5.5 + 0.8 + pulse * 0.4;
      final alpha = ((1 - t) * 0.30 + 0.04).clamp(0.0, 1.0);

      final tailPaint = Paint()
        ..color = Color.lerp(
          Colors.white.withValues(alpha: alpha * 0.55),
          AppColors.accent.withValues(alpha: alpha),
          0.82,
        )!
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      canvas.drawCircle(tan.position, radius, tailPaint);
    }

    final runnerTan = metric.getTangentForOffset(
      runnerD.clamp(0.0, pathLen),
    );

    if (runnerTan != null) {
      final pulse = 0.5 + 0.5 * math.sin(flowT * math.pi * 2);

      final outerGlow = Paint()
        ..color = AppColors.accent.withValues(alpha: 0.22 + pulse * 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);

      final midGlow = Paint()
        ..color = AppColors.accent.withValues(alpha: 0.75);

      final innerCore = Paint()
        ..color = Colors.white.withValues(alpha: 0.95);

      canvas.drawCircle(runnerTan.position, 16 + pulse * 3, outerGlow);
      canvas.drawCircle(runnerTan.position, 7 + pulse * 1.0, midGlow);
      canvas.drawCircle(runnerTan.position, 2.4, innerCore);
    }
  }

  @override
  bool shouldRepaint(covariant _DottedRoutePainter oldDelegate) =>
      oldDelegate.path != path ||
      oldDelegate.progress != progress ||
      oldDelegate.flowT != flowT;
}



class TerritoryApp extends StatelessWidget {
  const TerritoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Territory Runner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.bgDeep,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.accent,
          secondary: AppColors.accentSecondary,
          surface: AppColors.surface,
          onSurface: AppColors.textPrimary,
        ),
        textTheme: ThemeData.dark().textTheme.apply(
              bodyColor: Colors.white,
              displayColor: Colors.white,
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
    duration: const Duration(milliseconds: 450),
    transitionBuilder: (child, animation) {
      return FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.08, 0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      );
    },
    child: KeyedSubtree(
      key: ValueKey(_selectedIndex),
      child: _pages[_selectedIndex],
    ),
  ),
  bottomNavigationBar: NavigationBar(
    selectedIndex: _selectedIndex,
    onDestinationSelected: (index) {
      setState(() {
        _selectedIndex = index;
      });
    },
    destinations: const [
      NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home_rounded),
        label: 'Home',
      ),
      NavigationDestination(
        icon: Icon(Icons.map_outlined),
        selectedIcon: Icon(Icons.map_rounded),
        label: 'Map',
      ),
      NavigationDestination(
        icon: Icon(Icons.person_outline_rounded),
        selectedIcon: Icon(Icons.person_rounded),
        label: 'Profile',
      ),
    ],
  ),
);
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: Stack(
        children: [
          Positioned(
            top: -120,
            right: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accentGlow,
              ),
            ),
          ),
          Positioned(
            top: 180,
            left: -100,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withValues(alpha: 0.06),
              ),
            ),
          ),
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24, topPad + 8, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _LogoMark(),
                          const Spacer(),
                          _PillBadge(
                            icon: Icons.bolt_rounded,
                            label: 'RUN CLUB',
                            onTap: () => RunClubModal.show(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 36),
                      Text(
                        'GOOD TO GO',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2.4,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Own your\nterritory.',
                        style: TextStyle(
                          fontSize: 42,
                          height: 0.98,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.8,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Track runs, claim blocks, and keep the streak alive — '
                        'minimal noise, maximum momentum.',
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.55,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 32),
                      const _SessionMetricsCard(),
                      const SizedBox(height: 28),
                      Text(
                        'THIS WEEK',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2.2,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const _StatsRow(),
                      const SizedBox(height: 36),
                      _StartRunButton(
                        onPressed: () => showRunStartAnimation(context),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.14),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () {},
                          child: const Text(
                            'View territory map',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      Text(
                        'TODAY',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2.2,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const _TodayGoalCard(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LogoMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Image.asset(
          'assets/icons/logo.png',
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const Icon(
            Icons.directions_run_rounded,
            color: AppColors.accent,
            size: 26,
          ),
        ),
      ),
    );
  }
}

class _PillBadge extends StatelessWidget {
  const _PillBadge({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: AppColors.accent),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Distance, duration, calories — hero session card (NRC-style metrics strip).
class _SessionMetricsCard extends StatelessWidget {
  const _SessionMetricsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.65)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'LAST RUN',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                  color: AppColors.textMuted,
                ),
              ),
              Text(
                'No activity',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: const [
              Expanded(
                child: _MetricCell(
                  label: 'Distance',
                  value: '0',
                  unit: 'km',
                ),
              ),
              _MetricDivider(),
              Expanded(
                child: _MetricCell(
                  label: 'Time',
                  value: '0',
                  unit: 'min',
                ),
              ),
              _MetricDivider(),
              Expanded(
                child: _MetricCell(
                  label: 'Calories',
                  value: '0',
                  unit: 'kcal',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricDivider extends StatelessWidget {
  const _MetricDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 52,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: AppColors.border.withValues(alpha: 0.5),
    );
  }
}

class _MetricCell extends StatelessWidget {
  const _MetricCell({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.4,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 28,
                height: 1,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              unit,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MiniStatTile(title: 'Territories', value: '0'),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniStatTile(title: 'Weekly km', value: '0'),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniStatTile(title: 'Rank', value: '#0'),
        ),
      ],
    );
  }
}

class _MiniStatTile extends StatelessWidget {
  const _MiniStatTile({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _StartRunButton extends StatefulWidget {
  const _StartRunButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_StartRunButton> createState() => _StartRunButtonState();
}

class _StartRunButtonState extends State<_StartRunButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 240),
    );
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: AnimatedBuilder(
        animation: _press,
        builder: (context, child) {
          final t = Curves.easeOutCubic.transform(_press.value);
          final scale = ui.lerpDouble(1.0, 0.97, t)!;
          final blur = ui.lerpDouble(20, 8, t)!;
          final offsetY = ui.lerpDouble(12, 4, t)!;
          final alpha = ui.lerpDouble(0.42, 0.16, t)!;
          final spread = ui.lerpDouble(-0.5, 0, t)!;

          return Transform.scale(
            scale: scale,
            alignment: Alignment.center,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: alpha),
                    blurRadius: blur,
                    spreadRadius: spread,
                    offset: Offset(0, offsetY),
                  ),
                ],
              ),
              child: child,
            ),
          );
        },
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTapDown: (_) => _press.forward(),
            onTapCancel: () => _press.reverse(),
            onTap: () {
              _press.reverse();
              widget.onPressed();
            },
            borderRadius: BorderRadius.circular(16),
            splashColor: Colors.white.withValues(alpha: 0.14),
            highlightColor: Colors.white.withValues(alpha: 0.06),
            child: const SizedBox(
              height: 58,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.play_arrow_rounded, size: 28, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'START RUN',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.6,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TodayGoalCard extends StatelessWidget {
  const _TodayGoalCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.flag_rounded,
              color: AppColors.accent,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Daily goal',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '0 km — start a run to log distance and claim your first block.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textMuted,
            size: 28,
          ),
        ],
      ),
    );
  }
}

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(
            child: _PlaceholderMapCanvas(),
          ),
          Positioned(
            top: pad.top + 12,
            left: 20,
            right: 20,
            child: Row(
              children: [
                Text(
                  'MAP',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.4,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const Spacer(),
                _MapIconButton(
                  icon: Icons.my_location_rounded,
                  onPressed: () {},
                ),
                const SizedBox(width: 10),
                _MapIconButton(
                  icon: Icons.layers_rounded,
                  onPressed: () {},
                ),
              ],
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: pad.bottom + 24,
            child: _MapBottomSheet(
              onStartRun: () => showRunStartAnimation(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapIconButton extends StatelessWidget {
  const _MapIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(icon, size: 22, color: Colors.white),
        ),
      ),
    );
  }
}

/// Stylized dark “map” — blocks, roads, and a glowing red route (no tiles).
class _PlaceholderMapCanvas extends StatelessWidget {
  const _PlaceholderMapCanvas();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MapPlaceholderPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _MapPlaceholderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFF0C0C0E);
    canvas.drawRect(Offset.zero & size, bg);

    final blockPaint = Paint()..color = const Color(0xFF121215);
    final blockBorder = Paint()
      ..color = const Color(0xFF1E1E22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    const cell = 56.0;
    for (double y = -cell; y < size.height + cell; y += cell) {
      for (double x = -cell; x < size.width + cell; x += cell) {
        final int hash = ((x.toInt() * 73856093) ^ (y.toInt() * 19349663)).abs();
        if ((hash % 100) > 42) {
          final r = RRect.fromRectAndRadius(
            Rect.fromLTWH(x + 2, y + 2, cell - 4, cell - 4),
            const Radius.circular(6),
          );
          canvas.drawRRect(r, blockPaint);
          canvas.drawRRect(r, blockBorder);
        }
      }
    }

    final roadPaint = Paint()
      ..color = const Color(0xFF252529)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    for (var i = 0.0; i < size.width; i += 88) {
      canvas.drawLine(Offset(i, 0), Offset(i + 40, size.height), roadPaint);
    }
    for (var j = 0.0; j < size.height; j += 72) {
      canvas.drawLine(Offset(0, j), Offset(size.width, j + 24), roadPaint);
    }

    final path = Path();
    path.moveTo(size.width * 0.18, size.height * 0.72);
    path.cubicTo(
      size.width * 0.32,
      size.height * 0.62,
      size.width * 0.38,
      size.height * 0.38,
      size.width * 0.52,
      size.height * 0.32,
    );
    path.cubicTo(
      size.width * 0.68,
      size.height * 0.26,
      size.width * 0.78,
      size.height * 0.42,
      size.width * 0.82,
      size.height * 0.28,
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.accent.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );

    final dot = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(size.width * 0.18, size.height * 0.72), 6, dot);
    canvas.drawCircle(Offset(size.width * 0.82, size.height * 0.28), 6, dot);
    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.28),
      12,
      Paint()
        ..color = AppColors.accent.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    final vignette = ui.Gradient.radial(
      Offset(size.width * 0.5, size.height * 0.45),
      size.shortestSide * 0.85,
      [
        Colors.transparent,
        Colors.black.withValues(alpha: 0.55),
      ],
      [0.45, 1],
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = vignette,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MapBottomSheet extends StatelessWidget {
  const _MapBottomSheet({required this.onStartRun});

  final VoidCallback onStartRun;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.65)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 32,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Territory outline',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              Text(
                'Live preview',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Row(
            children: [
              Expanded(
                child: _MapMetric(label: 'Area', value: '0 km²'),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _MapMetric(label: 'Blocks', value: '0'),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _MapMetric(label: 'Streak', value: '0 d'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: onStartRun,
              child: const Text(
                'START RUN',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapMetric extends StatelessWidget {
  const _MapMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.1,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

