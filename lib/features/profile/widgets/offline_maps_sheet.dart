import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../services/tile_cache_service.dart';
import '../../../ui/ui.dart';

void showOfflineMapsSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.bgElevated,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => const _OfflineMapsSheet(),
  );
}

class _OfflineMapsSheet extends StatefulWidget {
  const _OfflineMapsSheet();

  @override
  State<_OfflineMapsSheet> createState() => _OfflineMapsSheetState();
}

class _OfflineMapsSheetState extends State<_OfflineMapsSheet> {
  final TileCacheService _cacheService = TileCacheService();
  int _tileCount = 0;
  int _cacheSizeBytes = 0;
  bool _isLoading = true;
  bool _isDownloading = false;
  int _downloaded = 0;
  int _totalToDownload = 0;

  @override
  void initState() {
    super.initState();
    _refreshStats();
  }

  Future<void> _refreshStats() async {
    final count = await _cacheService.getCachedTileCount();
    final bytes = await _cacheService.getCacheSizeBytes();
    if (mounted) {
      setState(() {
        _tileCount = count;
        _cacheSizeBytes = bytes;
        _isLoading = false;
      });
    }
  }

  Future<void> _preDownloadCurrentSector() async {
    setState(() {
      _isDownloading = true;
      _downloaded = 0;
      _totalToDownload = 0;
    });

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );

      final center = LatLng(pos.latitude, pos.longitude);
      final newTiles = await _cacheService.preDownloadArea(
        center: center,
        radiusKm: 1.2,
        zoomLevels: [14, 15, 16],
        onProgress: (done, total) {
          if (mounted) {
            setState(() {
              _downloaded = done;
              _totalToDownload = total;
            });
          }
        },
      );

      await _refreshStats();
      if (mounted) {
        setState(() => _isDownloading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.surface,
            content: Text('Offline sector cached! Added $newTiles map tiles.', style: const TextStyle(color: AppColors.accent)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDownloading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not download sector: $e')),
        );
      }
    }
  }

  Future<void> _clearCache() async {
    await _cacheService.clearCache();
    await _refreshStats();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offline map cache purged.')),
      );
    }
  }

  String _formatSize(int bytes) {
    if (bytes >= 1048576) {
      return '${(bytes / 1048576.0).toStringAsFixed(1)} MB';
    } else if (bytes >= 1024) {
      return '${(bytes / 1024.0).toStringAsFixed(0)} KB';
    }
    return '$bytes B';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: AppSpacing.s16),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: AppSpacing.br10,
                ),
                child: const Icon(Icons.download_for_offline_rounded, color: AppColors.accent, size: 22),
              ),
              const SizedBox(width: AppSpacing.s10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'OFFLINE MAP STORAGE',
                    style: AppText.headingSmall.copyWith(fontSize: 15, fontWeight: FontWeight.w900),
                  ),
                  Text(
                    'ZERO-SIGNAL TACTICAL NAVIGATION',
                    style: AppText.label.copyWith(color: AppColors.accent, fontSize: 9.5),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.s14),
          Text(
            'Pre-download map sectors to continue claiming territories, viewing boundaries, and navigating when running in dead zones or cellular outages.',
            style: AppText.bodySmall.copyWith(color: AppColors.textSecondary, height: 1.35),
          ),
          const SizedBox(height: AppSpacing.s20),

          // Storage Metric Card
          Container(
            padding: const EdgeInsets.all(AppSpacing.s16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppSpacing.br16,
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text('CACHED TILES', style: AppText.label.copyWith(color: AppColors.textMuted, fontSize: 10)),
                    const SizedBox(height: 4),
                    Text(
                      _isLoading ? '...' : '$_tileCount',
                      style: AppText.statSmall.copyWith(fontSize: 18, color: AppColors.accent, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Container(width: 1, height: 32, color: AppColors.border),
                Column(
                  children: [
                    Text('DISK OCCUPIED', style: AppText.label.copyWith(color: AppColors.textMuted, fontSize: 10)),
                    const SizedBox(height: 4),
                    Text(
                      _isLoading ? '...' : _formatSize(_cacheSizeBytes),
                      style: AppText.statSmall.copyWith(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (_isDownloading) ...[
            const SizedBox(height: AppSpacing.s16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Caching Sector Tiles...', style: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.bold)),
                    Text(
                      _totalToDownload > 0 ? '$_downloaded / $_totalToDownload' : 'Preparing...',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: _totalToDownload > 0 ? (_downloaded / _totalToDownload) : null,
                  backgroundColor: AppColors.surface,
                  color: AppColors.accent,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
              ],
            ),
          ],

          const SizedBox(height: AppSpacing.s20),

          // Action Buttons
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: AppSpacing.br14),
              ),
              icon: const Icon(Icons.download_rounded, size: 20),
              label: const Text(
                'PRE-CACHE CURRENT SECTOR (1.2 KM)',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5),
              ),
              onPressed: _isDownloading ? null : _preDownloadCurrentSector,
            ),
          ),

          const SizedBox(height: AppSpacing.s10),

          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(borderRadius: AppSpacing.br14),
              ),
              icon: const Icon(Icons.delete_sweep_rounded, size: 18),
              label: const Text(
                'PURGE OFFLINE MAP CACHE',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
              ),
              onPressed: (_tileCount == 0 || _isDownloading) ? null : _clearCache,
            ),
          ),
        ],
      ),
    );
  }
}
