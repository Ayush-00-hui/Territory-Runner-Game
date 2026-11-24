enum AchievementTier {
  bronze,
  silver,
  gold,
  platinum;

  String get label {
    switch (this) {
      case AchievementTier.bronze:
        return 'Bronze';
      case AchievementTier.silver:
        return 'Silver';
      case AchievementTier.gold:
        return 'Gold';
      case AchievementTier.platinum:
        return 'Platinum';
    }
  }
}

/// Represents an authentic athletic tiered achievement milestone.
class TieredAchievement {
  final String id;
  final String title;
  final String description;
  final String metricUnit; // e.g. "km", "m²", "days", "cells"
  final Map<AchievementTier, double> thresholds;
  final Map<AchievementTier, String?> cosmeticUnlockIds;

  const TieredAchievement({
    required this.id,
    required this.title,
    required this.description,
    required this.metricUnit,
    required this.thresholds,
    this.cosmeticUnlockIds = const {},
  });

  /// Computes evaluation state given the runner's raw metric progress value.
  TieredProgress evaluate(double currentValue) {
    AchievementTier? currentTier;
    AchievementTier? nextTier;
    double? nextThreshold;

    final tiers = [
      AchievementTier.bronze,
      AchievementTier.silver,
      AchievementTier.gold,
      AchievementTier.platinum,
    ];

    for (final tier in tiers) {
      final target = thresholds[tier] ?? double.infinity;
      if (currentValue >= target) {
        currentTier = tier;
      } else {
        nextTier = tier;
        nextThreshold = target;
        break;
      }
    }

    double progressFraction = 1.0;
    String hint = 'Completed!';

    if (nextTier != null && nextThreshold != null) {
      final prevThreshold = currentTier != null
          ? (thresholds[currentTier] ?? 0.0)
          : 0.0;
      final step = nextThreshold - prevThreshold;
      final stepProgress = currentValue - prevThreshold;
      progressFraction = step > 0 ? (stepProgress / step).clamp(0.0, 1.0) : 0.0;

      final remaining = nextThreshold - currentValue;
      final remainingStr = remaining >= 10.0
          ? remaining.round().toString()
          : remaining.toStringAsFixed(1);
      hint = '$remainingStr $metricUnit more for ${nextTier.label}';
    }

    return TieredProgress(
      achievement: this,
      currentValue: currentValue,
      currentTier: currentTier,
      nextTier: nextTier,
      nextThreshold: nextThreshold,
      progressFraction: progressFraction,
      nextBadgeHint: hint,
    );
  }

  /// Built-in catalog of standard achievements
  static List<TieredAchievement> get standardCatalog => [
    const TieredAchievement(
      id: 'ach_distance',
      title: 'Road Strider',
      description: 'Accumulate lifetime running distance.',
      metricUnit: 'km',
      thresholds: {
        AchievementTier.bronze: 10.0,
        AchievementTier.silver: 50.0,
        AchievementTier.gold: 100.0,
        AchievementTier.platinum: 500.0,
      },
      cosmeticUnlockIds: {
        AchievementTier.bronze: 'visor_aero',
        AchievementTier.gold: 'shoes_carbon',
      },
    ),
    const TieredAchievement(
      id: 'ach_territory',
      title: 'Territory Claimer',
      description: 'Enclose and sovereignly fortify geographic land.',
      metricUnit: 'm²',
      thresholds: {
        AchievementTier.bronze: 1000.0,
        AchievementTier.silver: 10000.0,
        AchievementTier.gold: 50000.0,
        AchievementTier.platinum: 250000.0,
      },
      cosmeticUnlockIds: {
        AchievementTier.silver: 'top_vanguard',
        AchievementTier.platinum: 'bottom_elite',
      },
    ),
    const TieredAchievement(
      id: 'ach_streak',
      title: 'Unbroken Consistency',
      description: 'Maintain consecutive daily running streaks.',
      metricUnit: 'days',
      thresholds: {
        AchievementTier.bronze: 3.0,
        AchievementTier.silver: 7.0,
        AchievementTier.gold: 30.0,
        AchievementTier.platinum: 100.0,
      },
      cosmeticUnlockIds: {
        AchievementTier.silver: 'shoes_trail',
        AchievementTier.gold: 'flame_badge',
      },
    ),
    const TieredAchievement(
      id: 'ach_exploration',
      title: 'Master Cartographer',
      description: 'Explore new local grid cells and lift the fog of war.',
      metricUnit: 'cells',
      thresholds: {
        AchievementTier.bronze: 25.0,
        AchievementTier.silver: 100.0,
        AchievementTier.gold: 500.0,
        AchievementTier.platinum: 2000.0,
      },
      cosmeticUnlockIds: {
        AchievementTier.bronze: 'cap_explorer',
        AchievementTier.gold: 'backpack_pioneer',
      },
    ),
  ];
}

/// Evaluation state for an achievement.
class TieredProgress {
  final TieredAchievement achievement;
  final double currentValue;
  final AchievementTier? currentTier;
  final AchievementTier? nextTier;
  final double? nextThreshold;
  final double progressFraction;
  final String nextBadgeHint;

  const TieredProgress({
    required this.achievement,
    required this.currentValue,
    required this.currentTier,
    required this.nextTier,
    required this.nextThreshold,
    required this.progressFraction,
    required this.nextBadgeHint,
  });

  bool get isMaxed => nextTier == null;
}

/// An entry in the unlocked achievements timeline.
class AchievementTimelineEntry {
  final String achievementId;
  final String title;
  final AchievementTier tier;
  final DateTime unlockedAt;

  const AchievementTimelineEntry({
    required this.achievementId,
    required this.title,
    required this.tier,
    required this.unlockedAt,
  });

  Map<String, dynamic> toJson() => {
    'achievementId': achievementId,
    'title': title,
    'tier': tier.name,
    'unlockedAt': unlockedAt.toIso8601String(),
  };

  factory AchievementTimelineEntry.fromJson(Map<String, dynamic> json) =>
      AchievementTimelineEntry(
        achievementId: json['achievementId'] as String,
        title: json['title'] as String,
        tier: AchievementTier.values.firstWhere(
          (t) => t.name == json['tier'],
          orElse: () => AchievementTier.bronze,
        ),
        unlockedAt: DateTime.parse(json['unlockedAt'] as String),
      );
}
