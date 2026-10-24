import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../ui/ui.dart';

/// Isolated, safety-critical 48 dp SOS Shield Button.
/// Requires a 1.5 s press-and-hold with a radial progress ring
/// before triggering emergency distress services.
class SosShieldButton extends StatefulWidget {
  final VoidCallback onTriggerSos;

  const SosShieldButton({
    super.key,
    required this.onTriggerSos,
  });

  @override
  State<SosShieldButton> createState() => _SosShieldButtonState();
}

class _SosShieldButtonState extends State<SosShieldButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _completed = false;
  DateTime? _holdStartTime;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && !_completed) {
          _completed = true;
          AppMotion.heavyBurst();
          widget.onTriggerSos();
          _controller.reset();
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent _) {
    _completed = false;
    _holdStartTime = DateTime.now();
    AppMotion.lightTick();
    _controller.forward();
  }

  void _onPointerUp(PointerUpEvent _) {
    _handleRelease();
  }

  void _onPointerCancel(PointerCancelEvent _) {
    _handleRelease();
  }

  void _handleRelease() {
    if (_completed) return;
    final heldDuration = _holdStartTime != null
        ? DateTime.now().difference(_holdStartTime!)
        : Duration.zero;

    _controller.reverse();

    if (heldDuration.inMilliseconds < 400 && mounted) {
      AppToast.show(
        context,
        'Hold 1.5s to trigger Emergency SOS',
        duration: const Duration(seconds: 2),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Emergency SOS. Hold 1.5 seconds to trigger distress beacon.',
      child: Tooltip(
        message: 'Emergency SOS (Hold 1.5s)',
        child: Listener(
          onPointerDown: _onPointerDown,
          onPointerUp: _onPointerUp,
          onPointerCancel: _onPointerCancel,
          behavior: HitTestBehavior.opaque,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final progress = _controller.value;
              final isPressing = progress > 0.0;
              final isReduced = AppMotion.isReducedMotion(context);
              final scale = (isPressing && !isReduced) ? 0.96 : 1.0;

              return Transform.scale(
                scale: scale,
                child: Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: isPressing
                        ? AppColors.error.withValues(alpha: 0.18)
                        : AppColors.surfaceGlass,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isPressing
                          ? AppColors.error
                          : AppColors.error.withValues(alpha: 0.4),
                      width: 1.2,
                    ),
                    boxShadow: AppElevation.floating,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (progress > 0.0)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _SosProgressPainter(progress: progress),
                          ),
                        ),
                      const Icon(
                        Icons.emergency_rounded,
                        color: AppColors.error,
                        size: 24,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SosProgressPainter extends CustomPainter {
  final double progress;

  _SosProgressPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0) return;
    final strokeWidth = 2.5;
    final radius = (size.width - strokeWidth) / 2;
    final center = Offset(size.width / 2, size.height / 2);

    final paint = Paint()
      ..color = AppColors.error
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _SosProgressPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
