import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../motion/motion.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';

/// Full-screen cinematic startup animation overlay shown once per app launch session.
/// Features a 3D perspective terrain grid, kinetic neon runner light-cycle trajectory,
/// volumetric territory capture beacon, expanding 3D shockwaves, rotating wireframe
/// holographic crest, and high-tech cyber HUD telemetry.
class AppIntroGate extends StatefulWidget {
  final Widget child;

  const AppIntroGate({super.key, required this.child});

  static bool _hasPlayedThisLaunch = false;

  /// Resets session memory for testing purposes.
  static void resetForTesting() {
    _hasPlayedThisLaunch = false;
  }

  @override
  State<AppIntroGate> createState() => _AppIntroGateState();
}

class _AppIntroGateState extends State<AppIntroGate>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _isDone = false;
  bool _isReducedMotion = false;

  // Interactive 3D camera pan offsets
  double _panYaw = 0.0;
  double _panPitch = 0.0;

  @override
  void initState() {
    super.initState();
    if (AppIntroGate._hasPlayedThisLaunch) {
      _isDone = true;
      _controller = AnimationController(vsync: this);
      return;
    }

    AppIntroGate._hasPlayedThisLaunch = true;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _isDone = true);
      }
    });

    _controller.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isDone) return;
    final reduced = AppMotion.isReducedMotion(context);
    if (reduced != _isReducedMotion) {
      _isReducedMotion = reduced;
      _controller.duration = _isReducedMotion
          ? const Duration(milliseconds: 700)
          : const Duration(milliseconds: 2600);
      if (!_controller.isAnimating && !_controller.isCompleted) {
        _controller.forward();
      }
    }
  }

  void _skip() {
    if (_isDone) return;
    _controller.stop();
    setState(() => _isDone = true);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_isDone || _isReducedMotion) return;
    setState(() {
      _panYaw = (_panYaw + details.delta.dx * 0.003).clamp(-0.45, 0.45);
      _panPitch = (_panPitch - details.delta.dy * 0.002).clamp(-0.25, 0.25);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_isDone || _isReducedMotion) return;
    setState(() {
      _panYaw = 0.0;
      _panPitch = 0.0;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isDone) {
      return widget.child;
    }

    return RepaintBoundary(
      child: GestureDetector(
        onTap: _skip,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            widget.child,
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final double t = _controller.value;
                double sceneOpacity = 1.0;

                if (_isReducedMotion) {
                  // Reduced motion: 700ms elegant fade without camera motion
                  if (t >= 0.70) {
                    sceneOpacity = (1.0 - (t - 0.70) / 0.30).clamp(0.0, 1.0);
                  }
                  final double logoOpacity = (t / 0.40).clamp(0.0, 1.0);

                  return Opacity(
                    opacity: sceneOpacity,
                    child: Container(
                      color: AppColors.bgDeep,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Opacity(
                            opacity: logoOpacity,
                            child: _buildCrestIcon(80),
                          ),
                          const SizedBox(height: AppSpacing.s20),
                          Opacity(
                            opacity: logoOpacity,
                            child: Text(
                              'TERRITORY RUNNER',
                              style: AppText.headingLarge.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2.5,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s8),
                          Opacity(
                            opacity: logoOpacity,
                            child: Text(
                              'RUN • CLAIM • DEFEND',
                              style: AppText.labelAccent.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 3.0,
                                color: AppColors.accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // 1. Scene fade out at end (0.88 -> 1.00)
                if (t >= 0.88) {
                  sceneOpacity = (1.0 - (t - 0.88) / 0.12).clamp(0.0, 1.0);
                }

                // 2. Timeline staging
                // Runner loop progress (0.00 -> 0.42)
                final double loopProgress = (t / 0.42).clamp(0.0, 1.0);

                // Territory fill & ground shockwave (0.38 -> 0.70)
                final double fillProgress = ((t - 0.38) / 0.22).clamp(0.0, 1.0);
                final double shockwaveProgress = ((t - 0.40) / 0.30).clamp(0.0, 1.0);

                // 3D Crest rotation & reveal (0.45 -> 0.85)
                final double crestProgress = ((t - 0.45) / 0.25).clamp(0.0, 1.0);

                // Title typography timing (0.50 -> 0.80)
                final double textT = ((t - 0.50) / 0.25).clamp(0.0, 1.0);
                final double letterSpacing =
                    5.5 - (3.0 * Curves.easeOutCubic.transform(textT));
                final double textOpacity = textT;

                return Opacity(
                  opacity: sceneOpacity,
                  child: Container(
                    color: AppColors.bgDeep,
                    child: Stack(
                      children: [
                        // Dynamic 3D Scene (Perspective terrain, kinetic runner trail,
                        // beacon shockwave, floating 3D crest)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _Cinematic3DIntroPainter(
                              time: t,
                              loopProgress: loopProgress,
                              fillProgress: fillProgress,
                              shockwaveProgress: shockwaveProgress,
                              crestProgress: crestProgress,
                              panYaw: _panYaw,
                              panPitch: _panPitch,
                            ),
                          ),
                        ),

                        // High-tech Cyber HUD telemetry overlay
                        Positioned.fill(
                          child: IgnorePointer(
                            child: _CyberHudOverlay(
                              time: t,
                              textOpacity: textOpacity,
                            ),
                          ),
                        ),

                        // Central Title & Tagline typography (Revealed at t >= 0.50)
                        if (t >= 0.50)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 110,
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Opacity(
                                    opacity: textOpacity,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.surface.withValues(
                                          alpha: 0.65 * textOpacity,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: AppColors.primary.withValues(
                                            alpha: 0.4 * textOpacity,
                                          ),
                                          width: 1.0,
                                        ),
                                      ),
                                      child: Text(
                                        'TERRITORY RUNNER',
                                        style: AppText.headingLarge.copyWith(
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: letterSpacing,
                                          color: AppColors.textPrimary,
                                          shadows: [
                                            Shadow(
                                              color: AppColors.primary
                                                  .withValues(alpha: 0.8),
                                              blurRadius: 16,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.s10),
                                  Opacity(
                                    opacity: (textOpacity * 1.2).clamp(0.0, 1.0),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 24,
                                          height: 1.5,
                                          color: AppColors.accent,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'RUN • CLAIM • DEFEND',
                                          style: AppText.labelAccent.copyWith(
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 3.2,
                                            color: AppColors.accent,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          width: 24,
                                          height: 1.5,
                                          color: AppColors.accent,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCrestIcon(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.8),
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.35),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Icon(
        Icons.shield_rounded,
        size: size * 0.58,
        color: AppColors.accent,
      ),
    );
  }
}

/// Cybernetic HUD overlay providing tactical telemetry, corner reticles,
/// coordinates, and satellite lock status.
class _CyberHudOverlay extends StatelessWidget {
  final double time;
  final double textOpacity;

  const _CyberHudOverlay({
    required this.time,
    required this.textOpacity,
  });

  @override
  Widget build(BuildContext context) {
    final double hudFade = (time / 0.15).clamp(0.0, 1.0);
    return Opacity(
      opacity: hudFade,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Stack(
            children: [
              // Top-left: GPS & Satellite Telemetry
              Align(
                alignment: Alignment.topLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accent.withValues(alpha: 0.8),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'GPS // 3D LOCK [ACTIVE]',
                          style: AppText.caption.copyWith(
                            fontSize: 10,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'LAT: 28.6139° N  LON: 77.2090° E',
                      style: AppText.caption.copyWith(
                        fontSize: 9,
                        letterSpacing: 1.2,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),

              // Top-right: Grid Sector & Engine Status
              Align(
                alignment: Alignment.topRight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'SECTOR // 0x4F',
                      style: AppText.caption.copyWith(
                        fontSize: 10,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'NEURAL MAPPER v2.4',
                      style: AppText.caption.copyWith(
                        fontSize: 9,
                        letterSpacing: 1.2,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom prompt: Tap to skip
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Opacity(
                    opacity: 0.7 + 0.3 * math.sin(time * 12.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.touch_app_outlined,
                          size: 14,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'TAP TO SKIP',
                          style: AppText.caption.copyWith(
                            fontSize: 10,
                            letterSpacing: 2.0,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Tactical Corner Reticles
              const Positioned.fill(
                child: CustomPaint(
                  painter: _HudCornerBracketsPainter(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Draws tactical viewfinder corner brackets
class _HudCornerBracketsPainter extends CustomPainter {
  const _HudCornerBracketsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    const double len = 16.0;

    // Top-Left
    canvas.drawLine(const Offset(0, 0), const Offset(len, 0), paint);
    canvas.drawLine(const Offset(0, 0), const Offset(0, len), paint);

    // Top-Right
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - len, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, len), paint);

    // Bottom-Left
    canvas.drawLine(Offset(0, size.height), Offset(len, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(0, size.height - len), paint);

    // Bottom-Right
    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width - len, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width, size.height - len),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 3D Vector utility with vector arithmetic and dot/cross operations
class _Vec3 {
  final double x, y, z;
  const _Vec3(this.x, this.y, this.z);

  _Vec3 operator +(_Vec3 o) => _Vec3(x + o.x, y + o.y, z + o.z);
  _Vec3 operator -(_Vec3 o) => _Vec3(x - o.x, y - o.y, z - o.z);
  _Vec3 operator *(double s) => _Vec3(x * s, y * s, z * s);

  double dot(_Vec3 o) => x * o.x + y * o.y + z * o.z;

  _Vec3 cross(_Vec3 o) => _Vec3(
        y * o.z - z * o.y,
        z * o.x - x * o.z,
        x * o.y - y * o.x,
      );

  double get length => math.sqrt(x * x + y * y + z * z);

  _Vec3 get normalized {
    final len = length;
    return len > 0.0001 ? _Vec3(x / len, y / len, z / len) : this;
  }
}

/// CustomPainter that renders the complete 3D scene:
/// - Perspective 3D terrain grid receding into horizon with sweeping radar pulse
/// - Kinetic runner neon light-cycle trail with 3D sparks
/// - Volumetric territory capture beacon & ground shockwave ripples
/// - Orbiting wireframe 3D crest with dynamic specular facets
class _Cinematic3DIntroPainter extends CustomPainter {
  final double time;
  final double loopProgress;
  final double fillProgress;
  final double shockwaveProgress;
  final double crestProgress;
  final double panYaw;
  final double panPitch;

  _Cinematic3DIntroPainter({
    required this.time,
    required this.loopProgress,
    required this.fillProgress,
    required this.shockwaveProgress,
    required this.crestProgress,
    required this.panYaw,
    required this.panPitch,
  });

  // 3D Closed-Loop Route Waypoints across the terrain
  static const List<_Vec3> _routePoints = [
    _Vec3(-1.4, 0.0, 2.0),
    _Vec3(-1.6, 0.08, 3.1),
    _Vec3(-1.0, 0.22, 4.3),
    _Vec3(0.2, 0.32, 4.7),
    _Vec3(1.3, 0.18, 4.0),
    _Vec3(1.6, 0.05, 2.8),
    _Vec3(1.1, 0.0, 1.7),
    _Vec3(0.1, 0.04, 1.4),
    _Vec3(-0.9, 0.0, 1.5),
    _Vec3(-1.4, 0.0, 2.0), // closes loop
  ];

  // Camera settings
  static const double _basePitch = 0.44; // ~25 degrees downward tilt
  static const double _camY = 2.2;
  static const double _camZ = -3.2;
  static const double _focalLength = 480.0;

  @override
  void paint(Canvas canvas, Size size) {
    final double horizonY = size.height * 0.42;

    // Camera parameters incorporating subtle idle breathing and user pan
    final double pitch = _basePitch + panPitch + (math.sin(time * 1.5) * 0.015);
    final double yaw = panYaw + (math.cos(time * 1.2) * 0.025);

    Offset? project(_Vec3 world) {
      // 1. Translate relative to camera
      double x = world.x;
      double y = world.y - _camY;
      double z = world.z - _camZ;

      // 2. Yaw rotation
      if (yaw != 0.0) {
        final cy = math.cos(yaw);
        final sy = math.sin(yaw);
        final nx = x * cy - z * sy;
        final nz = x * sy + z * cy;
        x = nx;
        z = nz;
      }

      // 3. Pitch rotation
      final cp = math.cos(pitch);
      final sp = math.sin(pitch);
      final yView = y * cp + z * sp;
      final zView = -y * sp + z * cp;

      if (zView <= 0.15) return null;

      final double scale = _focalLength / zView;
      final double sx = size.width * 0.5 + x * scale;
      final double sy = horizonY - (yView * scale) + (math.tan(pitch) * _focalLength);

      return Offset(sx, sy);
    }

    // 1. Cyberpunk Sky Gradient & Horizon Glow
    _drawHorizonGlow(canvas, size, horizonY);

    // 2. 3D Perspective Ground Terrain Grid
    _drawTerrainGrid(canvas, size, project, horizonY);

    // 3. Volumetric Territory Fill & Ground Shockwaves (t >= 0.38)
    _drawTerritoryCapture(canvas, size, project);

    // 4. Kinetic Runner Light Trail & Embers
    _drawRunnerTrail(canvas, size, project);

    // 5. 3D Rotating Holographic Crest (t >= 0.45)
    if (crestProgress > 0.0) {
      _draw3DHolographicCrest(canvas, size, project);
    }
  }

  void _drawHorizonGlow(Canvas canvas, Size size, double horizonY) {
    // Deep atmospheric gradient
    final bgRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final bgPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment(0.0, (horizonY / size.height) * 2.0 - 1.0),
        radius: 1.1,
        colors: [
          AppColors.primary.withValues(alpha: 0.18),
          AppColors.bgElevated.withValues(alpha: 0.05),
          Colors.transparent,
        ],
      ).createShader(bgRect);
    canvas.drawRect(bgRect, bgPaint);

    // Horizon glowing neon line
    final horizonPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          AppColors.primary.withValues(alpha: 0.45),
          AppColors.accent.withValues(alpha: 0.65),
          AppColors.primary.withValues(alpha: 0.45),
          Colors.transparent,
        ],
        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
      ).createShader(Rect.fromLTWH(0, horizonY - 2, size.width, 4))
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(0, horizonY), Offset(size.width, horizonY), horizonPaint);
  }

  void _drawTerrainGrid(
    Canvas canvas,
    Size size,
    Offset? Function(_Vec3) project,
    double horizonY,
  ) {
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Moving radar sweep pulse across Z depth
    final double radarZ = 0.5 + ((time * 1.8) % 1.0) * 6.5;

    // Lateral (depth) lines along Z
    for (double z = 0.8; z <= 7.2; z += 0.45) {
      final pLeft = project(_Vec3(-4.5, 0.0, z));
      final pRight = project(_Vec3(4.5, 0.0, z));

      if (pLeft != null && pRight != null) {
        // Distance attenuation near horizon
        final double depthFactor = (1.0 - (z / 7.5)).clamp(0.0, 1.0);
        final double radarProx = (1.0 - (z - radarZ).abs() / 0.8).clamp(0.0, 1.0);
        final double alpha = (0.08 * depthFactor + 0.35 * radarProx).clamp(0.0, 0.6);

        linePaint.color = radarProx > 0.3
            ? AppColors.primary.withValues(alpha: alpha)
            : AppColors.primary.withValues(alpha: alpha * 0.7);
        linePaint.strokeWidth = radarProx > 0.3 ? 1.4 : 0.8;

        canvas.drawLine(pLeft, pRight, linePaint);
      }
    }

    // Longitudinal (perspective) lines along X
    for (double x = -4.0; x <= 4.0; x += 0.8) {
      final pNear = project(_Vec3(x, 0.0, 0.8));
      final pFar = project(_Vec3(x, 0.0, 7.2));

      if (pNear != null && pFar != null) {
        final double centerProx = (1.0 - (x.abs() / 4.5)).clamp(0.0, 1.0);
        final double alpha = (0.12 * centerProx).clamp(0.02, 0.35);

        linePaint.color = AppColors.primary.withValues(alpha: alpha);
        linePaint.strokeWidth = 0.9;
        canvas.drawLine(pNear, pFar, linePaint);
      }
    }

    // Grid Node Data Blips at key intersections
    final blipPaint = Paint()..style = PaintingStyle.fill;
    final List<_Vec3> blips = [
      const _Vec3(-2.4, 0.0, 2.5),
      const _Vec3(2.4, 0.0, 3.2),
      const _Vec3(0.0, 0.0, 3.8),
      const _Vec3(-1.6, 0.0, 5.0),
      const _Vec3(1.6, 0.0, 5.5),
    ];
    for (final b in blips) {
      final pt = project(b);
      if (pt != null) {
        final double pulse = 0.5 + 0.5 * math.sin(time * 6.0 + b.x);
        blipPaint.color = AppColors.accent.withValues(alpha: 0.4 * pulse);
        canvas.drawCircle(pt, 2.5, blipPaint);
      }
    }
  }

  void _drawTerritoryCapture(
    Canvas canvas,
    Size size,
    Offset? Function(_Vec3) project,
  ) {
    if (fillProgress <= 0.0) return;

    // Centroid of the polygon
    _Vec3 sum = const _Vec3(0, 0, 0);
    final count = _routePoints.length - 1;
    for (int i = 0; i < count; i++) {
      sum = sum + _routePoints[i];
    }
    final centroid = sum * (1.0 / count);

    // 1. Enclosed Polygon Projection & Hex-Lattice Fill
    final polyPath = Path();
    bool first = true;
    for (final wp in _routePoints) {
      final pt = project(wp);
      if (pt != null) {
        if (first) {
          polyPath.moveTo(pt.dx, pt.dy);
          first = false;
        } else {
          polyPath.lineTo(pt.dx, pt.dy);
        }
      }
    }
    polyPath.close();

    // Glowing territory fill
    final fillPaint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.18 * fillProgress)
      ..style = PaintingStyle.fill;
    canvas.drawPath(polyPath, fillPaint);

    // Inner contour border
    final borderPaint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.7 * fillProgress)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawPath(polyPath, borderPaint);

    // 2. Volumetric Vertical Light Beacon from Centroid
    final pGround = project(_Vec3(centroid.x, 0.0, centroid.z));
    final pSky = project(_Vec3(centroid.x, 3.8 * fillProgress, centroid.z));

    if (pGround != null && pSky != null) {
      final beaconRect = Rect.fromPoints(
        Offset(pGround.dx - 12, pSky.dy),
        Offset(pGround.dx + 12, pGround.dy),
      );
      final beaconPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            AppColors.accent.withValues(alpha: 0.65 * fillProgress),
            AppColors.primary.withValues(alpha: 0.4 * fillProgress),
            Colors.transparent,
          ],
        ).createShader(beaconRect);

      canvas.drawRect(beaconRect, beaconPaint);

      // Core bright laser line
      final coreLaser = Paint()
        ..color = Colors.white.withValues(alpha: 0.85 * fillProgress)
        ..strokeWidth = 2.0;
      canvas.drawLine(pGround, pSky, coreLaser);

      // Impact flare on the ground
      final flarePaint = Paint()
        ..color = AppColors.accent.withValues(alpha: 0.5 * fillProgress)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pGround, 10.0 * fillProgress, flarePaint);
    }

    // 3. 3D Ground Shockwave Expanding Ellipses
    if (shockwaveProgress > 0.0 && shockwaveProgress < 1.0) {
      final double radius = 3.6 * Curves.easeOutQuad.transform(shockwaveProgress);
      final double alpha = (1.0 - shockwaveProgress).clamp(0.0, 1.0);

      final shockPath = Path();
      const int steps = 36;
      bool started = false;

      for (int i = 0; i <= steps; i++) {
        final double theta = (i / steps) * 2 * math.pi;
        final double px = centroid.x + radius * math.cos(theta);
        final double pz = centroid.z + radius * math.sin(theta);
        final pt = project(_Vec3(px, 0.0, pz));
        if (pt != null) {
          if (!started) {
            shockPath.moveTo(pt.dx, pt.dy);
            started = true;
          } else {
            shockPath.lineTo(pt.dx, pt.dy);
          }
        }
      }

      if (started) {
        shockPath.close();
        final shockPaint = Paint()
          ..color = AppColors.accent.withValues(alpha: 0.65 * alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 * alpha;
        canvas.drawPath(shockPath, shockPaint);
      }
    }
  }

  void _drawRunnerTrail(
    Canvas canvas,
    Size size,
    Offset? Function(_Vec3) project,
  ) {
    if (loopProgress <= 0.0) return;

    final totalSegments = _routePoints.length - 1;
    final currentFloat = loopProgress * totalSegments;
    final currentIdx = currentFloat.floor().clamp(0, totalSegments - 1);
    final segmentFrac = (currentFloat - currentIdx).clamp(0.0, 1.0);

    // Calculate current 3D runner head position
    final pStart = _routePoints[currentIdx];
    final pEnd = _routePoints[currentIdx + 1];
    final currentHead3D = pStart + (pEnd - pStart) * segmentFrac;

    // Draw the traced 3D route path
    final routePath = Path();
    bool started = false;

    for (int i = 0; i <= currentIdx; i++) {
      final pt = project(_routePoints[i]);
      if (pt != null) {
        if (!started) {
          routePath.moveTo(pt.dx, pt.dy);
          started = true;
        } else {
          routePath.lineTo(pt.dx, pt.dy);
        }
      }
    }

    final ptHead = project(currentHead3D);
    if (ptHead != null) {
      if (!started) {
        routePath.moveTo(ptHead.dx, ptHead.dy);
      } else {
        routePath.lineTo(ptHead.dx, ptHead.dy);
      }
    }

    // Outer Neon Glow Stroke
    final glowPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(routePath, glowPaint);

    // Core Accent Stroke
    final corePaint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(routePath, corePaint);

    // Inner Pure Energy White Core
    final innerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(routePath, innerPaint);

    // Runner Head Blazing Orb
    if (ptHead != null && loopProgress < 1.0) {
      // Corona
      canvas.drawCircle(
        ptHead,
        9.0,
        Paint()..color = AppColors.accent.withValues(alpha: 0.35),
      );
      // Bright core
      canvas.drawCircle(ptHead, 5.0, Paint()..color = AppColors.accent);
      // Specular hot spot
      canvas.drawCircle(ptHead, 2.5, Paint()..color = Colors.white);
    }

    // Kinetic Spark Particles trailing behind head
    if (loopProgress < 1.0) {
      final sparkPaint = Paint()..style = PaintingStyle.fill;
      for (int i = 1; i <= 14; i++) {
        final double sparkAge = (i / 14.0);
        final double trailFrac = (currentFloat - sparkAge * 1.8);
        if (trailFrac > 0) {
          final int sIdx = trailFrac.floor().clamp(0, totalSegments - 1);
          final double sFrac = (trailFrac - sIdx).clamp(0.0, 1.0);
          final pA = _routePoints[sIdx];
          final pB = _routePoints[sIdx + 1];
          final sparkBase = pA + (pB - pA) * sFrac;

          // Add jitter in 3D
          final double jitterX = math.sin(i * 47.0 + time * 10.0) * 0.08;
          final double jitterY = math.cos(i * 31.0 + time * 12.0) * 0.06;
          final sparkPt = project(
            _Vec3(sparkBase.x + jitterX, sparkBase.y + jitterY + 0.05, sparkBase.z),
          );

          if (sparkPt != null) {
            final double alpha = (1.0 - sparkAge) * 0.8;
            sparkPaint.color = i % 2 == 0
                ? AppColors.accent.withValues(alpha: alpha)
                : AppColors.primary.withValues(alpha: alpha);
            canvas.drawCircle(sparkPt, 2.2 * (1.0 - sparkAge), sparkPaint);
          }
        }
      }
    }
  }

  void _draw3DHolographicCrest(
    Canvas canvas,
    Size size,
    Offset? Function(_Vec3) project,
  ) {
    final double animT = Curves.easeOutBack.transform(crestProgress);
    final double scale = 0.85 * animT;

    // Crest 3D Center Position in world space (elevated above the territory)
    const center = _Vec3(0.0, 1.7, 3.2);

    // Continuous 3D rotation around Y and subtle pitch
    final double rotY = (time * 2.8) + (panYaw * 1.5);
    final double rotX = math.sin(time * 2.0) * 0.15 + (panPitch * 1.2);

    // 3D Prism / Diamond Shield Geometry
    final apexTop = _Vec3(0.0, 0.75 * scale, 0.0);
    final apexBottom = _Vec3(0.0, -0.75 * scale, 0.0);

    const int ringCount = 6;
    final List<_Vec3> ringVerts = [];
    for (int i = 0; i < ringCount; i++) {
      final double theta = (i / ringCount) * 2 * math.pi;
      final double r = 0.60 * scale;
      final double vx = r * math.cos(theta);
      final double vy = 0.08 * math.sin(theta * 2) * scale;
      final double vz = r * math.sin(theta);
      ringVerts.add(_Vec3(vx, vy, vz));
    }

    // Rotation transform helper
    _Vec3 transformVertex(_Vec3 v) {
      // Rotate around X
      final cx = math.cos(rotX);
      final sx = math.sin(rotX);
      final y1 = v.y * cx - v.z * sx;
      final z1 = v.y * sx + v.z * cx;

      // Rotate around Y
      final cy = math.cos(rotY);
      final sy = math.sin(rotY);
      final x2 = v.x * cy + z1 * sy;
      final z2 = -v.x * sy + z1 * cy;

      return center + _Vec3(x2, y1, z2);
    }

    final pTopWorld = transformVertex(apexTop);
    final pBottomWorld = transformVertex(apexBottom);
    final transformedRing = ringVerts.map(transformVertex).toList();

    // Draw Facets with lighting angle calculation
    final lightDir = const _Vec3(0.3, 0.9, -0.6).normalized;

    void drawTriangle(_Vec3 a, _Vec3 b, _Vec3 c) {
      final norm = (b - a).cross(c - a).normalized;
      final double diff = norm.dot(lightDir);

      final pA = project(a);
      final pB = project(b);
      final pC = project(c);

      if (pA != null && pB != null && pC != null) {
        final triPath = Path()
          ..moveTo(pA.dx, pA.dy)
          ..lineTo(pB.dx, pB.dy)
          ..lineTo(pC.dx, pC.dy)
          ..close();

        // Facet fill with specular shading
        final double intensity = (diff * 0.5 + 0.5).clamp(0.1, 1.0);
        final facetPaint = Paint()
          ..color = AppColors.primary.withValues(
            alpha: (0.12 + 0.28 * intensity) * crestProgress,
          )
          ..style = PaintingStyle.fill;
        canvas.drawPath(triPath, facetPaint);

        // Holographic Wireframe Edges
        final edgePaint = Paint()
          ..color = AppColors.accent.withValues(
            alpha: (0.35 + 0.55 * intensity) * crestProgress,
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2;
        canvas.drawPath(triPath, edgePaint);
      }
    }

    // Upper facets
    for (int i = 0; i < ringCount; i++) {
      final vCurrent = transformedRing[i];
      final vNext = transformedRing[(i + 1) % ringCount];
      drawTriangle(pTopWorld, vCurrent, vNext);
    }

    // Lower facets
    for (int i = 0; i < ringCount; i++) {
      final vCurrent = transformedRing[i];
      final vNext = transformedRing[(i + 1) % ringCount];
      drawTriangle(vCurrent, pBottomWorld, vNext);
    }

    // Glowing Central Energy Shield Core
    final pCenter = project(center);
    if (pCenter != null) {
      // Outer glow
      canvas.drawCircle(
        pCenter,
        28.0 * scale,
        Paint()
          ..color = AppColors.accent.withValues(
            alpha: 0.25 * crestProgress * (0.8 + 0.2 * math.sin(time * 10.0)),
          ),
      );

      // Diamond core glyph
      final diamondPath = Path();
      const double dSize = 14.0;
      diamondPath.moveTo(pCenter.dx, pCenter.dy - dSize * scale);
      diamondPath.lineTo(pCenter.dx + dSize * 0.7 * scale, pCenter.dy);
      diamondPath.lineTo(pCenter.dx, pCenter.dy + dSize * scale);
      diamondPath.lineTo(pCenter.dx - dSize * 0.7 * scale, pCenter.dy);
      diamondPath.close();

      canvas.drawPath(
        diamondPath,
        Paint()
          ..color = AppColors.accent.withValues(alpha: 0.85 * crestProgress)
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(
        diamondPath,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.9 * crestProgress)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _Cinematic3DIntroPainter oldDelegate) {
    return oldDelegate.time != time ||
        oldDelegate.loopProgress != loopProgress ||
        oldDelegate.fillProgress != fillProgress ||
        oldDelegate.shockwaveProgress != shockwaveProgress ||
        oldDelegate.crestProgress != crestProgress ||
        oldDelegate.panYaw != panYaw ||
        oldDelegate.panPitch != panPitch;
  }
}
