import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import '../motion/motion.dart';

/// Full-screen startup animation overlay shown once per app launch session.
/// Traces a closed-loop route, fills territory, expands ripple, and reveals logo & brand.
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

    // Default duration, updated in didChangeDependencies if reduced motion
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
                  // Reduced motion: 700ms logo fade only
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
                          Opacity(opacity: logoOpacity, child: _buildLogo(72)),
                          const SizedBox(height: AppSpacing.s20),
                          Opacity(
                            opacity: logoOpacity,
                            child: Text(
                              'TERRITORY RUNNER',
                              style: AppText.headingLarge.copyWith(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2.5,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // 1. Scene fade out at end (0.88 -> 1.0)
                if (t >= 0.88) {
                  sceneOpacity = (1.0 - (t - 0.88) / 0.12).clamp(0.0, 1.0);
                }

                // 2. Loop trace (0.0 -> 0.40)
                final double loopProgress = (t / 0.40).clamp(0.0, 1.0);

                // 3. Fill and ripple (0.40 -> 0.65)
                final double fillProgress = ((t - 0.40) / 0.20).clamp(0.0, 1.0);
                final double rippleProgress = ((t - 0.42) / 0.25).clamp(
                  0.0,
                  1.0,
                );

                // 4. Logo scale & fade (0.50 -> 0.75)
                final double logoT = ((t - 0.50) / 0.25).clamp(0.0, 1.0);
                final double logoScale =
                    0.85 + (0.15 * Curves.easeOutBack.transform(logoT));
                final double logoOpacity = Curves.easeIn.transform(logoT);

                // 5. Title & Subtitle tightening (0.55 -> 0.82)
                final double textT = ((t - 0.55) / 0.27).clamp(0.0, 1.0);
                final double letterSpacing =
                    6.0 - (3.5 * Curves.easeOutCubic.transform(textT));
                final double textOpacity = textT;

                return Opacity(
                  opacity: sceneOpacity,
                  child: Container(
                    color: AppColors.bgDeep,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Closed loop trace and territory fill
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _IntroMapPainter(
                              loopProgress: loopProgress,
                              fillProgress: fillProgress,
                              rippleProgress: rippleProgress,
                            ),
                          ),
                        ),

                        // Center branding column
                        if (t >= 0.50)
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Transform.scale(
                                  scale: logoScale,
                                  child: Opacity(
                                    opacity: logoOpacity,
                                    child: _buildLogo(76),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.s24),
                                if (t >= 0.55) ...[
                                  Opacity(
                                    opacity: textOpacity,
                                    child: Text(
                                      'TERRITORY RUNNER',
                                      style: AppText.headingLarge.copyWith(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: letterSpacing,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.s8),
                                  Opacity(
                                    opacity: (textOpacity * 1.2).clamp(
                                      0.0,
                                      1.0,
                                    ),
                                    child: Text(
                                      'RUN • CLAIM • DEFEND',
                                      style: AppText.labelAccent.copyWith(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 3.2,
                                        color: AppColors.accent,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
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

  Widget _buildLogo(double size) {
    return Image.asset(
      'assets/icons/logo.png',
      width: size,
      height: size,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.accent.withValues(alpha: 0.6),
              width: 2.0,
            ),
          ),
          child: Icon(
            Icons.shield_rounded,
            size: size * 0.56,
            color: AppColors.accent,
          ),
        );
      },
    );
  }
}

/// CustomPainter that renders an irregular closed-loop run route,
/// fills it with translucent accent on loop closure, and expands a radar ripple.
class _IntroMapPainter extends CustomPainter {
  final double loopProgress;
  final double fillProgress;
  final double rippleProgress;

  _IntroMapPainter({
    required this.loopProgress,
    required this.fillProgress,
    required this.rippleProgress,
  });

  // Irregular closed loop route waypoints (normalized [0..1] within box)
  static const List<Offset> _waypoints = [
    Offset(0.50, 0.20),
    Offset(0.72, 0.28),
    Offset(0.82, 0.50),
    Offset(0.75, 0.72),
    Offset(0.56, 0.80),
    Offset(0.35, 0.76),
    Offset(0.20, 0.55),
    Offset(0.28, 0.32),
    Offset(0.50, 0.20),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final double boxSize = math.min(size.width, size.height) * 0.65;
    final Offset origin = Offset(
      (size.width - boxSize) / 2.0,
      (size.height - boxSize) / 2.0,
    );

    final List<Offset> points = _waypoints.map((pt) {
      return Offset(origin.dx + pt.dx * boxSize, origin.dy + pt.dy * boxSize);
    }).toList();

    // 1. Territory translucent fill when closed
    if (fillProgress > 0.0) {
      final fillPath = Path()..moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        fillPath.lineTo(points[i].dx, points[i].dy);
      }
      fillPath.close();

      final fillPaint = Paint()
        ..color = AppColors.accent.withValues(alpha: 0.16 * fillProgress)
        ..style = PaintingStyle.fill;
      canvas.drawPath(fillPath, fillPaint);
    }

    // 2. Ripple pulse expanding from centroid
    if (rippleProgress > 0.0 && rippleProgress < 1.0) {
      final Offset center = Offset(size.width / 2.0, size.height / 2.0);
      final double maxRadius = boxSize * 0.65;
      final double currentRadius =
          maxRadius * Curves.easeOutQuad.transform(rippleProgress);
      final double alpha = (1.0 - rippleProgress) * 0.45;

      final ripplePaint = Paint()
        ..color = AppColors.accent.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(center, currentRadius, ripplePaint);
    }

    // 3. Traced route polyline
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

      final routePaint = Paint()
        ..color = AppColors.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(tracePath, routePaint);

      // Runner dot at the head of the path
      if (loopProgress < 1.0) {
        canvas.drawCircle(
          currentHead,
          6.0,
          Paint()..color = AppColors.accent.withValues(alpha: 0.35),
        );
        canvas.drawCircle(currentHead, 4.0, Paint()..color = AppColors.accent);
        canvas.drawCircle(
          currentHead,
          2.0,
          Paint()..color = AppColors.textPrimary,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _IntroMapPainter oldDelegate) {
    return oldDelegate.loopProgress != loopProgress ||
        oldDelegate.fillProgress != fillProgress ||
        oldDelegate.rippleProgress != rippleProgress;
  }
}
