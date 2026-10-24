import 'package:flutter/material.dart';

import '../../../ui/ui.dart';

/// Accidental-tap protected Hold-to-Finish button (R2).
/// When inactive: disabled and greyed with "Hold to finish", tapping shows hint "Start a run first".
/// When active: smooth ring fill on 1.4s press-and-hold with haptic milestones.
class HoldToFinishButton extends StatefulWidget {
  final bool isRunActive;
  final VoidCallback onFinish;

  const HoldToFinishButton({
    super.key,
    required this.isRunActive,
    required this.onFinish,
  });

  @override
  State<HoldToFinishButton> createState() => _HoldToFinishButtonState();
}

class _HoldToFinishButtonState extends State<HoldToFinishButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _holdController;
  bool _isHolding = false;
  int _lastTickMilestone = 0;

  @override
  void initState() {
    super.initState();
    _holdController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _holdController.addListener(() {
      final progress = _holdController.value;
      if (progress >= 0.66 && _lastTickMilestone < 2) {
        _lastTickMilestone = 2;
        AppMotion.lightTick();
      } else if (progress >= 0.33 && _lastTickMilestone < 1) {
        _lastTickMilestone = 1;
        AppMotion.lightTick();
      }
    });

    _holdController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        AppMotion.heavyBurst();
        widget.onFinish();
      }
    });
  }

  @override
  void dispose() {
    _holdController.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent _) {
    if (!widget.isRunActive) return;
    _lastTickMilestone = 0;
    AppMotion.mediumTick();
    setState(() {
      _isHolding = true;
    });
    _holdController.forward(from: 0.0);
  }

  void _onPointerUp(PointerUpEvent _) {
    if (_isHolding && _holdController.value < 1.0) {
      AppMotion.selectionTick();
    }
    _holdController.reset();
    _lastTickMilestone = 0;
    setState(() {
      _isHolding = false;
    });
  }

  void _onPointerCancel(PointerCancelEvent _) {
    if (_isHolding && _holdController.value < 1.0) {
      AppMotion.selectionTick();
    }
    _holdController.reset();
    _lastTickMilestone = 0;
    setState(() {
      _isHolding = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isRunActive) {
      return Semantics(
        button: true,
        enabled: false,
        label: 'Hold to finish. Disabled. Start a run first.',
        child: GestureDetector(
          onTap: () {
            AppMotion.lightTick();
            AppToast.show(
              context,
              'Start a run first',
              duration: const Duration(seconds: 2),
            );
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s10,
              vertical: AppSpacing.s12,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: AppSpacing.br16,
              border: Border.all(color: AppColors.borderSubtle, width: 1.0),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.stop_circle_outlined,
                  color: AppColors.textMuted,
                  size: 16,
                ),
                const SizedBox(width: AppSpacing.s4),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Hold to finish',
                      style: AppText.labelSmall.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Semantics(
      button: true,
      label: 'Hold 1.4 seconds to finish run',
      child: Listener(
        onPointerDown: _onPointerDown,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerCancel,
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _holdController,
          builder: (context, child) {
            final progress = _holdController.value;
            final isReducedMotion = AppMotion.shouldReduceMotion(context);

            return AnimatedScale(
              scale: (_isHolding && !isReducedMotion) ? 0.98 : 1.0,
              duration: AppMotion.fast,
              curve: AppMotion.easeOut,
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s10,
                  vertical: AppSpacing.s10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(
                    alpha: 0.12 + (progress * 0.35),
                  ),
                  borderRadius: AppSpacing.br16,
                  border: Border.all(
                    color: _isHolding
                        ? AppColors.error
                        : AppColors.error.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 2.5,
                            backgroundColor: AppColors.error.withValues(
                              alpha: 0.2,
                            ),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.error,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.stop_rounded,
                          color: AppColors.error,
                          size: 14,
                        ),
                      ],
                    ),
                    const SizedBox(width: AppSpacing.s6),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _isHolding ? 'Finishing...' : 'Hold to finish',
                          style: AppText.labelSmall.copyWith(
                            color: AppColors.error,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
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
      ),
    );
  }
}
