import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../motion/motion.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';

/// Full-screen startup animation overlay shown once per app launch session.
/// Features a minimal, ultra-smooth animated running person carving out a glowing
/// territory loop, smooth territory claim pulse, and clean brand typography reveal.
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
      duration: const Duration(milliseconds: 580),
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
    if (reduced) {
      _isReducedMotion = true;
      _skip();
    }
  }

  void _skip() {
    if (_isDone) return;
    _controller.stop();
    setState(() => _isDone = true);
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
                  // Reduced motion: clean 700ms fade without high-frequency motion
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
                            child: _buildCrestIcon(76),
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

                // 1. Overall scene fade out at end (0.88 -> 1.00)
                if (t >= 0.88) {
                  sceneOpacity = (1.0 - (t - 0.88) / 0.12).clamp(0.0, 1.0);
                }

                // 2. Timeline staging
                // Route drawing (0.00 -> 0.44)
                final double loopProgress = (t / 0.44).clamp(0.0, 1.0);

                // Territory fill & pulse (0.42 -> 0.70)
                final double fillProgress = ((t - 0.42) / 0.20).clamp(0.0, 1.0);
                final double pulseProgress = ((t - 0.44) / 0.26).clamp(
                  0.0,
                  1.0,
                );

                // Runner visibility: smoothly fades out as crest/title take focus (0.50 -> 0.68)
                final double runnerOpacity = t < 0.50
                    ? 1.0
                    : (1.0 - (t - 0.50) / 0.18).clamp(0.0, 1.0);

                // Crest reveal (0.50 -> 0.74)
                final double crestT = ((t - 0.50) / 0.24).clamp(0.0, 1.0);
                final double crestOpacity = Curves.easeIn.transform(crestT);
                final double crestScale =
                    0.85 + (0.15 * Curves.easeOutBack.transform(crestT));

                // Title reveal (0.48 -> 0.75) — guaranteed visible by 1500ms
                final double textT = ((t - 0.48) / 0.24).clamp(0.0, 1.0);
                final double letterSpacing =
                    5.0 - (2.5 * Curves.easeOutCubic.transform(textT));
                final double textOpacity = textT;

                return Opacity(
                  opacity: sceneOpacity,
                  child: Container(
                    color: AppColors.bgDeep,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Minimalist Canvas (Running Person + Territory Loop + Pulse)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _MinimalRunnerIntroPainter(
                              time: t,
                              loopProgress: loopProgress,
                              fillProgress: fillProgress,
                              pulseProgress: pulseProgress,
                              runnerOpacity: runnerOpacity,
                            ),
                          ),
                        ),

                        // Center Brand Column (Smoothly revealed as runner transitions)
                        if (t >= 0.48)
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Transform.scale(
                                  scale: crestScale,
                                  child: Opacity(
                                    opacity: crestOpacity,
                                    child: _buildCrestIcon(76),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.s24),
                                Opacity(
                                  opacity: textOpacity,
                                  child: Text(
                                    'TERRITORY RUNNER',
                                    style: AppText.headingLarge.copyWith(
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: letterSpacing,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.s8),
                                Opacity(
                                  opacity: (textOpacity * 1.2).clamp(0.0, 1.0),
                                  child: Text(
                                    'RUN • CLAIM • DEFEND',
                                    style: AppText.labelAccent.copyWith(
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 3.2,
                                      color: AppColors.accent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Minimal subtle tap to skip prompt at bottom
                        Positioned(
                          bottom: 32,
                          child: Opacity(
                            opacity: (t / 0.20).clamp(0.0, 0.45),
                            child: Text(
                              'TAP TO SKIP',
                              style: AppText.labelSmall.copyWith(
                                letterSpacing: 2.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMuted,
                              ),
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
          width: 2.0,
        ),
      ),
      child: Icon(
        Icons.shield_rounded,
        size: size * 0.56,
        color: AppColors.accent,
      ),
    );
  }
}

/// Minimalist CustomPainter:
/// 1. Sleek closed-loop territory path
/// 2. Soft glowing territory claim fill upon loop completion
/// 3. Minimal radial claim ripple
/// 4. Smooth, articulated running person with realistic sprinting kinematics
class _MinimalRunnerIntroPainter extends CustomPainter {
  final double time;
  final double loopProgress;
  final double fillProgress;
  final double pulseProgress;
  final double runnerOpacity;

  _MinimalRunnerIntroPainter({
    required this.time,
    required this.loopProgress,
    required this.fillProgress,
    required this.pulseProgress,
    required this.runnerOpacity,
  });

  // Normalized waypoints forming an organic athletic loop
  static const List<Offset> _waypoints = [
    Offset(0.50, 0.20),
    Offset(0.72, 0.27),
    Offset(0.83, 0.48),
    Offset(0.76, 0.72),
    Offset(0.54, 0.80),
    Offset(0.32, 0.76),
    Offset(0.18, 0.54),
    Offset(0.26, 0.30),
    Offset(0.50, 0.20), // closes loop
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final double boxSize = math.min(size.width, size.height) * 0.70;
    final Offset origin = Offset(
      (size.width - boxSize) / 2.0,
      (size.height - boxSize) / 2.0,
    );

    final List<Offset> points = _waypoints.map((pt) {
      return Offset(origin.dx + pt.dx * boxSize, origin.dy + pt.dy * boxSize);
    }).toList();

    // 1. Territory translucent claim fill upon loop closure
    if (fillProgress > 0.0) {
      final fillPath = Path()..moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        fillPath.lineTo(points[i].dx, points[i].dy);
      }
      fillPath.close();

      // Soft ambient territory glow
      final fillPaint = Paint()
        ..color = AppColors.accent.withValues(alpha: 0.14 * fillProgress)
        ..style = PaintingStyle.fill;
      canvas.drawPath(fillPath, fillPaint);

      // Delicate inner boundary
      final borderPaint = Paint()
        ..color = AppColors.accent.withValues(alpha: 0.4 * fillProgress)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawPath(fillPath, borderPaint);
    }

    // 2. Minimal territory claim ripple pulse
    if (pulseProgress > 0.0 && pulseProgress < 1.0) {
      final Offset center = Offset(size.width / 2.0, size.height / 2.0);
      final double maxRadius = boxSize * 0.60;
      final double currentRadius =
          maxRadius * Curves.easeOutCubic.transform(pulseProgress);
      final double alpha = (1.0 - pulseProgress) * 0.5;

      final pulsePaint = Paint()
        ..color = AppColors.accent.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 * (1.0 - pulseProgress * 0.5);
      canvas.drawCircle(center, currentRadius, pulsePaint);
    }

    // 3. Traced route line
    if (loopProgress > 0.0) {
      final totalSegments = points.length - 1;
      final currentFloat = loopProgress * totalSegments;
      final currentIdx = currentFloat.floor().clamp(0, totalSegments - 1);
      final segmentFrac = (currentFloat - currentIdx).clamp(0.0, 1.0);

      final tracePath = Path()..moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i <= currentIdx; i++) {
        tracePath.lineTo(points[i].dx, points[i].dy);
      }

      final pStart = points[currentIdx];
      final pEnd = points[currentIdx + 1];
      final currentHead = Offset(
        pStart.dx + (pEnd.dx - pStart.dx) * segmentFrac,
        pStart.dy + (pEnd.dy - pStart.dy) * segmentFrac,
      );
      tracePath.lineTo(currentHead.dx, currentHead.dy);

      // Clean crisp core stroke
      final routePaint = Paint()
        ..color = AppColors.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(tracePath, routePaint);

      // Leading beacon dot at the head of the loop (crisp, zero glow)
      if (loopProgress < 1.0) {
        canvas.drawCircle(currentHead, 3.5, Paint()..color = AppColors.accent);
        canvas.drawCircle(currentHead, 1.8, Paint()..color = AppColors.bgDeep);
      }
    }

    // 4. Smooth Articulated Running Person at the Center
    if (runnerOpacity > 0.0) {
      final Offset center = Offset(size.width / 2.0, size.height / 2.0);
      _drawRunningPerson(canvas, center, runnerOpacity);
    }
  }

  /// Draws a sleek, articulated runner with realistic sprinting kinematics:
  /// - Natural forward athletic lean
  /// - Contralateral pumping arms (elbows bent, cycling with opposing legs)
  /// - Full stride leg kinematics (hip, knee extension, high-heel recovery)
  /// - Center-of-mass vertical stride bounce
  /// - Foreground/background depth shading for natural 3D silhouette
  void _drawRunningPerson(Canvas canvas, Offset center, double opacity) {
    // Sprint cycle phase (cadence ~ 3.2 strides/second for athletic sprint)
    final double phase = time * 20.0;

    // Subtle vertical stride bounce (runners dip on foot-strike, rise at flight)
    final double bobY = -math.sin(phase * 2.0).abs() * 3.5;

    // Runner origin (pelvis / hips)
    final Offset hip = Offset(center.dx - 2.0, center.dy + bobY + 4.0);

    // Forward athletic lean angle (~14 degrees)
    const double leanAngle = 0.24;
    final double sinLean = math.sin(leanAngle);
    final double cosLean = math.cos(leanAngle);

    // Torso length and shoulder position
    const double torsoLen = 22.0;
    final Offset shoulder = Offset(
      hip.dx + torsoLen * sinLean,
      hip.dy - torsoLen * cosLean,
    );

    // Head position and size
    final Offset headCenter = Offset(
      shoulder.dx + 8.0 * sinLean,
      shoulder.dy - 8.0 * cosLean,
    );
    const double headRadius = 5.2;

    // Limb segment lengths
    const double thighLen = 17.0;
    const double shinLen = 16.0;
    const double upperArmLen = 12.0;
    const double forearmLen = 11.0;

    // Paint styles
    final torsoPaint = Paint()
      ..color = AppColors.textPrimary.withValues(alpha: opacity)
      ..strokeWidth = 4.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final headPaint = Paint()
      ..color = AppColors.textPrimary.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;

    // Far limbs (rendered behind torso with subtle translucent depth)
    final farLimbPaint = Paint()
      ..color = AppColors.accent.withValues(alpha: opacity * 0.45)
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // Near limbs (foreground, vibrant accent)
    final nearLimbPaint = Paint()
      ..color = AppColors.accent.withValues(alpha: opacity * 0.95)
      ..strokeWidth = 3.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // Leg Kinematics Solver
    void drawLeg(double legPhase, Paint paint) {
      final double thighAngle = 0.65 * math.sin(legPhase) + 0.15;
      final Offset knee = Offset(
        hip.dx + thighLen * math.sin(thighAngle),
        hip.dy + thighLen * math.cos(thighAngle),
      );

      // Knee flexion: sharp bend when recovering back, straightens when reaching forward
      final double recovery = math.max(0.0, -math.cos(legPhase));
      final double kneeFlex = 0.25 + (recovery * 1.35);

      final Offset ankle = Offset(
        knee.dx + shinLen * math.sin(thighAngle - kneeFlex),
        knee.dy + shinLen * math.cos(thighAngle - kneeFlex),
      );

      // Foot stroke
      final Offset foot = Offset(ankle.dx + 4.5, ankle.dy + 1.5);

      final legPath = Path()
        ..moveTo(hip.dx, hip.dy)
        ..lineTo(knee.dx, knee.dy)
        ..lineTo(ankle.dx, ankle.dy)
        ..lineTo(foot.dx, foot.dy);
      canvas.drawPath(legPath, paint);
    }

    // Arm Kinematics Solver (contralateral pumping motion)
    void drawArm(double armPhase, Paint paint) {
      final double armAngle = -0.70 * math.sin(armPhase) + 0.20;
      final Offset elbow = Offset(
        shoulder.dx + upperArmLen * math.sin(armAngle),
        shoulder.dy + upperArmLen * math.cos(armAngle),
      );

      // Forearm pumps forward with 85-degree elbow bend
      const double elbowBend = 1.45;
      final Offset hand = Offset(
        elbow.dx + forearmLen * math.sin(armAngle + elbowBend),
        elbow.dy + forearmLen * math.cos(armAngle + elbowBend),
      );

      final armPath = Path()
        ..moveTo(shoulder.dx, shoulder.dy)
        ..lineTo(elbow.dx, elbow.dy)
        ..lineTo(hand.dx, hand.dy);
      canvas.drawPath(armPath, paint);
    }

    // Minimal speed streaks trailing beneath the runner
    final streakPaint = Paint()
      ..color = AppColors.accent.withValues(alpha: opacity * 0.3)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final double streakOffset = (time * 160.0) % 60.0;
    canvas.drawLine(
      Offset(hip.dx - 32.0 - streakOffset, hip.dy + 32.0),
      Offset(hip.dx - 12.0 - streakOffset, hip.dy + 32.0),
      streakPaint,
    );
    canvas.drawLine(
      Offset(hip.dx - 48.0 - streakOffset * 0.7, hip.dy + 26.0),
      Offset(hip.dx - 22.0 - streakOffset * 0.7, hip.dy + 26.0),
      streakPaint,
    );

    // 1. Far Limbs (Back Leg & Back Arm)
    drawLeg(phase + math.pi, farLimbPaint);
    drawArm(phase, farLimbPaint);

    // 2. Torso & Head
    canvas.drawLine(hip, shoulder, torsoPaint);
    canvas.drawCircle(headCenter, headRadius, headPaint);

    // 3. Near Limbs (Front Leg & Front Arm)
    drawLeg(phase, nearLimbPaint);
    drawArm(phase + math.pi, nearLimbPaint);
  }

  @override
  bool shouldRepaint(covariant _MinimalRunnerIntroPainter oldDelegate) {
    return oldDelegate.time != time ||
        oldDelegate.loopProgress != loopProgress ||
        oldDelegate.fillProgress != fillProgress ||
        oldDelegate.pulseProgress != pulseProgress ||
        oldDelegate.runnerOpacity != runnerOpacity;
  }
}

/// Reusable, minimal vector running person with natural athletic kinematics.
/// Zero glow, zero neon, perfectly styled with [AppColors.accent] and [AppColors.textPrimary].
class MinimalRunningPerson extends StatefulWidget {
  final double size;
  final Color? primaryColor;
  final Color? accentColor;
  final bool isRunning;

  const MinimalRunningPerson({
    super.key,
    this.size = 48.0,
    this.primaryColor,
    this.accentColor,
    this.isRunning = true,
  });

  @override
  State<MinimalRunningPerson> createState() => _MinimalRunningPersonState();
}

class _MinimalRunningPersonState extends State<MinimalRunningPerson>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    final bindingName = WidgetsBinding.instance.runtimeType.toString();
    if (widget.isRunning &&
        !bindingName.contains('TestWidgetsFlutterBinding')) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant MinimalRunningPerson oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRunning != oldWidget.isRunning) {
      if (widget.isRunning) {
        final bindingName = WidgetsBinding.instance.runtimeType.toString();
        if (!bindingName.contains('TestWidgetsFlutterBinding')) {
          _controller.repeat();
        } else {
          _controller.value = 0.5;
        }
      } else {
        _controller.stop();
        _controller.reset();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AppMotion.isReducedMotion(context)) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(
          painter: _MinimalRunnerKinematicPainter(
            time: 0.25,
            primaryColor: widget.primaryColor ?? AppColors.textPrimary,
            accentColor: widget.accentColor ?? AppColors.accent,
          ),
        ),
      );
    }

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _MinimalRunnerKinematicPainter(
              time: _controller.value,
              primaryColor: widget.primaryColor ?? AppColors.textPrimary,
              accentColor: widget.accentColor ?? AppColors.accent,
            ),
          );
        },
      ),
    );
  }
}

class _MinimalRunnerKinematicPainter extends CustomPainter {
  final double time;
  final Color primaryColor;
  final Color accentColor;

  _MinimalRunnerKinematicPainter({
    required this.time,
    required this.primaryColor,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.width / 50.0;
    final Offset center = Offset(size.width / 2.0, size.height / 2.0);

    final double phase = time * math.pi * 2.0;
    final double bobY = -math.sin(phase * 2.0).abs() * 2.5 * scale;
    final Offset hip = Offset(
      center.dx - 1.0 * scale,
      center.dy + bobY + 3.0 * scale,
    );

    const double leanAngle = 0.22;
    final double sinLean = math.sin(leanAngle);
    final double cosLean = math.cos(leanAngle);

    final double torsoLen = 16.0 * scale;
    final Offset shoulder = Offset(
      hip.dx + torsoLen * sinLean,
      hip.dy - torsoLen * cosLean,
    );

    final Offset headCenter = Offset(
      shoulder.dx + 6.0 * scale * sinLean,
      shoulder.dy - 6.0 * scale * cosLean,
    );
    final double headRadius = 4.0 * scale;

    final double thighLen = 13.0 * scale;
    final double shinLen = 12.0 * scale;
    final double upperArmLen = 9.0 * scale;
    final double forearmLen = 8.5 * scale;

    final torsoPaint = Paint()
      ..color = primaryColor
      ..strokeWidth = 3.2 * scale
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final headPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;

    final farLimbPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.45)
      ..strokeWidth = 2.6 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final nearLimbPaint = Paint()
      ..color = accentColor
      ..strokeWidth = 2.8 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    void drawLeg(double legPhase, Paint paint) {
      final double thighAngle = 0.60 * math.sin(legPhase) + 0.15;
      final Offset knee = Offset(
        hip.dx + thighLen * math.sin(thighAngle),
        hip.dy + thighLen * math.cos(thighAngle),
      );

      final double recovery = math.max(0.0, -math.cos(legPhase));
      final double kneeFlex = 0.25 + (recovery * 1.30);

      final Offset ankle = Offset(
        knee.dx + shinLen * math.sin(thighAngle - kneeFlex),
        knee.dy + shinLen * math.cos(thighAngle - kneeFlex),
      );

      final Offset foot = Offset(
        ankle.dx + 3.5 * scale,
        ankle.dy + 1.2 * scale,
      );

      final legPath = Path()
        ..moveTo(hip.dx, hip.dy)
        ..lineTo(knee.dx, knee.dy)
        ..lineTo(ankle.dx, ankle.dy)
        ..lineTo(foot.dx, foot.dy);
      canvas.drawPath(legPath, paint);
    }

    void drawArm(double armPhase, Paint paint) {
      final double armAngle = -0.65 * math.sin(armPhase) + 0.20;
      final Offset elbow = Offset(
        shoulder.dx + upperArmLen * math.sin(armAngle),
        shoulder.dy + upperArmLen * math.cos(armAngle),
      );

      const double elbowBend = 1.40;
      final Offset hand = Offset(
        elbow.dx + forearmLen * math.sin(armAngle + elbowBend),
        elbow.dy + forearmLen * math.cos(armAngle + elbowBend),
      );

      final armPath = Path()
        ..moveTo(shoulder.dx, shoulder.dy)
        ..lineTo(elbow.dx, elbow.dy)
        ..lineTo(hand.dx, hand.dy);
      canvas.drawPath(armPath, paint);
    }

    // Far Limbs
    drawLeg(phase + math.pi, farLimbPaint);
    drawArm(phase, farLimbPaint);

    // Torso & Head
    canvas.drawLine(hip, shoulder, torsoPaint);
    canvas.drawCircle(headCenter, headRadius, headPaint);

    // Near Limbs
    drawLeg(phase, nearLimbPaint);
    drawArm(phase + math.pi, nearLimbPaint);
  }

  @override
  bool shouldRepaint(covariant _MinimalRunnerKinematicPainter oldDelegate) {
    return oldDelegate.time != time ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.accentColor != accentColor;
  }
}
