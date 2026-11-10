import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/loading_quotes_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import 'secondary_button.dart';

/// A branded, calm loading view with a breathing track loop painter,
/// rotating athletic facts/quotes, and a 10-second timeout recovery notice.
class AppLoadingView extends StatefulWidget {
  final String? label;
  final bool fullScreen;
  final VoidCallback? onRetry;
  final VoidCallback? onCancel;
  final Duration quoteRotationInterval;
  final Duration timeoutDuration;
  final double painterSize;

  const AppLoadingView({
    super.key,
    this.label,
    this.fullScreen = false,
    this.onRetry,
    this.onCancel,
    this.quoteRotationInterval = const Duration(seconds: 5),
    this.timeoutDuration = const Duration(seconds: 10),
    this.painterSize = 64.0,
  });

  /// Displays a modal loading overlay during a long asynchronous operation
  /// (e.g. data export, backup sync, season transition).
  static Future<T> showModal<T>({
    required BuildContext context,
    required Future<T> Function() task,
    String? label,
  }) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    var isDismissed = false;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: AppColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.br16,
            side: const BorderSide(color: AppColors.border, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s24,
              vertical: AppSpacing.s32,
            ),
            child: AppLoadingView(label: label, painterSize: 52),
          ),
        ),
      ),
    ).then((_) => isDismissed = true);

    try {
      final result = await task();
      if (!isDismissed && navigator.canPop()) {
        navigator.pop();
      }
      return result;
    } catch (e) {
      if (!isDismissed && navigator.canPop()) {
        navigator.pop();
      }
      rethrow;
    }
  }

  @override
  State<AppLoadingView> createState() => _AppLoadingViewState();
}

class _AppLoadingViewState extends State<AppLoadingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  Timer? _rotationTimer;
  Timer? _timeoutTimer;

  RunningQuote _currentQuote = LoadingQuotesService.instance.getQuote();
  bool _isTimedOut = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    // Asynchronously warm up the quotes dataset for subsequent rotations
    LoadingQuotesService.instance.loadQuotes();

    _startTimers();
  }

  void _startTimers() {
    _rotationTimer?.cancel();
    _timeoutTimer?.cancel();

    _rotationTimer = Timer.periodic(widget.quoteRotationInterval, (_) {
      if (!mounted) return;
      final reduceMotion = MediaQuery.of(context).disableAnimations;
      if (reduceMotion) {
        return; // Do not rotate when reduced motion is preferred
      }

      setState(() {
        _currentQuote = LoadingQuotesService.instance.getQuote();
      });
    });

    _timeoutTimer = Timer(widget.timeoutDuration, () {
      if (!mounted) return;
      setState(() {
        _isTimedOut = true;
      });
    });
  }

  @override
  void dispose() {
    _rotationTimer?.cancel();
    _timeoutTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    Widget content = Semantics(
      label: widget.label != null
          ? 'Loading: ${widget.label}'
          : 'Loading in progress',
      container: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Subtle Contour Loop Painter
          SizedBox(
            width: widget.painterSize,
            height: widget.painterSize,
            child: reduceMotion
                ? CustomPaint(
                    painter: _TrackLoopPainter(progress: 0.25, isStatic: true),
                  )
                : AnimatedBuilder(
                    animation: _animController,
                    builder: (context, _) {
                      return CustomPaint(
                        painter: _TrackLoopPainter(
                          progress: _animController.value,
                          isStatic: false,
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: AppSpacing.s16),

          // 2. Status Label (optional)
          if (widget.label != null) ...[
            Text(
              widget.label!,
              style: AppText.titleSmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s8),
          ],

          // 3. Rotating Quote (sequential fade out then fade in so quotes never overlap)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: AnimatedSwitcher(
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 350),
              transitionBuilder: (child, animation) {
                if (reduceMotion) return child;
                final fadeIn = CurvedAnimation(
                  parent: animation,
                  curve: const Interval(0.55, 1.0, curve: Curves.easeOut),
                );
                return FadeTransition(opacity: fadeIn, child: child);
              },
              child: Column(
                key: ValueKey<String>(_currentQuote.text),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '“${_currentQuote.text}”',
                    style: AppText.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                      height: 1.35,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    '— ${_currentQuote.author}',
                    style: AppText.caption.copyWith(
                      color: AppColors.textMuted,
                      letterSpacing: 0.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

          // 4. Timeout Recovery Note & Actions
          if (_isTimedOut) ...[
            const SizedBox(height: AppSpacing.s24),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s16,
                vertical: AppSpacing.s8,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: AppRadius.br8,
                border: Border.all(color: AppColors.border, width: 1),
              ),
              child: Column(
                children: [
                  Text(
                    'Taking longer than usual...',
                    style: AppText.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (widget.onRetry != null || widget.onCancel != null) ...[
                    const SizedBox(height: AppSpacing.s8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.onRetry != null)
                          SecondaryButton(
                            label: 'Retry',
                            isFullWidth: false,
                            onPressed: () {
                              setState(() {
                                _isTimedOut = false;
                              });
                              _startTimers();
                              widget.onRetry!();
                            },
                          ),
                        if (widget.onRetry != null && widget.onCancel != null)
                          const SizedBox(width: AppSpacing.s8),
                        if (widget.onCancel != null)
                          SecondaryButton(
                            label: 'Cancel',
                            isFullWidth: false,
                            onPressed: widget.onCancel!,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );

    if (widget.fullScreen) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.s32),
          child: content,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: content,
    );
  }
}

/// Custom painter rendering a calm athletic track contour loop.
class _TrackLoopPainter extends CustomPainter {
  final double progress;
  final bool isStatic;

  _TrackLoopPainter({required this.progress, required this.isStatic});

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.08;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        strokeWidth / 2,
        strokeWidth / 2,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      Radius.circular(size.width * 0.35),
    );

    // 1. Base track contour
    final trackPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawRRect(rrect, trackPaint);

    if (isStatic) {
      // Calm static indicator for reduced motion
      final staticArcPaint = Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawRRect(rrect, staticArcPaint);
      return;
    }

    // 2. Active traveling pulse around the perimeter
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;

    final metric = metrics.first;
    final totalLength = metric.length;
    final activeSegmentLength = totalLength * 0.28;

    final startDist = (progress * totalLength) % totalLength;
    final endDist = startDist + activeSegmentLength;

    final activePaint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 1.15
      ..strokeCap = StrokeCap.round;

    if (endDist <= totalLength) {
      final extractPath = metric.extractPath(startDist, endDist);
      canvas.drawPath(extractPath, activePaint);
    } else {
      final extract1 = metric.extractPath(startDist, totalLength);
      final extract2 = metric.extractPath(0, endDist - totalLength);
      canvas.drawPath(extract1, activePaint);
      canvas.drawPath(extract2, activePaint);
    }

    // 3. Subtle pulse runner dot at the leading head
    final headDist = endDist % totalLength;
    final tangent = metric.getTangentForOffset(headDist);
    if (tangent != null) {
      final dotPaint = Paint()
        ..color = AppColors.textPrimary
        ..style = PaintingStyle.fill;

      // Soft non-neon breathing radius
      final dotRadius =
          strokeWidth * 0.75 * (0.85 + 0.15 * math.sin(progress * 2 * math.pi));
      canvas.drawCircle(tangent.position, dotRadius, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TrackLoopPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.isStatic != isStatic;
}
