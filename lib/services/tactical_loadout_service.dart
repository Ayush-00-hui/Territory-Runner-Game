import 'package:flutter/foundation.dart';
import '../core/logging/app_logger.dart';
import '../models/tactical_perk.dart';
import '../features/gameplay/loot_crate_service.dart';

/// Service managing athlete pre-run tactical perk loadouts.
class TacticalLoadoutService extends ChangeNotifier {
  static final TacticalLoadoutService _instance = TacticalLoadoutService._internal();
  factory TacticalLoadoutService() => _instance;
  TacticalLoadoutService._internal() {
    _availablePerks = TacticalPerk.defaultPerks();
  }

  late final List<TacticalPerk> _availablePerks;

  List<TacticalPerk> get availablePerks => List.unmodifiable(_availablePerks);
  List<TacticalPerk> get equippedPerks =>
      _availablePerks.where((p) => p.isEquipped).toList();

  /// Toggles equip state (max 2 equipped simultaneously)
  bool toggleEquip(TacticalPerkType type) {
    final perk = _availablePerks.firstWhere((p) => p.type == type);
    if (perk.isEquipped) {
      perk.isEquipped = false;
      notifyListeners();
      return true;
    } else {
      if (equippedPerks.length >= 2) {
        AppLogger.warning('Cannot equip more than 2 tactical perks simultaneously.', tag: 'TacticalLoadoutService');
        return false;
      }
      perk.isEquipped = true;
      notifyListeners();
      return true;
    }
  }

  /// Activates equipped perks at the start of a run session
  void activateLoadoutForRun() {
    for (final perk in equippedPerks) {
      AppLogger.info('Activating Tactical Perk: ${perk.title}', tag: 'TacticalLoadoutService');
      if (perk.type == TacticalPerkType.trailMagnet) {
        LootCrateService().hasTrailMagnet = true;
      }
    }
  }
}
