import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';

/// A calm, athletic, or biomechanical fact or quote displayed during loading.
class RunningQuote {
  final String text;
  final String author;

  const RunningQuote({
    required this.text,
    required this.author,
  });

  factory RunningQuote.fromJson(Map<String, dynamic> json) {
    return RunningQuote(
      text: json['text'] as String? ?? '',
      author: json['author'] as String? ?? 'Anonymous',
    );
  }
}

/// Service that loads and delivers runner quotes and facts for loading states.
class LoadingQuotesService {
  static final LoadingQuotesService instance = LoadingQuotesService._();

  LoadingQuotesService._();

  List<RunningQuote>? _cachedQuotes;
  final Random _rng = Random();

  /// Default fallback quotes available synchronously before asset load.
  static const List<RunningQuote> _fallbackQuotes = [
    RunningQuote(
      text: 'Every running step exerts impact forces between two to three times your body weight onto the lower limbs.',
      author: 'Sports Biomechanics',
    ),
    RunningQuote(
      text: 'The human Achilles tendon functions like a biological spring, returning over ninety percent of stored elastic energy.',
      author: 'Comparative Biomechanics',
    ),
    RunningQuote(
      text: 'A step cadence near 170 to 180 strides per minute naturally minimizes braking forces upon foot contact.',
      author: 'Locomotion Research',
    ),
    RunningQuote(
      text: 'Running economy measures the volume of oxygen required to maintain a specific steady-state running speed.',
      author: 'Exercise Physiology',
    ),
    RunningQuote(
      text: 'Roger Bannister broke the four-minute mile barrier on May 6, 1954, clocking 3:59.4 at Iffley Road, Oxford.',
      author: 'Athletics History',
    ),
    RunningQuote(
      text: 'Most runners run their easy days too hard, and their hard days too easy.',
      author: 'Arthur Lydiard',
    ),
    RunningQuote(
      text: 'Negative splits—running the second half faster than the first—is the strategy behind nearly every distance world record.',
      author: 'Pacing Science',
    ),
    RunningQuote(
      text: 'Lactate is not a waste product, but a vital aerobic fuel recycled continuously by your heart and active muscles.',
      author: 'Cellular Metabolism',
    ),
  ];

  /// Asynchronously loads quotes from `assets/loading_quotes.json`.
  Future<List<RunningQuote>> loadQuotes({AssetBundle? bundle}) async {
    if (_cachedQuotes != null && _cachedQuotes!.isNotEmpty) {
      return _cachedQuotes!;
    }

    try {
      final assetBundle = bundle ?? rootBundle;
      final rawString = await assetBundle.loadString('assets/loading_quotes.json');
      final dynamic decoded = jsonDecode(rawString);
      if (decoded is List) {
        _cachedQuotes = decoded
            .whereType<Map<String, dynamic>>()
            .map((item) => RunningQuote.fromJson(item))
            .where((q) => q.text.isNotEmpty)
            .toList();
      }
    } catch (_) {
      // Fallback silently if assets cannot be read in a test or headless shell.
    }

    if (_cachedQuotes == null || _cachedQuotes!.isEmpty) {
      _cachedQuotes = List<RunningQuote>.from(_fallbackQuotes);
    }

    return _cachedQuotes!;
  }

  /// Returns a quote synchronously, prioritizing cached quotes with fallback.
  RunningQuote getQuote({int? index}) {
    final pool = (_cachedQuotes != null && _cachedQuotes!.isNotEmpty)
        ? _cachedQuotes!
        : _fallbackQuotes;

    if (index != null && index >= 0 && index < pool.length) {
      return pool[index];
    }

    return pool[_rng.nextInt(pool.length)];
  }

  /// For unit testing: sets specific quote pool.
  void setQuotesForTesting(List<RunningQuote>? quotes) {
    _cachedQuotes = quotes;
  }
}

