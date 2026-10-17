import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';

/// Standard Bottom Sheet modal with continuous squircle corners (24dp),
/// centered drag handle, scrim overlay, and safe-area wrapping.
class AppSheet extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const AppSheet({
    super.key,
    this.title,
    this.subtitle,
    required this.child,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(AppSpacing.s20, 0, AppSpacing.s20, AppSpacing.s24),
  });

  /// Displays the modal sheet using standardized styling tokens
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool isScrollControlled = true,
    bool isDismissible = true,
    bool enableDrag = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: AppColors.surface,
      barrierColor: AppColors.scrim,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: builder(context),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Standard Drag Handle
        Center(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
            width: 36.0,
            height: 4.0,
            decoration: BoxDecoration(
              color: AppColors.disabled,
              borderRadius: AppRadius.brFull,
            ),
          ),
        ),

        // Optional Title Header
        if (title != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.s20, AppSpacing.s4, AppSpacing.s20, AppSpacing.s16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title!,
                        style: AppText.titleLarge,
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: AppSpacing.s4),
                        Text(
                          subtitle!,
                          style: AppText.bodyMedium.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ],

        // Sheet Content
        Padding(
          padding: padding,
          child: child,
        ),
      ],
    );
  }
}
