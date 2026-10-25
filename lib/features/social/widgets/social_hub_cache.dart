import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/duel.dart';
import '../../../models/friend.dart';
import '../../../ui/ui.dart';

/// Helper to cache social data locally for offline viewing.
class SocialHubCache {
  static const String _cachedFriendsKey = 'territory_runner_cached_friends';
  static const String _cachedRequestsKey =
      'territory_runner_cached_friend_requests';
  static const String _cachedDuelsKey = 'territory_runner_cached_duels';

  static Future<
    ({
      List<FriendUser> friends,
      List<FriendRequestDetail> requests,
      List<Duel> duels,
    })
  >
  loadCachedData() async {
    final cachedFriends = <FriendUser>[];
    final cachedRequests = <FriendRequestDetail>[];
    final cachedDuels = <Duel>[];

    try {
      final prefs = await SharedPreferences.getInstance();
      final friendsJson = prefs.getString(_cachedFriendsKey);
      final requestsJson = prefs.getString(_cachedRequestsKey);
      final duelsJson = prefs.getString(_cachedDuelsKey);

      if (friendsJson != null && friendsJson.isNotEmpty) {
        final List<dynamic> list = jsonDecode(friendsJson);
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            cachedFriends.add(FriendUser.fromJson(item));
          }
        }
      }

      if (requestsJson != null && requestsJson.isNotEmpty) {
        final List<dynamic> list = jsonDecode(requestsJson);
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            cachedRequests.add(FriendRequestDetail.fromJson(item));
          }
        }
      }

      if (duelsJson != null && duelsJson.isNotEmpty) {
        final List<dynamic> list = jsonDecode(duelsJson);
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            cachedDuels.add(Duel.fromJson(item));
          }
        }
      }
    } catch (e) {
      AppLogger.warning(
        'Failed to load cached social data: $e',
        tag: 'SocialHubCache',
      );
    }

    return (
      friends: cachedFriends,
      requests: cachedRequests,
      duels: cachedDuels,
    );
  }

  static Future<void> saveCachedData({
    required List<FriendUser> friends,
    required List<FriendRequestDetail> requests,
    required List<Duel> duels,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cachedFriendsKey,
        jsonEncode(friends.map((f) => f.toJson()).toList()),
      );
      await prefs.setString(
        _cachedRequestsKey,
        jsonEncode(requests.map((r) => r.toJson()).toList()),
      );
      await prefs.setString(
        _cachedDuelsKey,
        jsonEncode(duels.map((d) => d.toJson()).toList()),
      );
    } catch (e) {
      AppLogger.warning(
        'Failed to cache social data: $e',
        tag: 'SocialHubCache',
      );
    }
  }
}
