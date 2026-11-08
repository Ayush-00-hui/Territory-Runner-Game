/// Crew model representing a cooperative group of runners.
class Crew {
  final String id;
  final String name;
  final String joinCode;
  final String creatorId;
  final DateTime createdAt;

  const Crew({
    required this.id,
    required this.name,
    required this.joinCode,
    required this.creatorId,
    required this.createdAt,
  });

  factory Crew.fromJson(Map<String, dynamic> json) => Crew(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    joinCode: json['join_code'] as String? ?? '',
    creatorId: json['creator_id'] as String? ?? '',
    createdAt:
        DateTime.tryParse(json['created_at'] as String? ?? '')?.toUtc() ??
        DateTime.now().toUtc(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'join_code': joinCode,
    'creator_id': creatorId,
    'created_at': createdAt.toIso8601String(),
  };
}

/// Member of a crew with their weekly distance and area contribution.
class CrewMember {
  final String crewId;
  final String userId;
  final String username;
  final String role; // "leader", "member"
  final DateTime joinedAt;
  final double weeklyDistanceM;
  final double weeklyAreaSqm;

  const CrewMember({
    required this.crewId,
    required this.userId,
    required this.username,
    required this.role,
    required this.joinedAt,
    required this.weeklyDistanceM,
    required this.weeklyAreaSqm,
  });

  bool get isLeader => role.toLowerCase() == 'leader';

  factory CrewMember.fromJson(Map<String, dynamic> json) => CrewMember(
    crewId: json['crew_id'] as String? ?? '',
    userId: json['user_id'] as String? ?? '',
    username: json['username'] as String? ?? '',
    role: json['role'] as String? ?? 'member',
    joinedAt:
        DateTime.tryParse(json['joined_at'] as String? ?? '')?.toUtc() ??
        DateTime.now().toUtc(),
    weeklyDistanceM: (json['weekly_distance_m'] as num?)?.toDouble() ?? 0.0,
    weeklyAreaSqm: (json['weekly_area_sqm'] as num?)?.toDouble() ?? 0.0,
  );

  Map<String, dynamic> toJson() => {
    'crew_id': crewId,
    'user_id': userId,
    'username': username,
    'role': role,
    'joined_at': joinedAt.toIso8601String(),
    'weekly_distance_m': weeklyDistanceM,
    'weekly_area_sqm': weeklyAreaSqm,
  };
}

/// Weekly target set for a crew.
class CrewGoal {
  final String id;
  final String crewId;
  final String goalType; // "distance", "area"
  final double targetValue;
  final double currentValue;
  final DateTime weekStart;
  final double progressPercent;
  final String createdBy;
  final DateTime createdAt;

  const CrewGoal({
    required this.id,
    required this.crewId,
    required this.goalType,
    required this.targetValue,
    required this.currentValue,
    required this.weekStart,
    required this.progressPercent,
    required this.createdBy,
    required this.createdAt,
  });

  factory CrewGoal.fromJson(Map<String, dynamic> json) => CrewGoal(
    id: json['id'] as String? ?? '',
    crewId: json['crew_id'] as String? ?? '',
    goalType: json['goal_type'] as String? ?? 'distance',
    targetValue: (json['target_value'] as num?)?.toDouble() ?? 0.0,
    currentValue: (json['current_value'] as num?)?.toDouble() ?? 0.0,
    weekStart:
        DateTime.tryParse(json['week_start'] as String? ?? '')?.toUtc() ??
        DateTime.now().toUtc(),
    progressPercent: (json['progress_percent'] as num?)?.toDouble() ?? 0.0,
    createdBy: json['created_by'] as String? ?? '',
    createdAt:
        DateTime.tryParse(json['created_at'] as String? ?? '')?.toUtc() ??
        DateTime.now().toUtc(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'crew_id': crewId,
    'goal_type': goalType,
    'target_value': targetValue,
    'current_value': currentValue,
    'week_start': weekStart.toIso8601String(),
    'progress_percent': progressPercent,
    'created_by': createdBy,
    'created_at': createdAt.toIso8601String(),
  };
}

/// Runner crew status, membership list, and active weekly goal.
class MyCrewData {
  final Crew? crew;
  final String? role;
  final List<CrewMember> members;
  final CrewGoal? activeGoal;

  const MyCrewData({
    this.crew,
    this.role,
    this.members = const [],
    this.activeGoal,
  });

  bool get hasCrew => crew != null;
  bool get isLeader => role?.toLowerCase() == 'leader';

  factory MyCrewData.fromJson(Map<String, dynamic> json) => MyCrewData(
    crew: json['crew'] != null
        ? Crew.fromJson(json['crew'] as Map<String, dynamic>)
        : null,
    role: json['role'] as String?,
    members:
        (json['members'] as List<dynamic>?)
            ?.map((e) => CrewMember.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
    activeGoal: json['active_goal'] != null
        ? CrewGoal.fromJson(json['active_goal'] as Map<String, dynamic>)
        : null,
  );

  Map<String, dynamic> toJson() => {
    if (crew != null) 'crew': crew!.toJson(),
    if (role != null) 'role': role,
    'members': members.map((e) => e.toJson()).toList(),
    if (activeGoal != null) 'active_goal': activeGoal!.toJson(),
  };
}
