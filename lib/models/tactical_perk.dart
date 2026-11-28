/// Consumable pre-run tactical perks / loadout abilities.
enum TacticalPerkType {
  /// Reveals hidden supply drops and ghost runners within 1.5km.
  sonarPulse,

  /// Freezes territory decay across all player polygons for 24 hours.
  aegisShield,

  /// Multiplies territory points by 1.5x while cadence remains above 165 SPM.
  overdrive,

  /// Magnetically collects tactical crates within a 40m radius without direct contact.
  trailMagnet,
}

class TacticalPerk {
  final TacticalPerkType type;
  final String title;
  final String description;
  final int durationMinutes;
  bool isEquipped;

  TacticalPerk({
    required this.type,
    required this.title,
    required this.description,
    required this.durationMinutes,
    this.isEquipped = false,
  });

  static List<TacticalPerk> defaultPerks() => [
    TacticalPerk(
      type: TacticalPerkType.sonarPulse,
      title: 'Sonar Pulse',
      description: 'Reveals all tactical crates and ghost beacons within 1.5km for 30 minutes.',
      durationMinutes: 30,
    ),
    TacticalPerk(
      type: TacticalPerkType.aegisShield,
      title: 'Aegis Shield',
      description: 'Freezes decay on your claimed territories for 24 hours after this run.',
      durationMinutes: 1440,
    ),
    TacticalPerk(
      type: TacticalPerkType.overdrive,
      title: 'Cadence Overdrive',
      description: 'Awards 1.5x territory area points whenever cadence exceeds 165 SPM.',
      durationMinutes: 45,
    ),
    TacticalPerk(
      type: TacticalPerkType.trailMagnet,
      title: 'Trail Magnet',
      description: 'Expands loot crate collection radius from 25m to 50m.',
      durationMinutes: 60,
    ),
  ];
}
