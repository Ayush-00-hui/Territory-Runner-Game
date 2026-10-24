import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../ui/ui.dart';

/// Isolated, safety-critical 48 dp SOS Button (R1).
/// Features an unmistakable shield with bold "SOS" typography,
/// a visible 1.5 s radial progress ring, milestone haptic ticks,
/// and clear semantic labels.
class SosShieldButton extends StatefulWidget {
  final VoidCallback onTriggerSos;

  const SosShieldButton({super.key, required this.onTriggerSos});

  @override
  State<SosShieldButton> createState() => _SosShieldButtonState();
}

class _SosShieldButtonState extends State<SosShieldButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _completed = false;
  DateTime? _holdStartTime;
  int _lastTickMilestone = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )
      ..addListener(() {
        final progress = _controller.value;
        if (progress >= 0.75 && _lastTickMilestone < 3) {
          _lastTickMilestone = 3;
          AppMotion.lightTick();
        } else if (progress >= 0.50 && _lastTickMilestone < 2) {
          _lastTickMilestone = 2;
          AppMotion.lightTick();
        } else if (progress >= 0.25 && _lastTickMilestone < 1) {
          _lastTickMilestone = 1;
          AppMotion.lightTick();
        }
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && !_completed) {
          _completed = true;
          AppMotion.heavyBurst();
          widget.onTriggerSos();
          _controller.reset();
          _lastTickMilestone = 0;
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
    _lastTickMilestone = 0;
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
    _lastTickMilestone = 0;

    if (heldDuration.inMilliseconds < 400 && mounted) {
      AppToast.show(
        context,
        'Hold 1.5s for Emergency SOS',
        duration: const Duration(seconds: 2),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Emergency SOS. Hold 1.5 seconds for emergency assistance.',
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
                        ? AppColors.error.withValues(alpha: 0.22)
                        : AppColors.surfaceGlass,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isPressing
                          ? AppColors.error
                          : AppColors.error.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                    boxShadow: AppElevation.floating,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Smooth radial progress ring filling during hold
                      if (progress > 0.0)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _SosProgressPainter(progress: progress),
                          ),
                        ),
                      // Unmistakable emergency shield with bold "SOS" lettering
                      Center(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            const Icon(
                              Icons.shield_rounded,
                              color: AppColors.error,
                              size: 30,
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                'SOS',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.6,
                                  fontFamily: AppText.fontFamily,
                                ),
                              ),
                            ),
                          ],
                        ),
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
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 4) / 2;

    final ringPaint = Paint()
      ..color = AppColors.error
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      ringPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _SosProgressPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
