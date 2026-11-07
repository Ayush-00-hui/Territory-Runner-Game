import 'package:flutter/material.dart';

import '../../../services/app_preferences.dart';
import '../../../ui/ui.dart';

/// Modal bottom sheet explaining physiological calorie calculation factors
/// and offering transparent personal smartwatch calibration.
class CalorieFactorsSheet extends StatefulWidget {
  const CalorieFactorsSheet({super.key});

  /// Displays the calorie information and calibration sheet modally.
  static Future<void> show({required BuildContext context}) {
    return AppSheet.show(
      context: context,
      builder: (ctx) => const CalorieFactorsSheet(),
    );
  }

  @override
  State<CalorieFactorsSheet> createState() => _CalorieFactorsSheetState();
}

class _CalorieFactorsSheetState extends State<CalorieFactorsSheet> {
  final AppPreferences _appPrefs = AppPreferences();
  final TextEditingController _watchKcalController = TextEditingController();
  final TextEditingController _appKcalController = TextEditingController();
  bool _isEnteringSession = false;
  String? _inlineError;

  @override
  void dispose() {
    _watchKcalController.dispose();
    _appKcalController.dispose();
    super.dispose();
  }

  void _saveCalibrationSession() async {
    final watchKcal = double.tryParse(_watchKcalController.text.trim());
    final appKcal = double.tryParse(_appKcalController.text.trim());

    if (watchKcal == null || watchKcal < 20 || watchKcal > 4000) {
      setState(() {
        _inlineError =
            'Please enter a valid watch calorie value (20–4000 kcal).';
      });
      return;
    }
    if (appKcal == null || appKcal < 20 || appKcal > 4000) {
      setState(() {
        _inlineError = 'Please enter a valid app calorie value (20–4000 kcal).';
      });
      return;
    }

    await _appPrefs.recordWatchCalibrationSession(
      userWatchKcal: watchKcal,
      modelEstimatedKcal: appKcal,
    );

    setState(() {
      _isEnteringSession = false;
      _watchKcalController.clear();
      _appKcalController.clear();
      _inlineError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double?>(
      valueListenable: _appPrefs.watchCalorieFactorNotifier,
      builder: (context, factor, _) {
        final sessionCount = _appPrefs.watchCalibrationSessionCount;
        final hasActiveFactor = factor != null;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.local_fire_department_rounded,
                  color: AppColors.rival,
                  size: 22,
                ),
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: Text(
                    'How calories are calculated',
                    style: AppText.headingSmall.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.textMuted,
                  ),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Close',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s12),
            Text(
              'Calories are estimated entirely on this phone using published biomechanical equations and an on-device ML surrogate. They are never uploaded.',
              style: AppText.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.s16),

            // Factor explanation cards
            _buildFactorRow(
              icon: Icons.fitness_center_rounded,
              title: 'Body Mass',
              description: 'Heavier runners expend more energy moving center-of-mass horizontally and vertically.',
            ),
            const SizedBox(height: AppSpacing.s10),
            _buildFactorRow(
              icon: Icons.speed_rounded,
              title: 'Speed & Locomotion',
              description: 'Smoothed GPS speed distinguishes walking from running using ACSM metabolic curves.',
            ),
            const SizedBox(height: AppSpacing.s10),
            _buildFactorRow(
              icon: Icons.terrain_rounded,
              title: 'Incline & Elevation',
              description: 'Grade filtered over 25m horizontal windows models uphill gravitational work via Minetti slope polynomials.',
            ),
            const SizedBox(height: AppSpacing.s10),
            _buildFactorRow(
              icon: Icons.directions_walk_rounded,
              title: 'Step Cadence',
              description: 'Real-time accelerometer step frequency informs locomotion economy and stride mechanics.',
            ),

            const SizedBox(height: AppSpacing.s16),
            const Divider(color: AppColors.border),
            const SizedBox(height: AppSpacing.s14),

            // Personal Watch Calibration Section
            Row(
              children: [
                const Icon(
                  Icons.watch_rounded,
                  color: AppColors.accent,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.s8),
                Text(
                  'Calibrate with my watch',
                  style: AppText.labelLarge.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              hasActiveFactor
                  ? 'Active personal calibration: ${(factor).toStringAsFixed(2)}x factor applied to all estimates.'
                  : 'Enter calories from 3 runs recorded with your smartwatch (Apple Watch, Garmin, Coros) to compute a personal scaling factor (bounded 0.8x–1.2x).',
              style: AppText.bodySmall.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.s10),

            if (hasActiveFactor) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.s12),
                decoration: BoxDecoration(
                  color: AppColors.bgDeep,
                  borderRadius: AppSpacing.br12,
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      color: AppColors.success,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Expanded(
                      child: Text(
                        'Calibrated with $sessionCount sessions (${(factor).toStringAsFixed(2)}x)',
                        style: AppText.bodySmall.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        await _appPrefs.resetWatchCalibration();
                      },
                      child: Text(
                        'Reset',
                        style: AppText.label.copyWith(color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_isEnteringSession) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.s12),
                decoration: BoxDecoration(
                  color: AppColors.bgDeep,
                  borderRadius: AppSpacing.br12,
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Session ${sessionCount + 1} of 3',
                      style: AppText.labelMedium.copyWith(
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _watchKcalController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Watch kcal',
                              hintText: 'e.g. 420',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s12),
                        Expanded(
                          child: TextField(
                            controller: _appKcalController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'App kcal',
                              hintText: 'e.g. 395',
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_inlineError != null) ...[
                      const SizedBox(height: AppSpacing.s8),
                      Text(
                        _inlineError!,
                        style: AppText.bodySmall.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.s10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _isEnteringSession = false;
                              _inlineError = null;
                            });
                          },
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: AppSpacing.s8),
                        ElevatedButton(
                          onPressed: _saveCalibrationSession,
                          child: const Text('Save session'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ] else ...[
              OutlinedButton.icon(
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(
                  sessionCount == 0
                      ? 'Add first watch calibration run'
                      : 'Add session ($sessionCount / 3 completed)',
                ),
                onPressed: () {
                  setState(() {
                    _isEnteringSession = true;
                    _inlineError = null;
                  });
                },
              ),
            ],

            const SizedBox(height: AppSpacing.s20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Got it'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFactorRow({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.s6),
          decoration: BoxDecoration(
            color: AppColors.bgDeep,
            borderRadius: AppSpacing.br8,
          ),
          child: Icon(icon, size: 16, color: AppColors.textPrimary),
        ),
        const SizedBox(width: AppSpacing.s10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppText.labelMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: AppText.bodySmall.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
