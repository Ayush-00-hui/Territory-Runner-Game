import 'package:flutter/material.dart';
import '../../../ui/ui.dart';

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

  @override
  void initState() {
    super.initState();
    _holdController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

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
    AppMotion.mediumTick();
    setState(() {
      _isHolding = true;
    });
    _holdController.forward(from: 0.0);
  }

  void _onPointerUp(PointerUpEvent _) {
    _holdController.reset();
    setState(() {
      _isHolding = false;
    });
  }

  void _onPointerCancel(PointerCancelEvent _) {
    _holdController.reset();
    setState(() {
      _isHolding = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isRunActive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s12),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: AppSpacing.br16,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline_rounded, color: Colors.white38, size: 16),
            const SizedBox(width: AppSpacing.s4),
            Text(
              'LOCKED',
              style: AppText.label.copyWith(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }

    return Listener(
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _holdController,
        builder: (context, child) {
          final progress = _holdController.value;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s10, vertical: AppSpacing.s10),
            decoration: BoxDecoration(
              color: AppColors.rival.withValues(alpha: 0.15 + (progress * 0.4)),
              borderRadius: AppSpacing.br16,
              border: Border.all(
                color: AppColors.rival,
                width: 1.5,
              ),
              boxShadow: _isHolding
                  ? AppSpacing.subtleElevation
                  : null,
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
                        backgroundColor: AppColors.rival.withValues(alpha: 0.25),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    const Icon(
                      Icons.stop_rounded,
                      color: AppColors.rival,
                      size: 14,
                    ),
                  ],
                ),
                const SizedBox(width: AppSpacing.s6),
                Text(
                  _isHolding ? 'HOLD ${(1.4 * (1.0 - progress)).toStringAsFixed(1)}s' : 'HOLD STOP',
                  style: AppText.label.copyWith(
                    color: AppColors.rival,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
