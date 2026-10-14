import 'package:flutter_test/flutter_test.dart';
import 'package:territory_runner/models/ws_events.dart';

void main() {
  group('WebSocket Event Models Tests', () {
    test('RunnerPresenceEvent parses JSON correctly', () {
      final json = {
        'type': 'runner_presence',
        'user_id': 'usr_rival_42',
        'username': 'NeonRacer',
        'faction': 'Neon Syndicate',
        'latitude': 51.505,
        'longitude': -0.125,
        'speed': 3.5,
        'heading': 180.0,
        'updated_at': '2026-10-13T20:00:00Z',
      };

      final event = RunnerPresenceEvent.fromJson(json);
      expect(event.userId, equals('usr_rival_42'));
      expect(event.username, equals('NeonRacer'));
      expect(event.faction, equals('Neon Syndicate'));
      expect(event.position.latitude, equals(51.505));
      expect(event.position.longitude, equals(-0.125));
      expect(event.speed, equals(3.5));
      expect(event.heading, equals(180.0));
    });

    test('TerritoryAlertEvent parses targeted carved alert correctly', () {
      final json = {
        'type': 'territory_alert',
        'event': 'territory_carved',
        'attacker_id': 'usr_attacker',
        'attacker_name': 'GhostSprinter',
        'area_claimed_sqm': 4500.0,
        'victim_user_id': 'usr_self',
        'message': '⚠️ Rival GhostSprinter carved 4500 m² from your territory!',
        'timestamp': '2026-10-13T20:05:00Z',
      };

      final alert = TerritoryAlertEvent.fromJson(json);
      expect(alert.event, equals('territory_carved'));
      expect(alert.attackerId, equals('usr_attacker'));
      expect(alert.attackerName, equals('GhostSprinter'));
      expect(alert.areaClaimedSqm, equals(4500.0));
      expect(alert.message, contains('GhostSprinter carved 4500 m²'));
    });

    test('ConquestBroadcastEvent parses milestone newsfeed correctly', () {
      final json = {
        'type': 'conquest_broadcast',
        'event': 'territory_claimed',
        'attacker_id': 'usr_apex',
        'attacker_name': 'ApexPredator',
        'area_claimed_sqm': 12000.0,
        'message': 'ApexPredator conquered 12000 m² of territory!',
        'timestamp': '2026-10-13T20:10:00Z',
      };

      final bcast = ConquestBroadcastEvent.fromJson(json);
      expect(bcast.event, equals('territory_claimed'));
      expect(bcast.attackerId, equals('usr_apex'));
      expect(bcast.areaClaimedSqm, equals(12000.0));
      expect(bcast.message, contains('conquered 12000 m²'));
    });
  });
}
