import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/leaderboard_entry.dart';
import '../models/runner_profile.dart';
import '../models/territory.dart';
import '../ui/theme/app_colors.dart';
import 'firebase_service.dart';

/// Exception thrown when API calls encounter unrecoverable network or server errors.
class ApiException implements Exception {
  final int statusCode;
  final String code;
  final String message;

  const ApiException({
    required this.statusCode,
    required this.code,
    required this.message,
  });

  @override
  String toString() => 'ApiException($statusCode, $code: $message)';
}

/// Service managing communication with the Go backend server.
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();

  final http.Client _httpClient;
  final FirebaseService _firebaseService;
  final String baseUrl;
  final int maxRetries;

  static String get defaultBaseUrl {
    if (kIsWeb) return 'http://localhost:8085';
    if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:8085';
    return 'http://localhost:8085';
  }

  factory ApiClient({
    http.Client? httpClient,
    FirebaseService? firebaseService,
    String? baseUrl,
    int maxRetries = 3,
  }) {
    if (httpClient != null || firebaseService != null || baseUrl != null || maxRetries != 3) {
      return ApiClient.custom(
        httpClient: httpClient,
        firebaseService: firebaseService,
        baseUrl: baseUrl,
        maxRetries: maxRetries,
      );
    }
    return _instance;
  }

  ApiClient.custom({
    http.Client? httpClient,
    FirebaseService? firebaseService,
    String? baseUrl,
    this.maxRetries = 3,
  })  : _httpClient = httpClient ?? http.Client(),
        _firebaseService = firebaseService ?? FirebaseService(),
        baseUrl = (baseUrl != null && baseUrl.isNotEmpty)
            ? baseUrl
            : const String.fromEnvironment('API_BASE_URL', defaultValue: '').isNotEmpty
                ? const String.fromEnvironment('API_BASE_URL')
                : defaultBaseUrl;

  ApiClient._internal()
      : _httpClient = http.Client(),
        _firebaseService = FirebaseService(),
        maxRetries = 3,
        baseUrl = const String.fromEnvironment('API_BASE_URL', defaultValue: '').isNotEmpty
            ? const String.fromEnvironment('API_BASE_URL')
            : defaultBaseUrl;

  /// Builds standard headers including Firebase ID token or dev header
  Future<Map<String, String>> _buildHeaders() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      final user = _firebaseService.currentUser;
      if (user != null) {
        final token = await user.getIdToken();
        if (token != null && token.isNotEmpty) {
          headers['Authorization'] = 'Bearer $token';
        }
      }
    } catch (e) {
      debugPrint('[ApiClient] Error fetching auth token: $e');
    }

    // Include dev user header for local Go testing in AUTH_MODE=dev
    headers['X-Dev-User'] = _firebaseService.currentUserId;

    return headers;
  }

  /// Executes an HTTP request with exponential backoff retry on transient failures
  Future<http.Response> _executeWithRetry(
    Future<http.Response> Function() requestFn, {
    int? maxRetries,
    Duration initialDelay = const Duration(milliseconds: 500),
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final retries = maxRetries ?? this.maxRetries;
    int attempts = 0;
    Duration delay = initialDelay;
    final random = math.Random();

    while (true) {
      attempts++;
      try {
        final response = await requestFn().timeout(timeout);
        // Only retry on transient 5xx server errors
        if (response.statusCode >= 500 && attempts <= retries) {
          debugPrint('[ApiClient] Server error ${response.statusCode}, retry $attempts/$retries');
        } else {
          return response;
        }
      } on Exception catch (e) {
        if (attempts > retries) {
          debugPrint('[ApiClient] Request failed after $attempts attempts: $e');
          rethrow;
        }
        debugPrint('[ApiClient] Transient failure ($e), retrying $attempts/$retries in ${delay.inMilliseconds}ms');
      }

      // Exponential backoff with jitter
      final jitterMs = random.nextInt(200);
      await Future.delayed(delay + Duration(milliseconds: jitterMs));
      delay *= 2;
    }
  }

  /// Checks server liveness (GET /healthz)
  Future<bool> checkHealth() async {
    try {
      final uri = Uri.parse('$baseUrl/healthz');
      final res = await _httpClient.get(uri).timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Submits a completed run to the server (POST /v1/runs)
  Future<Map<String, dynamic>> submitRun({
    required String idempotencyKey,
    required List<LatLng> points,
    required int durationSeconds,
    required double distanceMeters,
    double? clientPreviewArea,
    int? clientPreviewXp,
  }) async {
    final uri = Uri.parse('$baseUrl/v1/runs');
    final headers = await _buildHeaders();

    final now = DateTime.now();
    final body = jsonEncode({
      'idempotency_key': idempotencyKey,
      'duration_seconds': durationSeconds,
      'distance_meters': distanceMeters,
      'client_preview': {
        'area_claimed': clientPreviewArea ?? 0.0,
        'xp_awarded': clientPreviewXp ?? 0,
      },
      'points': points.asMap().entries.map((entry) {
        final idx = entry.key;
        final p = entry.value;
        return {
          'latitude': p.latitude,
          'longitude': p.longitude,
          'timestamp': now.add(Duration(seconds: idx)).toIso8601String(),
          'speed': 2.7,
          'heading': 0.0,
          'is_mocked': false,
        };
      }).toList(),
    });

    final response = await _executeWithRetry(
      () => _httpClient.post(uri, headers: headers, body: body),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    final errorBody = _parseError(response.body);
    throw ApiException(
      statusCode: response.statusCode,
      code: errorBody['error'] ?? 'SUBMIT_ERROR',
      message: errorBody['detail'] ?? 'Failed to submit run',
    );
  }

  /// Fetches runner profile (GET /v1/me)
  Future<RunnerProfile> getMe() async {
    final uri = Uri.parse('$baseUrl/v1/me');
    final headers = await _buildHeaders();

    final response = await _executeWithRetry(
      () => _httpClient.get(uri, headers: headers),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return RunnerProfile(
        id: data['id'] as String? ?? _firebaseService.currentUserId,
        username: data['username'] as String? ?? 'CyberRunner',
        faction: data['faction'] as String? ?? 'Cyber Vanguard',
        xp: (data['xp'] as num?)?.toInt() ?? 0,
        level: (data['level'] as num?)?.toInt() ?? 1,
        totalHexesClaimed: (data['total_runs'] as num?)?.toInt() ?? 0,
        totalDistanceKm: 0.0,
      );
    }

    final errorBody = _parseError(response.body);
    throw ApiException(
      statusCode: response.statusCode,
      code: errorBody['error'] ?? 'PROFILE_ERROR',
      message: errorBody['detail'] ?? 'Failed to fetch runner profile',
    );
  }

  /// Fetches territories in visible map bounding box (GET /v1/territories)
  Future<List<Territory>> getTerritoriesInBBox({
    required double minLng,
    required double minLat,
    required double maxLng,
    required double maxLat,
  }) async {
    final uri = Uri.parse('$baseUrl/v1/territories?bbox=$minLng,$minLat,$maxLng,$maxLat');
    final headers = await _buildHeaders();

    final response = await _executeWithRetry(
      () => _httpClient.get(uri, headers: headers),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final features = data['features'] as List<dynamic>? ?? [];

      final territories = <Territory>[];
      for (final f in features) {
        final feat = f as Map<String, dynamic>;
        final props = feat['properties'] as Map<String, dynamic>? ?? {};
        final geom = feat['geometry'] as Map<String, dynamic>?;

        final ownerId = props['owner_id'] as String? ?? 'unknown';
        final areaSqm = (props['area_sqm'] as num?)?.toDouble() ?? 0.0;
        final id = feat['id'] as String? ?? 'poly_${ownerId}_territory';

        List<List<LatLng>> multiPolys = [];
        if (geom != null && geom['coordinates'] is List) {
          final rawCoords = geom['coordinates'] as List<dynamic>;
          for (final poly in rawCoords) {
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
        }

        final isSelf = ownerId == _firebaseService.currentUserId;
        final color = isSelf ? AppColors.accent : AppColors.rival;

        territories.add(Territory(
          id: id,
          ownerId: ownerId,
          polygon: multiPolys.isNotEmpty ? multiPolys.first : [],
          polygons: multiPolys,
          areaSqMeters: areaSqm,
          capturedAt: DateTime.now(),
          color: color,
        ));
      }
      return territories;
    }

    final errorBody = _parseError(response.body);
    throw ApiException(
      statusCode: response.statusCode,
      code: errorBody['error'] ?? 'TERRITORY_ERROR',
      message: errorBody['detail'] ?? 'Failed to load territories',
    );
  }

  /// Fetches global leaderboard ranked by total captured territory area (GET /v1/leaderboard)
  Future<List<LeaderboardEntry>> getLeaderboard({int limit = 50}) async {
    final uri = Uri.parse('$baseUrl/v1/leaderboard?limit=$limit');
    final headers = await _buildHeaders();

    final response = await _executeWithRetry(
      () => _httpClient.get(uri, headers: headers),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final list = data['leaderboard'] as List<dynamic>? ?? [];
      return list.map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>)).toList();
    }

    final errorBody = _parseError(response.body);
    throw ApiException(
      statusCode: response.statusCode,
      code: errorBody['error'] ?? 'LEADERBOARD_ERROR',
      message: errorBody['detail'] ?? 'Failed to load leaderboard',
    );
  }

  /// Requests post-run coaching insight from backend Gemini proxy (POST /v1/runs/{id}/coach)
  Future<Map<String, dynamic>> getRunCoachInsight({
    required String runId,
    required double distanceKm,
    required int durationSeconds,
    required int hexesClaimed,
    String? currentPace,
    int? level,
    int? streakDays,
    double? totalDistanceKm,
  }) async {
    final uri = Uri.parse('$baseUrl/v1/runs/$runId/coach');
    final headers = await _buildHeaders();
    final body = jsonEncode({
      'distance_km': distanceKm,
      'duration_seconds': durationSeconds,
      'hexes_claimed': hexesClaimed,
      'current_pace': currentPace ?? '',
      'level': level ?? 1,
      'streak_days': streakDays ?? 0,
      'total_distance_km': totalDistanceKm ?? 0.0,
    });

    final response = await _executeWithRetry(
      () => _httpClient.post(uri, headers: headers, body: body),
      maxRetries: 0,
      timeout: const Duration(seconds: 2),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    final errorBody = _parseError(response.body);
    throw ApiException(
      statusCode: response.statusCode,
      code: errorBody['error'] ?? 'COACH_ERROR',
      message: errorBody['detail'] ?? 'Failed to get coach insight',
    );
  }

  Map<String, dynamic> _parseError(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return {'error': 'UNKNOWN', 'detail': body};
    }
  }
}
