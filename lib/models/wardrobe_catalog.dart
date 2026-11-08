import '../../ui/theme/wardrobe_colors.dart';
import 'package:flutter/material.dart';
import 'runner_profile.dart';

enum WardrobeCategory {
  headwear,
  top,
  bottoms,
  shoes,
  accessory,
  bodyTone,
}

extension WardrobeCategoryExtension on WardrobeCategory {
  String get displayName {
    switch (this) {
      case WardrobeCategory.headwear:
        return 'Headwear';
      case WardrobeCategory.top:
        return 'Tops';
      case WardrobeCategory.bottoms:
        return 'Bottoms';
      case WardrobeCategory.shoes:
        return 'Shoes';
      case WardrobeCategory.accessory:
        return 'Accessories';
      case WardrobeCategory.bodyTone:
        return 'Skin Tone';
    }
  }

  IconData get icon {
    switch (this) {
      case WardrobeCategory.headwear:
        return Icons.face_rounded;
      case WardrobeCategory.top:
        return Icons.checkroom_rounded;
      case WardrobeCategory.bottoms:
        return Icons.airline_seat_legroom_extra_rounded;
      case WardrobeCategory.shoes:
        return Icons.directions_run_rounded;
      case WardrobeCategory.accessory:
        return Icons.watch_rounded;
      case WardrobeCategory.bodyTone:
        return Icons.palette_outlined;
    }
  }
}

enum WardrobeUnlockType {
  free,
  level,
  distanceKm,
  streakDays,
  season,
}

class WardrobeUnlockCondition {
  final WardrobeUnlockType type;
  final int requiredValue;
  final String label;

  const WardrobeUnlockCondition.free()
      : type = WardrobeUnlockType.free,
        requiredValue = 0,
        label = 'Unlocked';

  const WardrobeUnlockCondition.level(int level)
      : type = WardrobeUnlockType.level,
        requiredValue = level,
        label = 'Reach Level $level';

  const WardrobeUnlockCondition.distance(int km)
      : type = WardrobeUnlockType.distanceKm,
        requiredValue = km,
        label = 'Run $km km total';

  const WardrobeUnlockCondition.streak(int days)
      : type = WardrobeUnlockType.streakDays,
        requiredValue = days,
        label = '$days-day run streak';

  const WardrobeUnlockCondition.season(String seasonName)
      : type = WardrobeUnlockType.season,
        requiredValue = 1,
        label = 'Season $seasonName reward';

  bool isUnlocked(RunnerProfile? profile) {
    if (type == WardrobeUnlockType.free) return true;
    if (profile == null) return false;

    switch (type) {
      case WardrobeUnlockType.free:
        return true;
      case WardrobeUnlockType.level:
        return profile.level >= requiredValue;
      case WardrobeUnlockType.distanceKm:
        return profile.totalDistanceKm >= requiredValue;
      case WardrobeUnlockType.streakDays:
        return profile.currentStreak >= requiredValue;
      case WardrobeUnlockType.season:
        return profile.level >= 3;
    }
  }
}

class WardrobeItem {
  final String id;
  final String name;
  final WardrobeCategory category;
  final Color primaryColor;
  final Color accentColor;
  final String description;
  final WardrobeUnlockCondition unlockCondition;

  const WardrobeItem({
    required this.id,
    required this.name,
    required this.category,
    required this.primaryColor,
    required this.accentColor,
    required this.description,
    required this.unlockCondition,
  });
}

class WardrobeCatalog {
  WardrobeCatalog._();

  static const List<WardrobeItem> items = [
    // -------------------------------------------------------------
    // 1. HEADWEAR (10 items)
    // -------------------------------------------------------------
    WardrobeItem(
      id: 'headwear_none',
      name: 'No Headwear',
      category: WardrobeCategory.headwear,
      primaryColor: Colors.transparent,
      accentColor: Colors.transparent,
      description: 'Clean natural athletic hair',
      unlockCondition: WardrobeUnlockCondition.free(),
    ),
    WardrobeItem(
      id: 'headwear_headband_blue',
      name: 'Electric Sweatband',
      category: WardrobeCategory.headwear,
      primaryColor: WardrobeColors.c_FF2D9CDB,
      accentColor: WardrobeColors.c_FFF4F6F8,
      description: 'Signature electric blue moisture-wicking headband',
      unlockCondition: WardrobeUnlockCondition.free(),
    ),
    WardrobeItem(
      id: 'headwear_cap_graphite',
      name: 'Graphite Trail Cap',
      category: WardrobeCategory.headwear,
      primaryColor: WardrobeColors.c_FF23272E,
      accentColor: WardrobeColors.c_FFF2C94C,
      description: 'Lightweight curved bill technical runner cap',
      unlockCondition: WardrobeUnlockCondition.level(2),
    ),
    WardrobeItem(
      id: 'headwear_visor_yellow',
      name: 'Mustard Speed Visor',
      category: WardrobeCategory.headwear,
      primaryColor: WardrobeColors.c_FFF2C94C,
      accentColor: WardrobeColors.c_FF121417,
      description: 'Open-top ventilated sun visor with high contrast trim',
      unlockCondition: WardrobeUnlockCondition.distance(10),
    ),
    WardrobeItem(
      id: 'headwear_beanie_dark',
      name: 'Obsidian Thermal Beanie',
      category: WardrobeCategory.headwear,
      primaryColor: WardrobeColors.c_FF121417,
      accentColor: WardrobeColors.c_FF2D9CDB,
      description: 'Fleece-lined wind resistant cold morning headwear',
      unlockCondition: WardrobeUnlockCondition.streak(3),
    ),
    WardrobeItem(
      id: 'headwear_visor_crimson',
      name: 'Marathon Visor Crimson',
      category: WardrobeCategory.headwear,
      primaryColor: WardrobeColors.c_FFFF6B6B,
      accentColor: WardrobeColors.c_FFF4F6F8,
      description: 'Featherweight racing visor with anti-glare underbill',
      unlockCondition: WardrobeUnlockCondition.distance(25),
    ),
    WardrobeItem(
      id: 'headwear_cap_midnight',
      name: 'Midnight Running Cap',
      category: WardrobeCategory.headwear,
      primaryColor: WardrobeColors.c_FF181B20,
      accentColor: WardrobeColors.c_FF2D9CDB,
      description: 'Perforated side panels for optimal heat dissipation',
      unlockCondition: WardrobeUnlockCondition.level(5),
    ),
    WardrobeItem(
      id: 'headwear_headband_neon',
      name: 'Cyan Grip Headband',
      category: WardrobeCategory.headwear,
      primaryColor: WardrobeColors.c_FF00E5FF,
      accentColor: WardrobeColors.c_FF121417,
      description: 'Low-profile silicone grip sweat barrier',
      unlockCondition: WardrobeUnlockCondition.streak(5),
    ),
    WardrobeItem(
      id: 'headwear_visor_wind',
      name: 'Apex Aero Visor',
      category: WardrobeCategory.headwear,
      primaryColor: WardrobeColors.c_FFF4F6F8,
      accentColor: WardrobeColors.c_FF2D9CDB,
      description: 'Minimalist aerodynamic race day visor',
      unlockCondition: WardrobeUnlockCondition.distance(50),
    ),
    WardrobeItem(
      id: 'headwear_crown_gold',
      name: 'Gold Crown Headband',
      category: WardrobeCategory.headwear,
      primaryColor: WardrobeColors.c_FFE5A93C,
      accentColor: WardrobeColors.c_FF121417,
      description: 'Gilded athletic headband for top territory contenders',
      unlockCondition: WardrobeUnlockCondition.level(10),
    ),

    // -------------------------------------------------------------
    // 2. TOPS (10 items)
    // -------------------------------------------------------------
    WardrobeItem(
      id: 'top_tech_tee_navy',
      name: 'Core Tech Tee Navy',
      category: WardrobeCategory.top,
      primaryColor: WardrobeColors.c_FF1A2B42,
      accentColor: WardrobeColors.c_FF2D9CDB,
      description: 'Breathable raglan-sleeve technical training tee',
      unlockCondition: WardrobeUnlockCondition.free(),
    ),
    WardrobeItem(
      id: 'top_singlet_electric',
      name: 'Electric Blue Singlet',
      category: WardrobeCategory.top,
      primaryColor: WardrobeColors.c_FF2D9CDB,
      accentColor: WardrobeColors.c_FFF4F6F8,
      description: 'Racerback track singlet with low friction bonded seams',
      unlockCondition: WardrobeUnlockCondition.free(),
    ),
    WardrobeItem(
      id: 'top_pro_tank_yellow',
      name: 'Mustard Speed Tank',
      category: WardrobeCategory.top,
      primaryColor: WardrobeColors.c_FFF2C94C,
      accentColor: WardrobeColors.c_FF121417,
      description: 'High visibility lightweight speedwork tank',
      unlockCondition: WardrobeUnlockCondition.level(2),
    ),
    WardrobeItem(
      id: 'top_long_sleeve_obsidian',
      name: 'Obsidian Long-Sleeve',
      category: WardrobeCategory.top,
      primaryColor: WardrobeColors.c_FF121417,
      accentColor: WardrobeColors.c_FF2D9CDB,
      description: 'Thumbhole cuff cold-weather base layer',
      unlockCondition: WardrobeUnlockCondition.distance(15),
    ),
    WardrobeItem(
      id: 'top_windbreaker_stealth',
      name: 'Stealth Windbreaker',
      category: WardrobeCategory.top,
      primaryColor: WardrobeColors.c_FF23272E,
      accentColor: WardrobeColors.c_FF00E5FF,
      description: 'Packable ripstop nylon shell with rear storm vent',
      unlockCondition: WardrobeUnlockCondition.streak(3),
    ),
    WardrobeItem(
      id: 'top_speedsuit_top',
      name: 'Aero Speed Top',
      category: WardrobeCategory.top,
      primaryColor: WardrobeColors.c_FF1E232B,
      accentColor: WardrobeColors.c_FFF2C94C,
      description: 'Form-fitting compressive endurance top',
      unlockCondition: WardrobeUnlockCondition.distance(30),
    ),
    WardrobeItem(
      id: 'top_shell_grey',
      name: 'Stormproof Shell Grey',
      category: WardrobeCategory.top,
      primaryColor: WardrobeColors.c_FF38404A,
      accentColor: WardrobeColors.c_FF2D9CDB,
      description: 'Seam-sealed water repellent running jacket',
      unlockCondition: WardrobeUnlockCondition.streak(7),
    ),
    WardrobeItem(
      id: 'top_jersey_coral',
      name: 'Rival Coral Singlet',
      category: WardrobeCategory.top,
      primaryColor: WardrobeColors.c_FFFF6B6B,
      accentColor: WardrobeColors.c_FF121417,
      description: 'Bold rival faction race jersey',
      unlockCondition: WardrobeUnlockCondition.level(6),
    ),
    WardrobeItem(
      id: 'top_thermal_zip',
      name: 'Alpine Thermal Half-Zip',
      category: WardrobeCategory.top,
      primaryColor: WardrobeColors.c_FF2A3444,
      accentColor: WardrobeColors.c_FFF2C94C,
      description: 'Micro-grid fleece half-zip for sub-zero tempo runs',
      unlockCondition: WardrobeUnlockCondition.distance(75),
    ),
    WardrobeItem(
      id: 'top_elite_vest',
      name: 'Territory Master Vest',
      category: WardrobeCategory.top,
      primaryColor: WardrobeColors.c_FFE5A93C,
      accentColor: WardrobeColors.c_FF121417,
      description: 'Champion gold trim endurance racing vest',
      unlockCondition: WardrobeUnlockCondition.distance(100),
    ),

    // -------------------------------------------------------------
    // 3. BOTTOMS (10 items)
    // -------------------------------------------------------------
    WardrobeItem(
      id: 'bottoms_shorts_charcoal',
      name: 'Split Shorts Charcoal',
      category: WardrobeCategory.bottoms,
      primaryColor: WardrobeColors.c_FF1C2025,
      accentColor: WardrobeColors.c_FF2D9CDB,
      description: 'Classic 3-inch split leg racing shorts',
      unlockCondition: WardrobeUnlockCondition.free(),
    ),
    WardrobeItem(
      id: 'bottoms_shorts_blue',
      name: 'Electric Blue 5-inch',
      category: WardrobeCategory.bottoms,
      primaryColor: WardrobeColors.c_FF1D5D86,
      accentColor: WardrobeColors.c_FF2D9CDB,
      description: 'Versatile 5-inch shorts with zippered rear key pocket',
      unlockCondition: WardrobeUnlockCondition.free(),
    ),
    WardrobeItem(
      id: 'bottoms_half_tights_dark',
      name: 'Compression Half-Tights',
      category: WardrobeCategory.bottoms,
      primaryColor: WardrobeColors.c_FF121417,
      accentColor: WardrobeColors.c_FFF2C94C,
      description: 'Zero-chafe targeted quad and hamstring compression',
      unlockCondition: WardrobeUnlockCondition.level(2),
    ),
    WardrobeItem(
      id: 'bottoms_trail_cargo',
      name: 'Trail Cargo Shorts',
      category: WardrobeCategory.bottoms,
      primaryColor: WardrobeColors.c_FF262C35,
      accentColor: WardrobeColors.c_FF27AE60,
      description: 'Reinforced trail shorts with dual energy gel loops',
      unlockCondition: WardrobeUnlockCondition.distance(10),
    ),
    WardrobeItem(
      id: 'bottoms_tights_thermal',
      name: 'Thermal Full Tights',
      category: WardrobeCategory.bottoms,
      primaryColor: WardrobeColors.c_FF15191E,
      accentColor: WardrobeColors.c_FF2D9CDB,
      description: 'Full-length cold weather tights with ankle zips',
      unlockCondition: WardrobeUnlockCondition.streak(3),
    ),
    WardrobeItem(
      id: 'bottoms_brief_slate',
      name: 'Racing Brief Slate',
      category: WardrobeCategory.bottoms,
      primaryColor: WardrobeColors.c_FF2E3642,
      accentColor: WardrobeColors.c_FFF4F6F8,
      description: 'Ultra-minimal track competition brief',
      unlockCondition: WardrobeUnlockCondition.distance(25),
    ),
    WardrobeItem(
      id: 'bottoms_track_pants',
      name: 'Tapered Track Pants',
      category: WardrobeCategory.bottoms,
      primaryColor: WardrobeColors.c_FF1C2025,
      accentColor: WardrobeColors.c_FFF2C94C,
      description: 'Modern slim warm-up pants with articulated knees',
      unlockCondition: WardrobeUnlockCondition.level(5),
    ),
    WardrobeItem(
      id: 'bottoms_aero_tights',
      name: 'Aero Split Half-Tights',
      category: WardrobeCategory.bottoms,
      primaryColor: WardrobeColors.c_FF0F1216,
      accentColor: WardrobeColors.c_FF00E5FF,
      description: 'Drop-in phone pockets with laser-perforated hem',
      unlockCondition: WardrobeUnlockCondition.distance(50),
    ),
    WardrobeItem(
      id: 'bottoms_shorts_yellow',
      name: 'Mustard Trim Shorts',
      category: WardrobeCategory.bottoms,
      primaryColor: WardrobeColors.c_FF181B20,
      accentColor: WardrobeColors.c_FFF2C94C,
      description: 'Contrast bound side splits with reflective tape',
      unlockCondition: WardrobeUnlockCondition.streak(14),
    ),
    WardrobeItem(
      id: 'bottoms_ultra_tights',
      name: 'Ultra Endurance Tights',
      category: WardrobeCategory.bottoms,
      primaryColor: WardrobeColors.c_FF121417,
      accentColor: WardrobeColors.c_FFE5A93C,
      description: 'Gold piped 100km club multi-pocket tights',
      unlockCondition: WardrobeUnlockCondition.distance(100),
    ),

    // -------------------------------------------------------------
    // 4. SHOES (10 items)
    // -------------------------------------------------------------
    WardrobeItem(
      id: 'shoes_trainer_electric',
      name: 'Aero Trainer Electric',
      category: WardrobeCategory.shoes,
      primaryColor: WardrobeColors.c_FF2D9CDB,
      accentColor: WardrobeColors.c_FFF4F6F8,
      description: 'Responsive supercritical foam daily running shoe',
      unlockCondition: WardrobeUnlockCondition.free(),
    ),
    WardrobeItem(
      id: 'shoes_daily_cushion',
      name: 'Daily Cushion Graphite',
      category: WardrobeCategory.shoes,
      primaryColor: WardrobeColors.c_FF23272E,
      accentColor: WardrobeColors.c_FF2D9CDB,
      description: 'High stack plush road running cruiser',
      unlockCondition: WardrobeUnlockCondition.free(),
    ),
    WardrobeItem(
      id: 'shoes_spike_yellow',
      name: 'Mustard Speed Spike',
      category: WardrobeCategory.shoes,
      primaryColor: WardrobeColors.c_FFF2C94C,
      accentColor: WardrobeColors.c_FF121417,
      description: 'Aggressive track and sprint interval footwear',
      unlockCondition: WardrobeUnlockCondition.level(2),
    ),
    WardrobeItem(
      id: 'shoes_trail_lug',
      name: 'Trail Lug Max',
      category: WardrobeCategory.shoes,
      primaryColor: WardrobeColors.c_FF27AE60,
      accentColor: WardrobeColors.c_FF1C2025,
      description: '5mm multidirectional rubber lugs for loose dirt',
      unlockCondition: WardrobeUnlockCondition.distance(15),
    ),
    WardrobeItem(
      id: 'shoes_carbon_cyan',
      name: 'Cyan Carbon Racer',
      category: WardrobeCategory.shoes,
      primaryColor: WardrobeColors.c_FF00E5FF,
      accentColor: WardrobeColors.c_FF121417,
      description: 'Curved carbon fiber plate marathon speed weapon',
      unlockCondition: WardrobeUnlockCondition.streak(3),
    ),
    WardrobeItem(
      id: 'shoes_rival_tempo',
      name: 'Rival Coral Tempo',
      category: WardrobeCategory.shoes,
      primaryColor: WardrobeColors.c_FFFF6B6B,
      accentColor: WardrobeColors.c_FFF4F6F8,
      description: 'Snappy lightweight trainer for tempo sessions',
      unlockCondition: WardrobeUnlockCondition.level(4),
    ),
    WardrobeItem(
      id: 'shoes_stealth_dark',
      name: 'Stealth Obsidian Runner',
      category: WardrobeCategory.shoes,
      primaryColor: WardrobeColors.c_FF121417,
      accentColor: WardrobeColors.c_FF38404A,
      description: 'Triple black monochrome road racer',
      unlockCondition: WardrobeUnlockCondition.distance(30),
    ),
    WardrobeItem(
      id: 'shoes_gold_carbon',
      name: 'Gold Plate Pro',
      category: WardrobeCategory.shoes,
      primaryColor: WardrobeColors.c_FFE5A93C,
      accentColor: WardrobeColors.c_FF121417,
      description: 'Gilded race day super shoe for podium chasers',
      unlockCondition: WardrobeUnlockCondition.distance(50),
    ),
    WardrobeItem(
      id: 'shoes_desert_haul',
      name: 'Desert Long-Haul Shoe',
      category: WardrobeCategory.shoes,
      primaryColor: WardrobeColors.c_FFD08B5B,
      accentColor: WardrobeColors.c_FF23272E,
      description: 'Reinforced gaiter compatible ultra shoe',
      unlockCondition: WardrobeUnlockCondition.streak(7),
    ),
    WardrobeItem(
      id: 'shoes_marathon_fly',
      name: 'Elite Flyknit Marathon',
      category: WardrobeCategory.shoes,
      primaryColor: WardrobeColors.c_FFF4F6F8,
      accentColor: WardrobeColors.c_FF2D9CDB,
      description: 'One-piece woven upper sub-2hr marathon flagship',
      unlockCondition: WardrobeUnlockCondition.distance(100),
    ),

    // -------------------------------------------------------------
    // 5. ACCESSORIES (10 items)
    // -------------------------------------------------------------
    WardrobeItem(
      id: 'acc_none',
      name: 'No Accessory',
      category: WardrobeCategory.accessory,
      primaryColor: Colors.transparent,
      accentColor: Colors.transparent,
      description: 'Unencumbered lightweight running setup',
      unlockCondition: WardrobeUnlockCondition.free(),
    ),
    WardrobeItem(
      id: 'acc_watch_charcoal',
      name: 'GPS Watch Charcoal',
      category: WardrobeCategory.accessory,
      primaryColor: WardrobeColors.c_FF1C2025,
      accentColor: WardrobeColors.c_FF2D9CDB,
      description: 'Multi-band GNSS wrist biometric sports watch',
      unlockCondition: WardrobeUnlockCondition.free(),
    ),
    WardrobeItem(
      id: 'acc_shades_cyan',
      name: 'Pro Shades Cyan',
      category: WardrobeCategory.accessory,
      primaryColor: WardrobeColors.c_FF00E5FF,
      accentColor: WardrobeColors.c_FF121417,
      description: 'Rimless panoramic shield sunglasses with UV400',
      unlockCondition: WardrobeUnlockCondition.level(2),
    ),
    WardrobeItem(
      id: 'acc_armband_slate',
      name: 'Reflective Armband',
      category: WardrobeCategory.accessory,
      primaryColor: WardrobeColors.c_FF38404A,
      accentColor: WardrobeColors.c_FFF2C94C,
      description: 'High visibility night running reflective strap',
      unlockCondition: WardrobeUnlockCondition.distance(10),
    ),
    WardrobeItem(
      id: 'acc_shades_gold',
      name: 'Gold Polarized Shades',
      category: WardrobeCategory.accessory,
      primaryColor: WardrobeColors.c_FFE5A93C,
      accentColor: WardrobeColors.c_FF121417,
      description: 'Anti-fog hydrophobic gold iridium sport shades',
      unlockCondition: WardrobeUnlockCondition.streak(3),
    ),
    WardrobeItem(
      id: 'acc_hr_strap',
      name: 'Optical HR Armband',
      category: WardrobeCategory.accessory,
      primaryColor: WardrobeColors.c_FF2D9CDB,
      accentColor: WardrobeColors.c_FF121417,
      description: 'Dual-beam optical sensor for precision heart tracking',
      unlockCondition: WardrobeUnlockCondition.distance(20),
    ),
    WardrobeItem(
      id: 'acc_waistpack_yellow',
      name: 'Mustard Waist Pack',
      category: WardrobeCategory.accessory,
      primaryColor: WardrobeColors.c_FFF2C94C,
      accentColor: WardrobeColors.c_FF121417,
      description: 'Bounce-free ergonomic hydration and key belt',
      unlockCondition: WardrobeUnlockCondition.level(5),
    ),
    WardrobeItem(
      id: 'acc_poles_holster',
      name: 'Trail Pole Quiver',
      category: WardrobeCategory.accessory,
      primaryColor: WardrobeColors.c_FF23272E,
      accentColor: WardrobeColors.c_FF27AE60,
      description: 'Quick-draw magnetic carbon pole harness',
      unlockCondition: WardrobeUnlockCondition.distance(50),
    ),
    WardrobeItem(
      id: 'acc_finisher_medal',
      name: 'Finisher Ribbon Medal',
      category: WardrobeCategory.accessory,
      primaryColor: WardrobeColors.c_FFE5A93C,
      accentColor: WardrobeColors.c_FF2D9CDB,
      description: 'Official commemorative territory league medal',
      unlockCondition: WardrobeUnlockCondition.streak(7),
    ),
    WardrobeItem(
      id: 'acc_scout_beacon',
      name: 'Territory Scout Beacon',
      category: WardrobeCategory.accessory,
      primaryColor: WardrobeColors.c_FF2D9CDB,
      accentColor: WardrobeColors.c_FFF2C94C,
      description: 'Frontier territory surveyor arm tracker beacon',
      unlockCondition: WardrobeUnlockCondition.distance(100),
    ),

    // -------------------------------------------------------------
    // 6. SKIN / BODY TONE (10 items)
    // -------------------------------------------------------------
    WardrobeItem(
      id: 'tone_warm_sand',
      name: 'Warm Sand',
      category: WardrobeCategory.bodyTone,
      primaryColor: WardrobeColors.c_FFF3C7A8,
      accentColor: WardrobeColors.c_FFDFAB8B,
      description: 'Warm light peach undertone',
      unlockCondition: WardrobeUnlockCondition.free(),
    ),
    WardrobeItem(
      id: 'tone_fair_peach',
      name: 'Fair Peach',
      category: WardrobeCategory.bodyTone,
      primaryColor: WardrobeColors.c_FFFFDBAC,
      accentColor: WardrobeColors.c_FFECC292,
      description: 'Natural light tone',
      unlockCondition: WardrobeUnlockCondition.free(),
    ),
    WardrobeItem(
      id: 'tone_golden_olive',
      name: 'Golden Olive',
      category: WardrobeCategory.bodyTone,
      primaryColor: WardrobeColors.c_FFE0AC69,
      accentColor: WardrobeColors.c_FFC99450,
      description: 'Warm medium golden tone',
      unlockCondition: WardrobeUnlockCondition.free(),
    ),
    WardrobeItem(
      id: 'tone_rich_caramel',
      name: 'Rich Caramel',
      category: WardrobeCategory.bodyTone,
      primaryColor: WardrobeColors.c_FFC68642,
      accentColor: WardrobeColors.c_FFAF6E2B,
      description: 'Deep amber caramel tone',
      unlockCondition: WardrobeUnlockCondition.free(),
    ),
    WardrobeItem(
      id: 'tone_deep_bronze',
      name: 'Deep Bronze',
      category: WardrobeCategory.bodyTone,
      primaryColor: WardrobeColors.c_FF8D5524,
      accentColor: WardrobeColors.c_FF754316,
      description: 'Rich dark bronze tone',
      unlockCondition: WardrobeUnlockCondition.free(),
    ),
    WardrobeItem(
      id: 'tone_warm_umber',
      name: 'Warm Umber',
      category: WardrobeCategory.bodyTone,
      primaryColor: WardrobeColors.c_FF6B4423,
      accentColor: WardrobeColors.c_FF553417,
      description: 'Deep warm brown tone',
      unlockCondition: WardrobeUnlockCondition.free(),
    ),
    WardrobeItem(
      id: 'tone_cool_alabaster',
      name: 'Cool Alabaster',
      category: WardrobeCategory.bodyTone,
      primaryColor: WardrobeColors.c_FFFFE0BD,
      accentColor: WardrobeColors.c_FFEBC7A3,
      description: 'Fair porcelain undertone',
      unlockCondition: WardrobeUnlockCondition.free(),
    ),
    WardrobeItem(
      id: 'tone_sun_bronze',
      name: 'Sun Bronze',
      category: WardrobeCategory.bodyTone,
      primaryColor: WardrobeColors.c_FFD08B5B,
      accentColor: WardrobeColors.c_FFB87343,
      description: 'Sun-kissed bronze tone',
      unlockCondition: WardrobeUnlockCondition.free(),
    ),
    WardrobeItem(
      id: 'tone_deep_espresso',
      name: 'Deep Espresso',
      category: WardrobeCategory.bodyTone,
      primaryColor: WardrobeColors.c_FF4A2C11,
      accentColor: WardrobeColors.c_FF381F0A,
      description: 'Deep rich espresso tone',
      unlockCondition: WardrobeUnlockCondition.free(),
    ),
    WardrobeItem(
      id: 'tone_obsidian_slate',
      name: 'Obsidian Earth',
      category: WardrobeCategory.bodyTone,
      primaryColor: WardrobeColors.c_FF382721,
      accentColor: WardrobeColors.c_FF261914,
      description: 'Darkest rich earth tone',
      unlockCondition: WardrobeUnlockCondition.free(),
    ),
  ];

  static List<WardrobeItem> getItemsByCategory(WardrobeCategory category) {
    return items.where((item) => item.category == category).toList();
  }

  static WardrobeItem findById(String id) {
    return items.firstWhere(
      (item) => item.id == id,
      orElse: () => items.first,
    );
  }

  static Color getToneColor(String toneId) {
    final item = items.firstWhere(
      (item) => item.id == toneId && item.category == WardrobeCategory.bodyTone,
      orElse: () => items.firstWhere(
        (i) => i.id == 'tone_warm_sand',
      ),
    );
    return item.primaryColor;
  }
}

