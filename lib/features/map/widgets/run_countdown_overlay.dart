import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../services/countdown_audio_service.dart';
import '../../../ui/ui.dart';

/// Full-screen 3-second athletic countdown overlay before active run tracking begins.
/// Driven by a single [AnimationController] with voice cues, beeps, ring animation,
/// and instant cancellation on tap. Strictly honors reduced motion.
class RunCountdownOverlay extends StatefulWidget {
  final VoidCallback onComplete;
  final VoidCallback onCancel;

  const RunCountdownOverlay({
    super.key,
    required this.onComplete,
    required this.onCancel,
  });

  @override
  State<RunCountdownOverlay> createState() => _RunCountdownOverlayState();
}

class _RunCountdownOverlayState extends State<RunCountdownOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int _currentSecond = 3;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _controller.addListener(_onTick);
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        CountdownAudioService().playGo();
        widget.onComplete();
      }
    });

    CountdownAudioService().playTick(3);
    _controller.forward();
  }

  void _onTick() {
    int second;
    if (_controller.value < 1.0 / 3.0) {
      second = 3;
    } else if (_controller.value < 2.0 / 3.0) {
      second = 2;
    } else {
      second = 1;
    }

    if (second != _currentSecond) {
      setState(() {
        _currentSecond = second;
      });
      CountdownAudioService().playTick(second);
    }
  }

  void _cancel() {
    _controller.stop();
    CountdownAudioService().stop();
    widget.onCancel();
  }

  @override
  void dispose() {
    _controller.removeListener(_onTick);
    _controller.dispose();
    CountdownAudioService().stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isReducedMotion = AppMotion.isReducedMotion(context);

    return RepaintBoundary(
      child: GestureDetector(
        onTap: _cancel,
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: AppColors.bgDeep.withValues(alpha: 0.92),
          alignment: Alignment.center,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final double secondProgress = (_controller.value * 3.0) % 1.0;
              final double scale = isReducedMotion
                  ? 1.0
                  : (1.20 - (secondProgress * 0.20)).clamp(1.0, 1.25);

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'GET READY',
                    style: AppText.labelAccent.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3.5,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s32),
                  SizedBox(
                    width: 180,
                    height: 180,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: const Size(180, 180),
                          painter: _CountdownRingPainter(
                            progress: _controller.value,
                            secondProgress: secondProgress,
                          ),
                        ),
                        Transform.scale(
                          scale: scale,
                          child: Text(
                            '$_currentSecond',
                            style: AppText.statHero.copyWith(
                              fontSize: 84,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s32),
                  Text(
                    'Tap anywhere to cancel',
                    style: AppText.bodySmall.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CountdownRingPainter extends CustomPainter {
  final double progress;
  final double secondProgress;

  const _CountdownRingPainter({
    required this.progress,
    required this.secondProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 16) / 2;

    // Background track ring
    final trackPaint = Paint()
      ..color = AppColors.surface2
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0;
    canvas.drawCircle(center, radius, trackPaint);

    // Active sweep arc for the 3-second cycle
    final activePaint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 6.0;

    final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      activePaint,
    );
  }

  @override
  bool shouldRepaint(_CountdownRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.secondProgress != secondProgress;
}
