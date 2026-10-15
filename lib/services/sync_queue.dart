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

/// A run rejected by the authoritative backend with human-friendly reason
class RejectedRun {
  final QueuedRun run;
  final String code;
  final String rawMessage;
  final String humanReason;
  final DateTime rejectedAt;

  RejectedRun({
    required this.run,
    required this.code,
    required this.rawMessage,
    required this.humanReason,
    required this.rejectedAt,
  });

  Map<String, dynamic> toJson() => {
    'run': run.toJson(),
    'code': code,
    'rawMessage': rawMessage,
    'humanReason': humanReason,
    'rejectedAt': rejectedAt.toIso8601String(),
  };

  factory RejectedRun.fromJson(Map<String, dynamic> json) {
    return RejectedRun(
      run: QueuedRun.fromJson(json['run'] as Map<String, dynamic>),
      code: json['code'] as String? ?? 'REJECTED',
      rawMessage: json['rawMessage'] as String? ?? '',
      humanReason: json['humanReason'] as String? ?? 'Run rejected by server',
      rejectedAt: json['rejectedAt'] != null
          ? DateTime.parse(json['rejectedAt'] as String)
          : DateTime.now(),
    );
  }
}

/// Formats backend API rejection codes into clear, empathetic runner-facing messages
String formatRejectionReason(String code, String detail) {
  final lower = detail.toLowerCase();
  if (code == 'ANOMALY_REJECTED' ||
      lower.contains('anomaly') ||
      lower.contains('speed') ||
      lower.contains('teleport') ||
      lower.contains('spoof')) {
    return 'GPS anomaly detected — run rejected due to unrealistic speed or position jumps.';
  }
  if (code == 'INVALID_LOOP' || lower.contains('loop')) {
    if (lower.contains('too large') ||
        lower.contains('5000000') ||
        lower.contains('maximum')) {
      return 'Loop too large — exceeds maximum single-run limit (5 km²).';
    }
    if (lower.contains('crossed itself') || lower.contains('self-intersect')) {
      return 'Loop crossed itself — sovereign territory cannot self-intersect.';
    }
    if (lower.contains('perimeter') ||
        lower.contains('threshold') ||
        lower.contains('40')) {
      return 'Loop perimeter too small — minimum 40m required.';
    }
    return 'Invalid loop geometry — could not enclose valid sovereign territory.';
  }
  return detail.isNotEmpty ? detail : 'Run rejected by server rules.';
}

/// Offline-first synchronization queue backed by Hive
class SyncQueueService {
  static final SyncQueueService _instance = SyncQueueService._internal();

  final ApiClient _apiClient;
  final TerritoryService _territoryService;
  final Uuid _uuid = const Uuid();

  final ValueNotifier<SyncStatus> statusNotifier = ValueNotifier<SyncStatus>(SyncStatus.synced);
  final ValueNotifier<int> unsettledCountNotifier = ValueNotifier<int>(0);
  final ValueNotifier<RejectedRun?> lastRejectionNotifier = ValueNotifier<RejectedRun?>(null);
  final ValueNotifier<String?> reconciliationToastNotifier = ValueNotifier<String?>(null);

  static const String _boxName = 'unsynced_runs_v2';
  static const String _rejectedBoxName = 'rejected_runs_v1';
  Box<String>? _box;
  Box<String>? _rejectedBox;
  bool _isSyncing = false;

  /// Returns true for permanent 4xx failures that should not be retried.
  /// 408 (Timeout) and 429 (Rate Limit) are transient and eligible for retry.
  static bool isPermanentFailure(dynamic error) {
    if (error is ApiException) {
      if (error.statusCode >= 400 && error.statusCode < 500) {
        if (error.statusCode == 408 || error.statusCode == 429) {
          return false;
        }
        return true;
      }
    }
    return false;
  }

  factory SyncQueueService({
    ApiClient? apiClient,
    TerritoryService? territoryService,
    Box<String>? overrideBox,
    Box<String>? overrideRejectedBox,
  }) {
    if (apiClient != null || territoryService != null || overrideBox != null || overrideRejectedBox != null) {
      return SyncQueueService.custom(
        apiClient: apiClient,
        territoryService: territoryService,
        overrideBox: overrideBox,
        overrideRejectedBox: overrideRejectedBox,
      );
    }
    return _instance;
  }

  SyncQueueService.custom({
    ApiClient? apiClient,
    TerritoryService? territoryService,
    Box<String>? overrideBox,
    Box<String>? overrideRejectedBox,
  })  : _apiClient = apiClient ?? ApiClient(),
        _territoryService = territoryService ?? TerritoryService(),
        _box = overrideBox,
        _rejectedBox = overrideRejectedBox {
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
        await _reconcileServerResponse(serverResponse, run);

        // Remove confirmed run from persistent queue
        await box.delete(run.idempotencyKey);
      } catch (e) {
        if (isPermanentFailure(e)) {
          final apiErr = e as ApiException;
          final humanMsg = formatRejectionReason(apiErr.code, apiErr.message);
          debugPrint('[SyncQueueService] Run ${run.idempotencyKey} permanently rejected (${apiErr.code}): $humanMsg');

          final rejectedRun = RejectedRun(
            run: run,
            code: apiErr.code,
            rawMessage: apiErr.message,
            humanReason: humanMsg,
            rejectedAt: DateTime.now(),
          );

          // Archive rejected run and remove from pending queue to prevent infinite retry loops
          await box.delete(run.idempotencyKey);
          await _saveRejectedRun(rejectedRun);
          lastRejectionNotifier.value = rejectedRun;
          // Continue processing subsequent runs in queue
        } else {
          debugPrint('[SyncQueueService] Transient sync failure for ${run.idempotencyKey}: $e');
          allSucceeded = false;

          // Increment retry count
          final updatedRun = run.copyWith(retryCount: run.retryCount + 1);
          await box.put(run.idempotencyKey, jsonEncode(updatedRun.toJson()));
          break; // Stop sequential FIFO upload if backend is unreachable
        }
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

  /// Updates local state with authoritative server calculations and notifies on area discrepancies
  Future<void> _reconcileServerResponse(Map<String, dynamic> response, QueuedRun run) async {
    try {
      final double? serverClaimedArea = (response['area_claimed_sqm'] as num?)?.toDouble();
      final double clientPreview = run.clientPreviewArea;

      if (serverClaimedArea != null && clientPreview > 0) {
        final double delta = serverClaimedArea - clientPreview;
        if (delta.abs() >= 1.0) {
          if (delta > 0) {
            reconciliationToastNotifier.value =
                'Server verified +${delta.toStringAsFixed(1)} m² bonus (rival territory overtaken)';
          } else {
            reconciliationToastNotifier.value =
                'Server adjusted ${delta.toStringAsFixed(1)} m² (overlap with existing domain deducted)';
          }
        }
      }

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

  Future<Box<String>> _getRejectedBox() async {
    if (_rejectedBox != null && _rejectedBox!.isOpen) return _rejectedBox!;
    if (Hive.isBoxOpen(_rejectedBoxName)) {
      _rejectedBox = Hive.box<String>(_rejectedBoxName);
      return _rejectedBox!;
    }
    _rejectedBox = await Hive.openBox<String>(_rejectedBoxName);
    return _rejectedBox!;
  }

  Future<void> _saveRejectedRun(RejectedRun rejected) async {
    try {
      final box = await _getRejectedBox();
      await box.put(rejected.run.idempotencyKey, jsonEncode(rejected.toJson()));
    } catch (e) {
      debugPrint('[SyncQueueService] Could not persist rejected run: $e');
    }
  }

  /// Returns all permanently rejected runs for user inspection
  Future<List<RejectedRun>> getRejectedRuns() async {
    try {
      final box = await _getRejectedBox();
      return box.values
          .map((v) => RejectedRun.fromJson(jsonDecode(v) as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Clears the queue (useful for testing)
  Future<void> clearQueue() async {
    final box = await _getBox();
    await box.clear();
    _updateUnsettledCount();
    statusNotifier.value = SyncStatus.synced;
  }

  /// Clears the rejected runs archive
  Future<void> clearRejectedRuns() async {
    final box = await _getRejectedBox();
    await box.clear();
    lastRejectionNotifier.value = null;
  }
}
