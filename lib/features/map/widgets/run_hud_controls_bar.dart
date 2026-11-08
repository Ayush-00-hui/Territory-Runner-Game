import 'package:flutter/material.dart';

import '../../../ui/ui.dart';
import 'hold_to_finish_button.dart';

/// Bottom action controls row for RunHud: Seal Shape, Giant Play/Pause, and HoldToFinish.
class RunHudControlsBar extends StatefulWidget {
  final bool isRunActive;
  final bool isNearClosure;
  final double? closureDist;
  final VoidCallback onToggleRun;
  final VoidCallback onSealShape;
  final VoidCallback onFinishRun;

  const RunHudControlsBar({
    super.key,
    required this.isRunActive,
    required this.isNearClosure,
    this.closureDist,
    required this.onToggleRun,
    required this.onSealShape,
    required this.onFinishRun,
  });

  @override
  State<RunHudControlsBar> createState() => _RunHudControlsBarState();
}

class _RunHudControlsBarState extends State<RunHudControlsBar> {
  bool _isPlayPressed = false;
  bool _isSealPressed = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isReducedMotion = AppMotion.shouldReduceMotion(context);
    final isRunActive = widget.isRunActive;
    final isNearClosure = widget.isNearClosure;
    final closureDist = widget.closureDist;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Left "Close loop" control
        Flexible(
          child: Semantics(
            button: true,
            enabled: isRunActive,
            label: isNearClosure
                ? 'Close loop. Ready to claim territory.'
                : (isRunActive
                      ? 'Close loop. Available when near your route start.'
                      : 'Close loop. Disabled. Start a run first.'),
            child: GestureDetector(
              onTapDown: (_) => setState(() => _isSealPressed = true),
              onTapUp: (_) => setState(() => _isSealPressed = false),
              onTapCancel: () => setState(() => _isSealPressed = false),
              onTap: () {
                if (!isRunActive) {
                  AppToast.show(context, 'Start a run first');
                  return;
                }
                if (!isNearClosure) {
                  final distText = closureDist != null
                      ? ' (${closureDist.round()}m away)'
                      : '';
                  AppToast.show(
                    context,
                    'Run back near your start point$distText to close the loop',
                  );
                  return;
                }
                widget.onSealShape();
              },
              behavior: HitTestBehavior.opaque,
              child: AnimatedScale(
                scale: (_isSealPressed && !isReducedMotion) ? 0.96 : 1.0,
                duration: AppMotion.fast,
                curve: AppMotion.easeOut,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s10,
                    vertical: AppSpacing.s12,
                  ),
                  decoration: BoxDecoration(
                    color: isNearClosure
                        ? palette.accent.withValues(alpha: 0.15)
                        : palette.surface2,
                    borderRadius: AppSpacing.br16,
                    border: Border.all(
                      color: isNearClosure
                          ? palette.accent
                          : palette.borderSubtle,
                      width: isNearClosure ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.sync_rounded,
                        color: isNearClosure
                            ? palette.accent
                            : (isRunActive
                                  ? palette.textSecondary
                                  : palette.textMuted),
                        size: 16,
                      ),
                      const SizedBox(width: AppSpacing.s4),
                      Flexible(
                        child: Text(
                          'Close loop',
                          style: TextStyle(
                            color: isNearClosure
                                ? palette.accent
                                : (isRunActive
                                      ? palette.textPrimary
                                      : palette.textMuted),
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(width: AppSpacing.s8),

        // Center Confident Matte Play/Pause Action Button
        Semantics(
          button: true,
          label: isRunActive ? 'Pause run tracking' : 'Start run tracking',
          child: GestureDetector(
            onTapDown: (_) => setState(() => _isPlayPressed = true),
            onTapUp: (_) => setState(() => _isPlayPressed = false),
            onTapCancel: () => setState(() => _isPlayPressed = false),
            onTap: widget.onToggleRun,
            behavior: HitTestBehavior.opaque,
            child: AnimatedScale(
              scale: (_isPlayPressed && !isReducedMotion) ? 0.94 : 1.0,
              duration: AppMotion.fast,
              curve: AppMotion.easeOut,
              child: Container(
                height: 58,
                width: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: palette.accent,
                ),
                child: Center(
                  child: Icon(
                    isRunActive
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: palette.onAccent,
                    size: 34,
                  ),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(width: AppSpacing.s8),

        // Right Accidental-Tap Protected Hold-To-Finish Button
        Flexible(
          child: HoldToFinishButton(
            isRunActive: isRunActive,
            onFinish: widget.onFinishRun,
          ),
        ),
      ],
    );
  }
}
