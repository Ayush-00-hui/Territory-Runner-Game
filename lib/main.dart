import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'features/auth/auth_screen.dart';
import 'profile_page.dart';
import 'features/map/map_screen.dart';
import 'models/territory.dart';
import 'models/runner_profile.dart';
import 'services/firebase_service.dart';
import 'features/home/home_screen.dart';
import 'ui/ui.dart';
export 'ui/ui.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(TerritoryAdapter());
  Hive.registerAdapter(RunnerProfileAdapter());
  await Hive.openBox<Territory>('territories_v3');
  await Hive.openBox<RunnerProfile>('profile');
  await FirebaseService().initialize();
  runApp(const TerritoryApp());
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

class TerritoryApp extends StatefulWidget {
  const TerritoryApp({super.key});

  @override
  State<TerritoryApp> createState() => _TerritoryAppState();
}

class _TerritoryAppState extends State<TerritoryApp> {
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    final firebaseService = FirebaseService();
    if (firebaseService.isSignedIn) {
      _isAuthenticated = true;
    } else {
      final profileBox = Hive.box<RunnerProfile>('profile');
      final currentUser = profileBox.get('current_user');
      if (currentUser != null &&
          currentUser.username.isNotEmpty &&
          currentUser.username != 'CyberRunner' &&
          currentUser.username != 'local_runner') {
        _isAuthenticated = true;
      }
    }
  }

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
      home: _isAuthenticated
          ? const MainScreen()
          : AuthScreen(
              onAuthenticated: () {
                setState(() {
                  _isAuthenticated = true;
                });
              },
            ),
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

  late final List<Widget> _pages = [
    HomeScreen(
      onStartRun: () {
        setState(() {
          _selectedIndex = 1;
        });
      },
    ),
    const MapScreenFeature(),
    const ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        height: 60 + MediaQuery.paddingOf(context).bottom,
        decoration: BoxDecoration(
          color: AppColors.bgDeep,
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.bolt_rounded, 'HOME'),
                _buildNavItem(1, Icons.map_rounded, 'MAP'),
                _buildNavItem(2, Icons.person_rounded, 'PROFILE'),
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
        if (_selectedIndex != index) {
          AppMotion.lightTick();
          setState(() {
            _selectedIndex = index;
          });
        }
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16 : 12,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: AppSpacing.brFull,
          border: Border.all(
            color: isSelected ? AppColors.accent.withValues(alpha: 0.35) : Colors.transparent,
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? AppColors.accent : AppColors.textMuted,
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: AppText.label.copyWith(
                  color: AppColors.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
