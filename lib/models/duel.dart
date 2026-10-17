class Duel {
  final String id;
  final String challengerId;
  final String challengerUsername;
  final String opponentId;
  final String opponentUsername;
  final String targetType; // 'area' or 'distance'
  final double targetValue; // sqm or meters
  final String status; // 'pending', 'active', 'completed', 'declined', 'expired'
  final double challengerProgress;
  final double opponentProgress;
  final String? winnerId;
  final int xpStake;
  final DateTime expiresAt;
  final DateTime createdAt;
  final DateTime? completedAt;

  const Duel({
    required this.id,
    required this.challengerId,
    required this.challengerUsername,
    required this.opponentId,
    required this.opponentUsername,
    required this.targetType,
    required this.targetValue,
    required this.status,
    required this.challengerProgress,
    required this.opponentProgress,
    this.winnerId,
    required this.xpStake,
    required this.expiresAt,
    required this.createdAt,
    this.completedAt,
  });

  factory Duel.fromJson(Map<String, dynamic> json) {
    return Duel(
      id: json['id'] as String? ?? '',
      challengerId: json['challenger_id'] as String? ?? '',
      challengerUsername: json['challenger_username'] as String? ?? 'Runner',
      opponentId: json['opponent_id'] as String? ?? '',
      opponentUsername: json['opponent_username'] as String? ?? 'Runner',
      targetType: json['target_type'] as String? ?? 'area',
      targetValue: (json['target_value'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'pending',
      challengerProgress: (json['challenger_progress'] as num?)?.toDouble() ?? 0.0,
      opponentProgress: (json['opponent_progress'] as num?)?.toDouble() ?? 0.0,
      winnerId: json['winner_id'] as String?,
      xpStake: (json['xp_stake'] as num?)?.toInt() ?? 500,
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'challenger_id': challengerId,
    'challenger_username': challengerUsername,
    'opponent_id': opponentId,
    'opponent_username': opponentUsername,
    'target_type': targetType,
    'target_value': targetValue,
    'status': status,
    'challenger_progress': challengerProgress,
    'opponent_progress': opponentProgress,
    if (winnerId != null) 'winner_id': winnerId,
    'xp_stake': xpStake,
    'expires_at': expiresAt.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
    if (completedAt != null) 'completed_at': completedAt!.toIso8601String(),
  };

  bool isChallenger(String currentUserId) => challengerId == currentUserId;

  String opponentName(String currentUserId) =>
      isChallenger(currentUserId) ? opponentUsername : challengerUsername;

  double myProgress(String currentUserId) =>
      isChallenger(currentUserId) ? challengerProgress : opponentProgress;

  double theirProgress(String currentUserId) =>
      isChallenger(currentUserId) ? opponentProgress : challengerProgress;

  double myProgressFraction(String currentUserId) {
    if (targetValue <= 0) return 0.0;
    return (myProgress(currentUserId) / targetValue).clamp(0.0, 1.0);
  }

  double theirProgressFraction(String currentUserId) {
    if (targetValue <= 0) return 0.0;
    return (theirProgress(currentUserId) / targetValue).clamp(0.0, 1.0);
  }

  bool get isPending => status == 'pending';
  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';
  bool get isDeclined => status == 'declined';
  bool get isExpired => status == 'expired';

  bool didIWin(String currentUserId) => isCompleted && winnerId == currentUserId;
}
