import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A compact, calm loading indicator for buttons, chips, and tight inline spaces.
///
/// Fully accessible with Semantics and respects reduced motion.
class InlineLoading extends StatefulWidget {
  final double size;
  final double strokeWidth;
  final Color? color;
  final String semanticsLabel;

  const InlineLoading({
    super.key,
    this.size = 18.0,
    this.strokeWidth = 2.0,
    this.color,
    this.semanticsLabel = 'Loading...',
  });

  @override
  State<InlineLoading> createState() => _InlineLoadingState();
}

class _InlineLoadingState extends State<InlineLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveColor = widget.color ??
        IconTheme.of(context).color ??
        AppColors.primary;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Semantics(
      label: widget.semanticsLabel,
      value: 'In progress',
      container: true,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: reduceMotion
            ? CustomPaint(
                painter: _StaticInlinePainter(
                  color: effectiveColor,
                  strokeWidth: widget.strokeWidth,
                ),
              )
            : AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _controller.value * 2 * math.pi,
                    child: CustomPaint(
                      painter: _SpinningInlinePainter(
                        color: effectiveColor,
                        strokeWidth: widget.strokeWidth,
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _SpinningInlinePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _SpinningInlinePainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Track circle
    canvas.drawCircle(center, radius, strokePaint);

    // Active arc (120 degrees)
    final arcPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 0.75,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _SpinningInlinePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}

class _StaticInlinePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _StaticInlinePainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final arcPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Static 180-degree calm arc for reduced-motion accessibility
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _StaticInlinePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}

