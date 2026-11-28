/// State of an active sprint incursion challenge.
enum IncursionStatus { active, repelled, failed }

/// Dynamic in-run gamified HIIT challenge representing a rival faction border breach.
class SprintIncursion {
  final String id;
  final String rivalFactionName;
  final double targetSpeedMps; // Minimum speed in meters per second
  final int totalDurationSeconds;
  int remainingSeconds;
  IncursionStatus status;
  final int rewardXp;
  final double targetPaceMinPerKm;

  SprintIncursion({
    required this.id,
    required this.rivalFactionName,
    required this.targetSpeedMps,
    required this.totalDurationSeconds,
    required this.remainingSeconds,
    this.status = IncursionStatus.active,
    this.rewardXp = 100,
  }) : targetPaceMinPerKm = targetSpeedMps > 0
           ? (1000.0 / targetSpeedMps) / 60.0
           : 5.0;

  bool get isActive => status == IncursionStatus.active;
  bool get isRepelled => status == IncursionStatus.repelled;

  double get progressFraction {
    if (totalDurationSeconds <= 0) return 1.0;
    final elapsed = totalDurationSeconds - remainingSeconds;
    return (elapsed / totalDurationSeconds).clamp(0.0, 1.0);
  }

  String get targetPaceString {
    final minutes = targetPaceMinPerKm.floor();
    final seconds = ((targetPaceMinPerKm - minutes) * 60).round();
    return '$minutes:${seconds.toString().padLeft(2, '0')}/km';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'rivalFactionName': rivalFactionName,
    'targetSpeedMps': targetSpeedMps,
    'totalDurationSeconds': totalDurationSeconds,
    'remainingSeconds': remainingSeconds,
    'status': status.name,
    'rewardXp': rewardXp,
  };

  factory SprintIncursion.fromJson(Map<String, dynamic> json) {
    return SprintIncursion(
      id: json['id'] as String,
      rivalFactionName: json['rivalFactionName'] as String? ?? 'Obsidian',
      targetSpeedMps: (json['targetSpeedMps'] as num).toDouble(),
      totalDurationSeconds: json['totalDurationSeconds'] as int,
      remainingSeconds: json['remainingSeconds'] as int,
      status: IncursionStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => IncursionStatus.active,
      ),
      rewardXp: json['rewardXp'] as int? ?? 100,
    );
  }
}
