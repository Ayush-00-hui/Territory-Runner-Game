import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';
import '../models/territory.dart';
import '../features/gameplay/territory_service.dart';
import 'api_client.dart';

/// Connection and synchronization state with the Go backend
enum SyncStatus {
  synced,
  pending,
  syncing,
  offline,
}

/// A serialized offline run record awaiting synchronization
class QueuedRun {
  final String idempotencyKey;
  final List<LatLng> points;
  final int durationSeconds;
  final double distanceMeters;
  final double clientPreviewArea;
  final int clientPreviewXp;
  final DateTime createdAt;
  final int retryCount;

  QueuedRun({
    required this.idempotencyKey,
    required this.points,
    required this.durationSeconds,
    required this.distanceMeters,
    required this.clientPreviewArea,
    required this.clientPreviewXp,
    required this.createdAt,
    this.retryCount = 0,
  });

  Map<String, dynamic> toJson() => {
    'idempotencyKey': idempotencyKey,
    'points': points.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList(),
    'durationSeconds': durationSeconds,
    'distanceMeters': distanceMeters,
    'clientPreviewArea': clientPreviewArea,
    'clientPreviewXp': clientPreviewXp,
    'createdAt': createdAt.toIso8601String(),
    'retryCount': retryCount,
  };

  factory QueuedRun.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['points'] as List<dynamic>? ?? [];
    final points = rawPoints.map((pt) {
      final m = pt as Map<String, dynamic>;
      return LatLng((m['lat'] as num).toDouble(), (m['lng'] as num).toDouble());
    }).toList();

    return QueuedRun(
      idempotencyKey: json['idempotencyKey'] as String? ?? const Uuid().v4(),
      points: points,
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble() ?? 0.0,
      clientPreviewArea: (json['clientPreviewArea'] as num?)?.toDouble() ?? 0.0,
      clientPreviewXp: (json['clientPreviewXp'] as num?)?.toInt() ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      retryCount: (json['retryCount'] as num?)?.toInt() ?? 0,
    );
  }

  QueuedRun copyWith({int? retryCount}) {
    return QueuedRun(
      idempotencyKey: idempotencyKey,
      points: points,
      durationSeconds: durationSeconds,
      distanceMeters: distanceMeters,
      clientPreviewArea: clientPreviewArea,
      clientPreviewXp: clientPreviewXp,
      createdAt: createdAt,
      retryCount: retryCount ?? this.retryCount,
    );
  }
}

/// Offline-first synchronization queue backed by Hive
class SyncQueueService {
  static final SyncQueueService _instance = SyncQueueService._internal();

  final ApiClient _apiClient;
  final TerritoryService _territoryService;
  final Uuid _uuid = const Uuid();

  final ValueNotifier<SyncStatus> statusNotifier = ValueNotifier<SyncStatus>(SyncStatus.synced);
  final ValueNotifier<int> unsettledCountNotifier = ValueNotifier<int>(0);

  static const String _boxName = 'unsynced_runs_v2';
  Box<String>? _box;
  bool _isSyncing = false;

  factory SyncQueueService({
    ApiClient? apiClient,
    TerritoryService? territoryService,
    Box<String>? overrideBox,
  }) {
    if (apiClient != null || territoryService != null || overrideBox != null) {
      return SyncQueueService.custom(
        apiClient: apiClient,
        territoryService: territoryService,
        overrideBox: overrideBox,
      );
    }
    return _instance;
  }

  SyncQueueService.custom({
    ApiClient? apiClient,
    TerritoryService? territoryService,
    Box<String>? overrideBox,
  })  : _apiClient = apiClient ?? ApiClient(),
        _territoryService = territoryService ?? TerritoryService(),
        _box = overrideBox {
    _initBox();
  }

  SyncQueueService._internal()
      : _apiClient = ApiClient(),
        _territoryService = TerritoryService() {
    _initBox();
  }

  Future<void> _initBox() async {
    if (_box == null && Hive.isBoxOpen(_boxName)) {
      _box = Hive.box<String>(_boxName);
    }
    _updateUnsettledCount();
  }

  Future<Box<String>> _getBox() async {
    if (_box != null && _box!.isOpen) return _box!;
    if (Hive.isBoxOpen(_boxName)) {
      _box = Hive.box<String>(_boxName);
      return _box!;
    }
    _box = await Hive.openBox<String>(_boxName);
    return _box!;
  }

  void _updateUnsettledCount() {
    final count = _box?.length ?? 0;
    unsettledCountNotifier.value = count;
    if (count == 0 && statusNotifier.value != SyncStatus.offline) {
      statusNotifier.value = SyncStatus.synced;
    } else if (count > 0 && statusNotifier.value != SyncStatus.syncing && statusNotifier.value != SyncStatus.offline) {
      statusNotifier.value = SyncStatus.pending;
    }
  }

  /// Enqueues a completed run and optionally triggers an opportunistic cloud upload
  Future<QueuedRun> enqueueRun({
    required List<LatLng> points,
    required int durationSeconds,
    required double distanceMeters,
    required double clientPreviewArea,
    required int clientPreviewXp,
    String? idempotencyKey,
    bool autoSync = true,
  }) async {
    final box = await _getBox();
    final key = idempotencyKey ?? _uuid.v4();

    final item = QueuedRun(
      idempotencyKey: key,
      points: points,
      durationSeconds: durationSeconds,
      distanceMeters: distanceMeters,
      clientPreviewArea: clientPreviewArea,
      clientPreviewXp: clientPreviewXp,
      createdAt: DateTime.now(),
    );

    await box.put(key, jsonEncode(item.toJson()));
    _updateUnsettledCount();

    // Trigger immediate background synchronization if requested
    if (autoSync) {
      unawaited(syncPendingRuns());
    }

    return item;
  }

  /// Attempts to upload all pending runs sequentially (FIFO by creation date)
  Future<bool> syncPendingRuns() async {
    if (_isSyncing) return false;
    _isSyncing = true;
    statusNotifier.value = SyncStatus.syncing;

    final box = await _getBox();
    if (box.isEmpty) {
      _isSyncing = false;
      statusNotifier.value = SyncStatus.synced;
      _updateUnsettledCount();
      return true;
    }

    // Retrieve and sort runs by chronological timestamp (FIFO)
    final List<QueuedRun> pending = [];
    for (final val in box.values) {
      try {
        final decoded = jsonDecode(val) as Map<String, dynamic>;
        pending.add(QueuedRun.fromJson(decoded));
      } catch (e) {
        debugPrint('[SyncQueueService] Corrupted queue entry: $e');
      }
    }
    pending.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    bool allSucceeded = true;

    for (final run in pending) {
      try {
        final serverResponse = await _apiClient.submitRun(
          idempotencyKey: run.idempotencyKey,
          points: run.points,
          durationSeconds: run.durationSeconds,
          distanceMeters: run.distanceMeters,
          clientPreviewArea: run.clientPreviewArea,
          clientPreviewXp: run.clientPreviewXp,
        );

        debugPrint('[SyncQueueService] Run ${run.idempotencyKey} successfully synced with backend!');

        // Authoritative Server Reconciliation:
        // Replace optimistic local Clipper2 territory with authoritative PostGIS MultiPolygon
        await _reconcileServerResponse(serverResponse);

        // Remove confirmed run from persistent queue
        await box.delete(run.idempotencyKey);
      } catch (e) {
        debugPrint('[SyncQueueService] Sync failed for ${run.idempotencyKey}: $e');
        allSucceeded = false;

        // Increment retry count
        final updatedRun = run.copyWith(retryCount: run.retryCount + 1);
        await box.put(run.idempotencyKey, jsonEncode(updatedRun.toJson()));
        break; // Stop sequential FIFO upload if backend is unreachable
      }
    }

    _isSyncing = false;
    _updateUnsettledCount();

    if (!allSucceeded) {
      statusNotifier.value = SyncStatus.offline;
      return false;
    } else {
      statusNotifier.value = SyncStatus.synced;
      return true;
    }
  }

  /// Updates local state with authoritative server calculations
  Future<void> _reconcileServerResponse(Map<String, dynamic> response) async {
    try {
      final double? serverTotalArea = (response['player_total_area_sqm'] as num?)?.toDouble();
      final String? geoJsonStr = response['territory_geojson'] as String?;

      if (geoJsonStr != null && geoJsonStr.isNotEmpty) {
        final geom = jsonDecode(geoJsonStr) as Map<String, dynamic>;
        final coordinates = geom['coordinates'] as List<dynamic>?;

        if (coordinates != null && coordinates.isNotEmpty) {
          final List<List<LatLng>> multiPolys = [];
          for (final poly in coordinates) {
            if (poly is List && poly.isNotEmpty) {
              final ring = poly.first as List<dynamic>;
              final ringPoints = <LatLng>[];
              for (final pt in ring) {
                if (pt is List && pt.length >= 2) {
                  ringPoints.add(LatLng((pt[1] as num).toDouble(), (pt[0] as num).toDouble()));
                }
              }
              if (ringPoints.isNotEmpty) {
                multiPolys.add(ringPoints);
              }
            }
          }

          if (multiPolys.isNotEmpty) {
            final profile = _territoryService.getProfile();
            final territoryId = 'poly_${profile.id}_territory';

            final authoritativeTerritory = Territory(
              id: territoryId,
              ownerId: profile.id,
              polygon: multiPolys.first,
              polygons: multiPolys,
              areaSqMeters: serverTotalArea ?? multiPolys.fold(0.0, (acc, p) => acc + p.length),
              capturedAt: DateTime.now(),
            );

            await _territoryService.saveTerritory(authoritativeTerritory);
            debugPrint('[SyncQueueService] Local territory reconciled to server authoritative MultiPolygon (${authoritativeTerritory.areaSqMeters.toStringAsFixed(1)} m²)');
          }
        }
      }
    } catch (e) {
      debugPrint('[SyncQueueService] Reconciliation error: $e');
    }
  }

  /// Clears the queue (useful for testing)
  Future<void> clearQueue() async {
    final box = await _getBox();
    await box.clear();
    _updateUnsettledCount();
    statusNotifier.value = SyncStatus.synced;
  }
}
