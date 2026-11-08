import 'dart:convert';

/// Represents the customizable runner buddy / avatar configuration.
class RunnerAvatar {
  final String headwearId;
  final String topId;
  final String bottomsId;
  final String shoesId;
  final String accessoryId;
  final String bodyToneId;
  final bool isReadyPose;

  const RunnerAvatar({
    this.headwearId = 'headwear_none',
    this.topId = 'top_tech_tee_navy',
    this.bottomsId = 'bottoms_shorts_charcoal',
    this.shoesId = 'shoes_trainer_electric',
    this.accessoryId = 'acc_none',
    this.bodyToneId = 'tone_warm_sand',
    this.isReadyPose = false,
  });

  static const RunnerAvatar defaultAvatar = RunnerAvatar();

  RunnerAvatar copyWith({
    String? headwearId,
    String? topId,
    String? bottomsId,
    String? shoesId,
    String? accessoryId,
    String? bodyToneId,
    bool? isReadyPose,
  }) {
    return RunnerAvatar(
      headwearId: headwearId ?? this.headwearId,
      topId: topId ?? this.topId,
      bottomsId: bottomsId ?? this.bottomsId,
      shoesId: shoesId ?? this.shoesId,
      accessoryId: accessoryId ?? this.accessoryId,
      bodyToneId: bodyToneId ?? this.bodyToneId,
      isReadyPose: isReadyPose ?? this.isReadyPose,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'headwearId': headwearId,
      'topId': topId,
      'bottomsId': bottomsId,
      'shoesId': shoesId,
      'accessoryId': accessoryId,
      'bodyToneId': bodyToneId,
      'isReadyPose': isReadyPose,
    };
  }

  factory RunnerAvatar.fromJson(Map<String, dynamic> json) {
    return RunnerAvatar(
      headwearId: json['headwearId'] as String? ?? 'headwear_none',
      topId: json['topId'] as String? ?? 'top_tech_tee_navy',
      bottomsId: json['bottomsId'] as String? ?? 'bottoms_shorts_charcoal',
      shoesId: json['shoesId'] as String? ?? 'shoes_trainer_electric',
      accessoryId: json['accessoryId'] as String? ?? 'acc_none',
      bodyToneId: json['bodyToneId'] as String? ?? 'tone_warm_sand',
      isReadyPose: json['isReadyPose'] as bool? ?? false,
    );
  }

  String serialize() => jsonEncode(toJson());

  factory RunnerAvatar.deserialize(String raw) {
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return RunnerAvatar.fromJson(decoded);
      }
    } catch (_) {}
    return defaultAvatar;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RunnerAvatar &&
          runtimeType == other.runtimeType &&
          headwearId == other.headwearId &&
          topId == other.topId &&
          bottomsId == other.bottomsId &&
          shoesId == other.shoesId &&
          accessoryId == other.accessoryId &&
          bodyToneId == other.bodyToneId &&
          isReadyPose == other.isReadyPose;

  @override
  int get hashCode =>
      headwearId.hashCode ^
      topId.hashCode ^
      bottomsId.hashCode ^
      shoesId.hashCode ^
      accessoryId.hashCode ^
      bodyToneId.hashCode ^
      isReadyPose.hashCode;
}

