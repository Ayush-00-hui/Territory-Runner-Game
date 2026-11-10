import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/runner_avatar.dart';
import '../../../models/runner_profile.dart';
import '../../../models/wardrobe_catalog.dart';
import '../../../services/avatar_service.dart';
import '../../../ui/theme/app_colors.dart';
import '../../../ui/theme/app_spacing.dart';
import '../../../ui/theme/app_text.dart';
import '../../../ui/widgets/app_sheet.dart';
import '../../../ui/widgets/app_toast.dart';
import '../../../ui/widgets/runner_avatar_painter.dart';

/// Modal bottom sheet allowing runners to preview, customize, and equip gear.
class WardrobeSheet extends StatefulWidget {
  final RunnerProfile? profile;

  const WardrobeSheet({super.key, this.profile});

  static Future<void> show(BuildContext context, {RunnerProfile? profile}) {
    return AppSheet.show(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.88,
        child: WardrobeSheet(profile: profile),
      ),
    );
  }

  @override
  State<WardrobeSheet> createState() => _WardrobeSheetState();
}

class _WardrobeSheetState extends State<WardrobeSheet> {
  WardrobeCategory _selectedCategory = WardrobeCategory.top;
  bool _previewRunning = true;

  @override
  Widget build(BuildContext context) {
    final avatarService = AvatarService.instance;

    return ValueListenableBuilder<RunnerAvatar>(
      valueListenable: avatarService.avatarNotifier,
      builder: (context, currentAvatar, _) {
        final categoryItems = WardrobeCatalog.getItemsByCategory(
          _selectedCategory,
        );

        return Scaffold(
          backgroundColor: AppColors.surface,
          appBar: AppBar(
            backgroundColor: AppColors.surface,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.close_rounded,
                color: AppColors.textPrimary,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Runner Wardrobe',
              style: AppText.titleMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  _previewRunning
                      ? Icons.directions_run_rounded
                      : Icons.accessibility_new_rounded,
                  color: AppColors.accent,
                ),
                tooltip: _previewRunning
                    ? 'Switch to Standing Pose'
                    : 'Switch to Running Stride',
                onPressed: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _previewRunning = !_previewRunning;
                  });
                },
              ),
            ],
          ),
          body: Column(
            children: [
              // 1. Large Live Interactive Athletic Showcase Stage
              Builder(
                builder: (context) {
                  final topAccent = WardrobeCatalog.findById(
                    currentAvatar.topId,
                  ).accentColor;
                  final stageGlow = topAccent == Colors.transparent
                      ? AppColors.accent
                      : topAccent;
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.s14,
                    ),
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0, -0.05),
                        radius: 0.9,
                        colors: [
                          stageGlow.withValues(alpha: 0.14),
                          AppColors.bgDeep,
                        ],
                      ),
                      border: const Border(
                        bottom: BorderSide(color: AppColors.border, width: 1),
                      ),
                    ),
                    child: Column(
                      children: [
                        Center(
                          child: AvatarWidget(
                            avatar: currentAvatar,
                            size: 152,
                            isRunning: _previewRunning,
                            semanticsLabel: 'Runner avatar live preview',
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s6),
                        InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _previewRunning = !_previewRunning;
                            });
                          },
                          borderRadius: AppRadius.brFull,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.s12,
                              vertical: AppSpacing.s4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: AppRadius.brFull,
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _previewRunning
                                      ? Icons.directions_run_rounded
                                      : Icons.accessibility_new_rounded,
                                  size: 14,
                                  color: AppColors.accent,
                                ),
                                const SizedBox(width: AppSpacing.s6),
                                Text(
                                  _previewRunning
                                      ? 'Dynamic Stride Cycle'
                                      : 'Athletic Ready Stance',
                                  style: AppText.caption.copyWith(
                                    color: AppColors.textSecondary,
                                    letterSpacing: 0.4,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              // 2. Category Selector Chips
              Container(
                height: 52,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.s6),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s16,
                  ),
                  itemCount: WardrobeCategory.values.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: AppSpacing.s8),
                  itemBuilder: (context, index) {
                    final cat = WardrobeCategory.values[index];
                    final isSelected = cat == _selectedCategory;

                    return ChoiceChip(
                      selected: isSelected,
                      avatar: Icon(
                        cat.icon,
                        size: 16,
                        color: isSelected
                            ? AppColors.onAccent
                            : AppColors.textSecondary,
                      ),
                      label: Text(
                        cat.displayName,
                        style: AppText.caption.copyWith(
                          color: isSelected
                              ? AppColors.onAccent
                              : AppColors.textPrimary,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w600,
                        ),
                      ),
                      selectedColor: AppColors.accent,
                      backgroundColor: AppColors.surface2,
                      side: BorderSide(
                        color: isSelected ? AppColors.accent : AppColors.border,
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _selectedCategory = cat;
                          });
                        }
                      },
                    );
                  },
                ),
              ),

              const Divider(height: 1, color: AppColors.border),

              // 3. Category Items Grid
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(AppSpacing.s16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.0,
                    crossAxisSpacing: AppSpacing.s12,
                    mainAxisSpacing: AppSpacing.s12,
                  ),
                  itemCount: categoryItems.length,
                  itemBuilder: (context, index) {
                    final item = categoryItems[index];
                    final isEquipped = _isItemEquipped(currentAvatar, item);
                    final isUnlocked = item.unlockCondition.isUnlocked(
                      widget.profile,
                    );

                    return _WardrobeItemCard(
                      item: item,
                      isEquipped: isEquipped,
                      isUnlocked: isUnlocked,
                      onTap: () async {
                        if (!isUnlocked) {
                          HapticFeedback.heavyImpact();
                          AppToast.showGlobal(
                            'Locked: ${item.unlockCondition.label} to unlock ${item.name}',
                            type: AppToastType.warning,
                          );
                          return;
                        }

                        HapticFeedback.lightImpact();
                        await avatarService.equip(_selectedCategory, item.id);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _isItemEquipped(RunnerAvatar avatar, WardrobeItem item) {
    switch (item.category) {
      case WardrobeCategory.headwear:
        return avatar.headwearId == item.id;
      case WardrobeCategory.top:
        return avatar.topId == item.id;
      case WardrobeCategory.bottoms:
        return avatar.bottomsId == item.id;
      case WardrobeCategory.shoes:
        return avatar.shoesId == item.id;
      case WardrobeCategory.accessory:
        return avatar.accessoryId == item.id;
      case WardrobeCategory.bodyTone:
        return avatar.bodyToneId == item.id;
    }
  }
}

class _WardrobeItemCard extends StatelessWidget {
  final WardrobeItem item;
  final bool isEquipped;
  final bool isUnlocked;
  final VoidCallback onTap;

  const _WardrobeItemCard({
    required this.item,
    required this.isEquipped,
    required this.isUnlocked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isEquipped
        ? AppColors.accent
        : (isUnlocked ? AppColors.border : AppColors.borderSubtle);

    return Semantics(
      label:
          '${item.name}, ${isEquipped ? 'Equipped' : (isUnlocked ? 'Available' : item.unlockCondition.label)}',
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.br12,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.s10),
          decoration: BoxDecoration(
            color: isEquipped ? AppColors.surface2 : AppColors.bgDeep,
            borderRadius: AppRadius.br12,
            border: Border.all(
              color: borderColor,
              width: isEquipped ? 2.0 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Dual-tone category gear badge
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: item.primaryColor == Colors.transparent
                          ? AppColors.surface2
                          : item.primaryColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: item.accentColor == Colors.transparent
                            ? AppColors.border
                            : item.accentColor,
                        width: 2.0,
                      ),
                    ),
                    child: Icon(
                      item.category.icon,
                      size: 16,
                      color: item.primaryColor == Colors.transparent
                          ? AppColors.textSecondary
                          : (item.primaryColor.computeLuminance() > 0.45
                                ? AppColors.onAccent
                                : AppColors.textPrimary),
                    ),
                  ),

                  // State Badge
                  if (isEquipped)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: AppRadius.br8,
                      ),
                      child: Text(
                        'EQUIPPED',
                        style: AppText.caption.copyWith(
                          color: AppColors.onAccent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  else if (!isUnlocked)
                    const Icon(
                      Icons.lock_outline_rounded,
                      size: 16,
                      color: AppColors.textMuted,
                    ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: AppText.titleSmall.copyWith(
                      color: isUnlocked
                          ? AppColors.textPrimary
                          : AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isUnlocked ? item.description : item.unlockCondition.label,
                    style: AppText.caption.copyWith(
                      color: isUnlocked
                          ? AppColors.textSecondary
                          : AppColors.warning,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
