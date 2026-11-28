import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'motion.dart';

/// Particle model for micro-sparkle celebration bursts.
class _CelebrationParticle {
  final double angle;
  final double distance;
  final double size;
  final Color color;
  final bool isStar;
  final double speedFactor;

  _CelebrationParticle({
    required this.angle,
    required this.distance,
    required this.size,
    required this.color,
    required this.isStar,
    required this.speedFactor,
  });
}

/// A delightful micro-celebration burst overlay widget that paints expanding
/// sonar shockwaves and twinkling star particles around a hero element.
/// Used for territory loop closure claims and run completion triumphs.
class CelebrationBurst extends StatefulWidget {
  final Widget child;
  final bool autoPlay;
  final Color primaryColor;
  final Color secondaryColor;
  final int particleCount;
  final VoidCallback? onCompleted;

  const CelebrationBurst({
    super.key,
    required this.child,
    this.autoPlay = true,
    this.primaryColor = AppColors.accent,
    this.secondaryColor = AppColors.gold,
    this.particleCount = 14,
    this.onCompleted,
  });

  @override
  State<CelebrationBurst> createState() => _CelebrationBurstState();
}

class _CelebrationBurstState extends State<CelebrationBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_CelebrationParticle> _particles;

  @override
  void initState() {
    super.initState();
    final random = math.Random();
    _particles = List.generate(widget.particleCount, (i) {
      final angle =
          (i * (2 * math.pi / widget.particleCount)) +
          (random.nextDouble() * 0.3 - 0.15);
      final dist = 42.0 + random.nextDouble() * 38.0;
      final size = 3.5 + random.nextDouble() * 4.0;
      final color = i.isEven ? widget.primaryColor : widget.secondaryColor;
      final isStar = i % 3 == 0;
      final speedFactor = 0.8 + random.nextDouble() * 0.4;
      return _CelebrationParticle(
        angle: angle,
        distance: dist,
        size: size,
        color: color,
        isStar: isStar,
        speedFactor: speedFactor,
      );
    });

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onCompleted?.call();
      }
    });

    if (widget.autoPlay) {
      _controller.forward();
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
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value;
        return CustomPaint(
          foregroundPainter: _CelebrationBurstPainter(
            progress: progress,
            particles: _particles,
            primaryColor: widget.primaryColor,
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _CelebrationBurstPainter extends CustomPainter {
  final double progress;
  final List<_CelebrationParticle> particles;
  final Color primaryColor;

  _CelebrationBurstPainter({
    required this.progress,
    required this.particles,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || progress >= 1.0) return;

    final center = Offset(size.width / 2, size.height / 2);

    // 1. Sonar Ring Expansion & Dissolve
    final ringProgress = Curves.easeOutCubic.transform(progress);
    final ringRadius = (size.width / 2 + 10) + (ringProgress * 32.0);
    final ringOpacity = (1.0 - ringProgress).clamp(0.0, 1.0);

    final ringPaint = Paint()
      ..color = primaryColor.withValues(alpha: ringOpacity * 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 * (1.0 - ringProgress * 0.5);

    canvas.drawCircle(center, ringRadius, ringPaint);

    // 2. Micro-Sparkle Particle Burst
    final particleProgress = Curves.easeOutQuad.transform(progress);
    final particleOpacity = (1.0 - Curves.easeIn.transform(progress)).clamp(
      0.0,
      1.0,
    );

    for (final p in particles) {
      final currentDist = p.distance * particleProgress * p.speedFactor;
      final dx = center.dx + math.cos(p.angle) * currentDist;
      final dy =
          center.dy +
          math.sin(p.angle) * currentDist +
          (progress * 8.0); // slight gravity drift
      final pt = Offset(dx, dy);

      final pPaint = Paint()
        ..color = p.color.withValues(alpha: particleOpacity)
        ..style = PaintingStyle.fill;

      if (p.isStar) {
        _drawFourPointStar(canvas, pt, p.size * (1.0 - progress * 0.3), pPaint);
      } else {
        canvas.drawCircle(pt, p.size * 0.5 * (1.0 - progress * 0.4), pPaint);
      }
    }
  }

  void _drawFourPointStar(
    Canvas canvas,
    Offset center,
    double radius,
    Paint paint,
  ) {
    final path = Path();
    final innerRadius = radius * 0.35;
    for (int i = 0; i < 8; i++) {
      final angle = (i * math.pi) / 4;
      final r = i.isEven ? radius : innerRadius;
      final x = center.dx + math.cos(angle) * r;
      final y = center.dy + math.sin(angle) * r;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CelebrationBurstPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
