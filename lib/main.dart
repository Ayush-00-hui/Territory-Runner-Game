import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/auth/auth_screen.dart';
import 'profile_page.dart';
import 'features/map/map_screen.dart';
import 'models/territory.dart';
import 'models/runner_profile.dart';
import 'services/firebase_service.dart';
import 'services/notification_service.dart';
import 'features/home/home_screen.dart';
import 'ui/ui.dart';
export 'ui/ui.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(TerritoryAdapter());
  }
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(RunnerProfileAdapter());
  }
  await Hive.openBox<Territory>('territories_v3');
  await Hive.openBox<RunnerProfile>('profile');
  await Hive.openBox<String>('active_run_recovery');

  // Load package metadata
  unawaited(AppVersion.init());

  // Immediately render UI — zero splash screen blocking!
  runApp(const TerritoryApp());

  // Initialize Firebase and push notifications asynchronously in background
  _initServicesAsync();
}

void _initServicesAsync() async {
  try {
    await FirebaseService().initialize().timeout(const Duration(seconds: 3));
  } catch (e) {
    debugPrint('[main] Firebase init skipped/timed out: $e');
  }
  try {
    await NotificationService().initialize().timeout(const Duration(seconds: 3));
  } catch (e) {
    debugPrint('[main] NotificationService init skipped/timed out: $e');
  }
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
    barrierColor: AppColors.scrim,
    transitionDuration: AppMotion.sheet,
    transitionBuilder: (context, animation, _, child) {
      return AppMotion.sharedAxisTransition(
        context: context,
        animation: animation,
        child: child,
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
    final opacity = layer == 0 ? 1.0 : [0.15, 0.30, 0.50][layer - 1];
    final size = layer == 0 ? 38.0 : 32.0 - layer * 2.0;

    return Positioned(
      left: tan.position.dx - size * 0.55,
      top: tan.position.dy - size * 0.6 + bob,
      child: Transform.rotate(
        angle: angle - math.pi / 2,
        child: Opacity(
          opacity: opacity,
          child: Icon(
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
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.s24),
            padding: const EdgeInsets.fromLTRB(AppSpacing.s20, AppSpacing.s24, AppSpacing.s20, AppSpacing.s20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.br24,
              border: Border.all(color: AppColors.borderSubtle, width: 1.0),
              boxShadow: AppElevation.floating,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Start run',
                      style: AppText.labelSmall.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s12),
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
                const SizedBox(height: AppSpacing.s12),
                Text(
                  'Connecting to GPS & preparing your run...',
                  textAlign: TextAlign.center,
                  style: AppText.bodyMedium.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.s20),
                PrimaryButton(
                  label: 'Start run',
                  onPressed: () => Navigator.of(context).pop(),
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
      ..color = AppColors.borderSubtle
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
        ..color = AppColors.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
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
  bool _hasCompletedOnboarding = true;

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

    // Check onboarding completion for unauthenticated runners
    SharedPreferences.getInstance().then((prefs) {
      final completed = prefs.getBool(OnboardingScreen.prefsKeyCompleted) ?? false;
      if (mounted && !completed && !_isAuthenticated) {
        setState(() {
          _hasCompletedOnboarding = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget homeWidget;
    if (_isAuthenticated) {
      homeWidget = const MainScreen();
    } else if (!_hasCompletedOnboarding) {
      homeWidget = OnboardingScreen(
        onCompleted: () {
          setState(() {
            _hasCompletedOnboarding = true;
          });
        },
      );
    } else {
      homeWidget = AuthScreen(
        onAuthenticated: () {
          setState(() {
            _isAuthenticated = true;
          });
        },
      );
    }

    return MaterialApp(
      scaffoldMessengerKey: AppToast.messengerKey,
      title: 'Territory Runner',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: homeWidget,
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
  StreamSubscription<String>? _notificationSub;

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
  void initState() {
    super.initState();
    _notificationSub = NotificationService().onAttackedTerritoryTapped.listen((_) {
      if (mounted) {
        setState(() {
          _selectedIndex = 1;
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService().showPermissionPrimerIfNeeded(context);
    });
  }

  @override
  void dispose() {
    _notificationSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: _buildPremiumBottomNav(context),
    );
  }

  Widget _buildPremiumBottomNav(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Container(
      height: 64.0 + bottomPad,
      decoration: const BoxDecoration(
        color: AppColors.bgElevated,
        border: Border(
          top: BorderSide(color: AppColors.borderSubtle, width: 1.0),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Home Tab
              Expanded(
                child: _buildNavTab(
                  index: 0,
                  icon: Icons.bolt_rounded,
                  label: 'Home',
                ),
              ),

              // Prominent Centre Run Action Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
                child: Semantics(
                  button: true,
                  label: 'Start Run',
                  child: _CenterRunAction(
                    isSelected: _selectedIndex == 1,
                    onTap: () {
                      AppMotion.heavyBurst();
                      setState(() {
                        _selectedIndex = 1;
                      });
                    },
                  ),
                ),
              ),

              // Profile Tab
              Expanded(
                child: _buildNavTab(
                  index: 2,
                  icon: Icons.person_rounded,
                  label: 'Profile',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavTab({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final bool isSelected = _selectedIndex == index;

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: GestureDetector(
        onTap: () {
          if (_selectedIndex != index) {
            AppMotion.selectionTick();
            setState(() {
              _selectedIndex = index;
            });
          }
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: AppMotion.duration(context, AppMotion.fast),
          curve: AppMotion.easeOut,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s6),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accentContainer : Colors.transparent,
            borderRadius: AppRadius.brFull,
            border: Border.all(
              color: isSelected ? AppColors.accent.withValues(alpha: 0.3) : Colors.transparent,
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? AppColors.accent : AppColors.textMuted,
              ),
              const SizedBox(width: AppSpacing.s6),
              Text(
                label,
                style: AppText.labelSmall.copyWith(
                  color: isSelected ? AppColors.accent : AppColors.textMuted,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CenterRunAction extends StatefulWidget {
  final bool isSelected;
  final VoidCallback onTap;

  const _CenterRunAction({
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_CenterRunAction> createState() => _CenterRunActionState();
}

class _CenterRunActionState extends State<_CenterRunAction> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final scale = _isPressed ? AppMotion.pressScale : 1.0;

    return AnimatedScale(
      scale: scale,
      duration: AppMotion.duration(context, AppMotion.fast),
      curve: AppMotion.easeOut,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: AppRadius.brFull,
            border: Border.all(color: AppColors.accent, width: 1.0),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.directions_run_rounded,
                size: 22,
                color: AppColors.onAccent,
              ),
              const SizedBox(width: AppSpacing.s6),
              Text(
                'Run',
                style: AppText.button.copyWith(
                  color: AppColors.onAccent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
