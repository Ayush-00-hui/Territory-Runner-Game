import 'package:flutter/material.dart';

import '../../../models/user_body_profile.dart';
import '../../../services/app_preferences.dart';
import '../../../ui/ui.dart';

/// Modal bottom sheet allowing users to input or edit their physical body details.
///
/// Under India's DPDP Act and privacy-by-design standards:
/// - Plain-language notice: "Used on this phone to estimate calories. It is never uploaded."
/// - Quick, non-blocking: allows skipping to use the documented reference adult (70 kg, 170 cm).
/// - Keyboard-safe layout, 48dp minimum touch targets, accessible semantics.
class BodyDetailsSheet extends StatefulWidget {
  final bool isFirstRun;
  final VoidCallback? onSaved;
  final VoidCallback? onSkipped;

  const BodyDetailsSheet({
    super.key,
    this.isFirstRun = false,
    this.onSaved,
    this.onSkipped,
  });

  /// Displays the body details sheet modally.
  static Future<void> show({
    required BuildContext context,
    bool isFirstRun = false,
    VoidCallback? onSaved,
    VoidCallback? onSkipped,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => BodyDetailsSheet(
        isFirstRun: isFirstRun,
        onSaved: onSaved,
        onSkipped: onSkipped,
      ),
    );
  }

  @override
  State<BodyDetailsSheet> createState() => _BodyDetailsSheetState();
}

class _BodyDetailsSheetState extends State<BodyDetailsSheet> {
  final AppPreferences _appPrefs = AppPreferences();

  late final TextEditingController _weightController;
  late final TextEditingController _heightCmController;
  late final TextEditingController _heightFtController;
  late final TextEditingController _heightInController;
  late final TextEditingController _birthYearController;

  late Gender _selectedGender;
  String? _weightError;
  String? _heightError;
  String? _birthYearError;

  bool get _isImperial => _appPrefs.unit == DistanceUnit.imperial;

  @override
  void initState() {
    super.initState();
    final profile = _appPrefs.bodyProfile;
    final isCustom = _appPrefs.hasBodyProfile && profile != null;
    final isMigrated = profile?.isMigratedWeightOnly ?? false;

    // Weight initial text
    if (profile != null && (isCustom || isMigrated)) {
      if (_isImperial) {
        final lb = UserBodyProfile.kgToLb(profile.weightKg);
        _weightController = TextEditingController(text: lb.toStringAsFixed(1));
      } else {
        _weightController = TextEditingController(
          text: profile.weightKg.toStringAsFixed(1),
        );
      }
    } else {
      _weightController = TextEditingController();
    }

    // Height initial text
    if (profile != null && isCustom && !isMigrated) {
      if (_isImperial) {
        final (ft, inches) = UserBodyProfile.cmToFeetAndInches(
          profile.heightCm,
        );
        _heightFtController = TextEditingController(text: '$ft');
        _heightInController = TextEditingController(
          text: inches.toStringAsFixed(0),
        );
        _heightCmController = TextEditingController();
      } else {
        _heightCmController = TextEditingController(
          text: profile.heightCm.toStringAsFixed(0),
        );
        _heightFtController = TextEditingController();
        _heightInController = TextEditingController();
      }
    } else {
      _heightCmController = TextEditingController();
      _heightFtController = TextEditingController();
      _heightInController = TextEditingController();
    }

    // Birth year
    if (profile != null && isCustom && profile.birthYear != null) {
      _birthYearController = TextEditingController(
        text: '${profile.birthYear}',
      );
    } else {
      _birthYearController = TextEditingController();
    }

    _selectedGender = isCustom ? profile.gender : Gender.preferNotToSay;
  }

  @override
  void dispose() {
    _weightController.dispose();
    _heightCmController.dispose();
    _heightFtController.dispose();
    _heightInController.dispose();
    _birthYearController.dispose();
    super.dispose();
  }

  Future<void> _validateAndSave() async {
    String? weightErr;
    String? heightErr;
    String? birthYearErr;

    // 1. Parse Weight
    final rawWeight = double.tryParse(_weightController.text.trim());
    double? weightKg;
    if (_isImperial) {
      weightErr = UserBodyProfile.validateWeightLb(rawWeight);
      if (weightErr == null && rawWeight != null) {
        weightKg = UserBodyProfile.lbToKg(rawWeight);
      }
    } else {
      weightErr = UserBodyProfile.validateWeightKg(rawWeight);
      if (weightErr == null && rawWeight != null) {
        weightKg = rawWeight;
      }
    }

    // 2. Parse Height
    double? heightCm;
    if (_isImperial) {
      final ft = int.tryParse(_heightFtController.text.trim());
      final inches = double.tryParse(_heightInController.text.trim()) ?? 0.0;
      heightErr = UserBodyProfile.validateHeightFtIn(ft, inches);
      if (heightErr == null && ft != null) {
        heightCm = UserBodyProfile.ftInToCm(ft, inches);
      }
    } else {
      final rawCm = double.tryParse(_heightCmController.text.trim());
      heightErr = UserBodyProfile.validateHeightCm(rawCm);
      if (heightErr == null && rawCm != null) {
        heightCm = rawCm;
      }
    }

    // 3. Parse Optional Birth Year / Age
    int? birthYear;
    final birthYearText = _birthYearController.text.trim();
    if (birthYearText.isNotEmpty) {
      final parsed = int.tryParse(birthYearText);
      if (parsed == null) {
        birthYearErr = 'Please enter a valid year';
      } else if (parsed >= UserBodyProfile.minAge &&
          parsed <= UserBodyProfile.maxAge) {
        birthYear = DateTime.now().year - parsed;
      } else {
        birthYearErr = UserBodyProfile.validateBirthYear(parsed);
        if (birthYearErr == null) {
          birthYear = parsed;
        }
      }
    }

    setState(() {
      _weightError = weightErr;
      _heightError = heightErr;
      _birthYearError = birthYearErr;
    });

    if (weightErr != null ||
        heightErr != null ||
        birthYearErr != null ||
        weightKg == null ||
        heightCm == null) {
      return;
    }

    final newProfile = UserBodyProfile(
      weightKg: weightKg,
      heightCm: heightCm,
      gender: _selectedGender,
      birthYear: birthYear,
      isCustomized: true,
      isMigratedWeightOnly: false,
    );

    await _appPrefs.setBodyProfile(newProfile);

    if (mounted) {
      Navigator.pop(context);
      widget.onSaved?.call();
    }
  }

  Future<void> _skip() async {
    await _appPrefs.setSkippedBodyDetails(true);
    if (mounted) {
      Navigator.pop(context);
      widget.onSkipped?.call();
    }
  }

  Future<void> _removeDetails() async {
    await _appPrefs.clearBodyProfile();
    if (mounted) {
      Navigator.pop(context);
      AppToast.show(
        context,
        'Body details removed. Reference default restored.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: AppSheet(
        title: widget.isFirstRun ? 'Body details (optional)' : 'Body details',
        subtitle:
            'Used on this phone to estimate calories. It is never uploaded.',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Plain-language DPDP notice banner
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s12,
                vertical: AppSpacing.s10,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: AppRadius.br12,
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.shield_outlined,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: Text(
                      'Stored on device only. Never sent to any server or shared.',
                      style: AppText.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.s16),

            // 1. Weight Input
            Text(
              'Weight (${_isImperial ? 'lbs' : 'kg'})',
              style: AppText.labelSmall.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.s6),
            TextField(
              controller: _weightController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.next,
              style: AppText.bodyLarge.copyWith(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: _isImperial ? 'e.g. 154' : 'e.g. 70.0',
                errorText: _weightError,
              ),
            ),

            const SizedBox(height: AppSpacing.s16),

            // 2. Height Input
            Text(
              'Height (${_isImperial ? 'ft & in' : 'cm'})',
              style: AppText.labelSmall.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.s6),
            if (_isImperial) ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _heightFtController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      style: AppText.bodyLarge.copyWith(
                        color: AppColors.textPrimary,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Feet (e.g. 5)',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: TextField(
                      controller: _heightInController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.next,
                      style: AppText.bodyLarge.copyWith(
                        color: AppColors.textPrimary,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Inches (e.g. 9)',
                      ),
                    ),
                  ),
                ],
              ),
              if (_heightError != null) ...[
                const SizedBox(height: AppSpacing.s4),
                Text(
                  _heightError!,
                  style: AppText.caption.copyWith(color: AppColors.error),
                ),
              ],
            ] else ...[
              TextField(
                controller: _heightCmController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
                style: AppText.bodyLarge.copyWith(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'e.g. 175',
                  errorText: _heightError,
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.s16),

            // 3. Gender Selection
            Text(
              'Gender (for metabolic rate)',
              style: AppText.labelSmall.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.s8),
            Wrap(
              spacing: AppSpacing.s8,
              runSpacing: AppSpacing.s8,
              children: Gender.values.map((g) {
                final isSelected = _selectedGender == g;
                return AppChip(
                  label: g.label,
                  isSelected: isSelected,
                  onTap: () {
                    setState(() => _selectedGender = g);
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: AppSpacing.s16),

            // 4. Optional Birth Year (Age)
            Text(
              'Year of birth (optional)',
              style: AppText.labelSmall.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.s6),
            TextField(
              controller: _birthYearController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              style: AppText.bodyLarge.copyWith(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'e.g. 1996 (or age e.g. 28)',
                errorText: _birthYearError,
              ),
              onSubmitted: (_) => _validateAndSave(),
            ),

            const SizedBox(height: AppSpacing.s24),

            // 5. Actions
            PrimaryButton(
              label: widget.isFirstRun ? 'Save and start' : 'Save details',
              onPressed: _validateAndSave,
            ),

            const SizedBox(height: AppSpacing.s8),

            if (widget.isFirstRun) ...[
              SecondaryButton(label: 'Skip for now', onPressed: _skip),
            ] else ...[
              SecondaryButton(
                label: 'Cancel',
                onPressed: () => Navigator.pop(context),
              ),
              if (_appPrefs.hasBodyProfile) ...[
                const SizedBox(height: AppSpacing.s12),
                TextButton(
                  onPressed: _removeDetails,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('Remove my body details'),
                ),
              ],
            ],
            const SizedBox(height: AppSpacing.s8),
          ],
        ),
      ),
    );
  }
}
