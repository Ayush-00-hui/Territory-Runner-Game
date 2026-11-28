/// Personality style of the tactical companion drone.
enum DronePersonality {
  tactical, // Crisp, military scout briefing
  zen, // Calm, breathing and posture focus
  hype, // High-energy arcade cheerleader
}

/// AI Companion Drone that orbits the athlete on the map and delivers personalized coaching.
class DroneCompanion {
  final String name;
  int level;
  int currentXp;
  DronePersonality personality;
  String skinName;

  DroneCompanion({
    this.name = 'Aero',
    this.level = 1,
    this.currentXp = 0,
    this.personality = DronePersonality.tactical,
    this.skinName = 'Electric Obsidian',
  });

  int get xpForNextLevel => level * 250;
  double get levelProgress => (currentXp / xpForNextLevel).clamp(0.0, 1.0);

  void addXp(int xp) {
    currentXp += xp;
    while (currentXp >= xpForNextLevel) {
      currentXp -= xpForNextLevel;
      level++;
    }
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'level': level,
    'currentXp': currentXp,
    'personality': personality.name,
    'skinName': skinName,
  };

  factory DroneCompanion.fromJson(Map<String, dynamic> json) {
    return DroneCompanion(
      name: json['name'] as String? ?? 'Aero',
      level: json['level'] as int? ?? 1,
      currentXp: json['currentXp'] as int? ?? 0,
      personality: DronePersonality.values.firstWhere(
        (e) => e.name == json['personality'],
        orElse: () => DronePersonality.tactical,
      ),
      skinName: json['skinName'] as String? ?? 'Electric Obsidian',
    );
  }
}
