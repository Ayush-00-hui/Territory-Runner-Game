class FriendUser {
  final String id;
  final String username;
  final String faction;
  final double totalAreaSqm;
  final int level;
  final int xp;
  final int totalRuns;

  const FriendUser({
    required this.id,
    required this.username,
    required this.faction,
    required this.totalAreaSqm,
    required this.level,
    required this.xp,
    required this.totalRuns,
  });

  factory FriendUser.fromJson(Map<String, dynamic> json) {
    return FriendUser(
      id: json['id'] as String? ?? '',
      username: json['username'] as String? ?? 'Runner',
      faction: json['faction'] as String? ?? 'Cyber Vanguard',
      totalAreaSqm: (json['total_area_sqm'] as num?)?.toDouble() ?? 0.0,
      level: (json['level'] as num?)?.toInt() ?? 1,
      xp: (json['xp'] as num?)?.toInt() ?? 0,
      totalRuns: (json['total_runs'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'faction': faction,
    'total_area_sqm': totalAreaSqm,
    'level': level,
    'xp': xp,
    'total_runs': totalRuns,
  };
}

class FriendRequestDetail {
  final String id;
  final String requesterId;
  final String requesterName;
  final String requesterFaction;
  final String addresseeId;
  final String addresseeName;
  final String status;
  final DateTime createdAt;
  final bool isIncoming;

  const FriendRequestDetail({
    required this.id,
    required this.requesterId,
    required this.requesterName,
    required this.requesterFaction,
    required this.addresseeId,
    required this.addresseeName,
    required this.status,
    required this.createdAt,
    required this.isIncoming,
  });

  factory FriendRequestDetail.fromJson(Map<String, dynamic> json) {
    return FriendRequestDetail(
      id: json['id'] as String? ?? '',
      requesterId: json['requester_id'] as String? ?? '',
      requesterName: json['requester_name'] as String? ?? 'Runner',
      requesterFaction:
          json['requester_faction'] as String? ?? 'Cyber Vanguard',
      addresseeId: json['addressee_id'] as String? ?? '',
      addresseeName: json['addressee_name'] as String? ?? 'Runner',
      status: json['status'] as String? ?? 'pending',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      isIncoming: json['is_incoming'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'requester_id': requesterId,
    'requester_name': requesterName,
    'requester_faction': requesterFaction,
    'addressee_id': addresseeId,
    'addressee_name': addresseeName,
    'status': status,
    'created_at': createdAt.toIso8601String(),
    'is_incoming': isIncoming,
  };
}
