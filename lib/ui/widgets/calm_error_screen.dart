import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// A calm, non-jarring fallback screen replacing the default red error box.
///
/// Designed to reassure runners that active route points and polygon data
/// are persisted safely in local storage, providing a one-tap recovery path.
class CalmErrorScreen extends StatefulWidget {
  final FlutterErrorDetails details;
  final VoidCallback? onReset;

  const CalmErrorScreen({super.key, required this.details, this.onReset});

  @override
  State<CalmErrorScreen> createState() => _CalmErrorScreenState();
}

class _CalmErrorScreenState extends State<CalmErrorScreen> {
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bgDeep,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s24,
              vertical: AppSpacing.s32,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border, width: 1.5),
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: AppColors.accent,
                    size: 36,
                  ),
                ),
                const SizedBox(height: AppSpacing.s24),
                const Text(
                  'RUNNER INTERFACE RECOVERED',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.s12),
                const Text(
                  'A temporary interface issue occurred. Your telemetry, active GPS track, and claimed territories remain safely stored on your device.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.s32),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.onAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      if (widget.onReset != null) {
                        widget.onReset!();
                      } else {
                        // Standard recovery: pop or reload home route
                        final nav = Navigator.maybeOf(context);
                        if (nav != null && nav.canPop()) {
                          nav.pop();
                        } else {
                          nav?.pushNamedAndRemoveUntil('/', (route) => false);
                        }
                      }
                    },
                    child: const Text(
                      'RETURN TO NAVIGATION',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: AppSpacing.s24),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _showDetails = !_showDetails;
                      });
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _showDetails
                              ? 'Hide Diagnostics'
                              : 'Show Diagnostics (Debug Only)',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                        Icon(
                          _showDetails ? Icons.expand_less : Icons.expand_more,
                          color: AppColors.textMuted,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                  if (_showDetails) ...[
                    const SizedBox(height: AppSpacing.s12),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.s12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        widget.details.exceptionAsString(),
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
