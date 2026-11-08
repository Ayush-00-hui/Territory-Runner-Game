import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/runner_avatar.dart';
import '../models/wardrobe_catalog.dart';

/// Offline-first service managing the runner buddy / avatar state and Hive persistence.
class AvatarService {
  static final AvatarService instance = AvatarService._();
  AvatarService._();

  static const String boxName = 'avatar_v1';
  static const String currentAvatarKey = 'current_avatar';

  Box<String>? _box;
  final ValueNotifier<RunnerAvatar> avatarNotifier =
      ValueNotifier<RunnerAvatar>(RunnerAvatar.defaultAvatar);

  RunnerAvatar get currentAvatar => avatarNotifier.value;

  /// Initializes the service and loads persisted avatar from Hive box `avatar_v1`.
  Future<void> init({Box<String>? box}) async {
    if (box != null) {
      _box = box;
    } else {
      try {
        if (Hive.isBoxOpen(boxName)) {
          _box = Hive.box<String>(boxName);
        } else {
          _box = await Hive.openBox<String>(boxName);
        }
      } catch (_) {
        // Fallback gracefully in testing / headless environments
      }
    }

    final raw = _box?.get(currentAvatarKey);
    if (raw != null && raw.isNotEmpty) {
      avatarNotifier.value = RunnerAvatar.deserialize(raw);
    } else {
      avatarNotifier.value = RunnerAvatar.defaultAvatar;
    }
  }

  /// Equips an item in a specific wardrobe category and saves to Hive.
  Future<void> equip(WardrobeCategory category, String itemId) async {
    RunnerAvatar updated;
    switch (category) {
      case WardrobeCategory.headwear:
        updated = currentAvatar.copyWith(headwearId: itemId);
        break;
      case WardrobeCategory.top:
        updated = currentAvatar.copyWith(topId: itemId);
        break;
      case WardrobeCategory.bottoms:
        updated = currentAvatar.copyWith(bottomsId: itemId);
        break;
      case WardrobeCategory.shoes:
        updated = currentAvatar.copyWith(shoesId: itemId);
        break;
      case WardrobeCategory.accessory:
        updated = currentAvatar.copyWith(accessoryId: itemId);
        break;
      case WardrobeCategory.bodyTone:
        updated = currentAvatar.copyWith(bodyToneId: itemId);
        break;
    }

    avatarNotifier.value = updated;
    await _saveToDisk();
  }

  /// Toggles between active running cycle and standing ready athletic pose.
  Future<void> setReadyPose(bool ready) async {
    avatarNotifier.value = currentAvatar.copyWith(isReadyPose: ready);
    await _saveToDisk();
  }

  Future<void> _saveToDisk() async {
    try {
      await _box?.put(currentAvatarKey, avatarNotifier.value.serialize());
    } catch (_) {}
  }

  /// Clears stored avatar data (e.g. on account deletion or local data wipe).
  Future<void> clear() async {
    avatarNotifier.value = RunnerAvatar.defaultAvatar;
    try {
      await _box?.clear();
    } catch (_) {}
  }

  /// Sets avatar directly for unit testing.
  @visibleForTesting
  void setAvatarForTesting(RunnerAvatar avatar) {
    avatarNotifier.value = avatar;
  }
}

