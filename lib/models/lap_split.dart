/// Represents an athletic 1 km or 1 mile lap split recorded during a run session.
class LapSplit {
  final int lapNumber; // 1-indexed
  final double distanceMeters;
  final int durationSeconds;
  final double paceSecondsPerKm;
  final double elevationGainMeters;

  const LapSplit({
    required this.lapNumber,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.paceSecondsPerKm,
    this.elevationGainMeters = 0.0,
  });

  /// Formatted split pace string (e.g. "5:12 /km")
  String get formattedPace {
    if (paceSecondsPerKm <= 0 || paceSecondsPerKm.isInfinite) return '--:--';
    final totalSec = paceSecondsPerKm.round();
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// Formatted duration string (e.g. "5:12")
  String get formattedDuration {
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toJson() => {
    'lapNumber': lapNumber,
    'distanceMeters': distanceMeters,
    'durationSeconds': durationSeconds,
    'paceSecondsPerKm': paceSecondsPerKm,
    'elevationGainMeters': elevationGainMeters,
  };

  factory LapSplit.fromJson(Map<String, dynamic> json) => LapSplit(
    lapNumber: json['lapNumber'] as int,
    distanceMeters: (json['distanceMeters'] as num).toDouble(),
    durationSeconds: json['durationSeconds'] as int,
    paceSecondsPerKm: (json['paceSecondsPerKm'] as num).toDouble(),
    elevationGainMeters:
        (json['elevationGainMeters'] as num?)?.toDouble() ?? 0.0,
  );
}
