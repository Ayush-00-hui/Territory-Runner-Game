import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/utils/constants.dart';
import '../../../services/tile_cache_service.dart';
import '../../../ui/ui.dart';

void showOfflineMapsSheet(BuildContext context) {
  AppSheet.show(context: context, builder: (ctx) => const OfflineMapsSheet());
}

class OfflineMapsSheet extends StatefulWidget {
  const OfflineMapsSheet({super.key});

  @override
  State<OfflineMapsSheet> createState() => _OfflineMapsSheetState();
}

class _OfflineMapsSheetState extends State<OfflineMapsSheet> {
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
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
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
        AppToast.show(
          context,
          'Offline map cached. Added $newTiles map tiles.',
          type: AppToastType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDownloading = false);
        AppToast.show(
          context,
          'Could not download map area: $e',
          type: AppToastType.error,
        );
      }
    }
  }

  Future<void> _clearCache() async {
    await _cacheService.clearCache();
    await _refreshStats();
    if (mounted) {
      AppToast.show(context, 'Offline map cache purged.');
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
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.disabled,
                borderRadius: AppRadius.brFull,
              ),
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
                child: const Icon(
                  Icons.download_for_offline_rounded,
                  color: AppColors.accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.s10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Offline Map Storage',
                    style: AppText.headingSmall.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Offline trail navigation',
                    style: AppText.labelSmall.copyWith(
                      color: AppColors.accent,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.s14),
          Text(
            AppConstants.allowTilePrefetch
                ? 'Pre-download map areas to continue claiming territories, viewing boundaries, and navigating when running in dead zones or cellular outages.'
                : 'Map tiles viewed while exploring or running are automatically cached locally on your device for at least 7 days. Bulk area pre-downloading is disabled under the OpenStreetMap Tile Usage Policy.',
            style: AppText.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
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
                    Text(
                      'Cached Tiles',
                      style: AppText.labelSmall.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isLoading ? '...' : '$_tileCount',
                      style: AppText.statSmall.copyWith(
                        fontSize: 18,
                        color: AppColors.accent,
                        fontWeight: FontWeight.bold,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                Container(width: 1, height: 32, color: AppColors.border),
                Column(
                  children: [
                    Text(
                      'Disk Occupied',
                      style: AppText.labelSmall.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isLoading ? '...' : _formatSize(_cacheSizeBytes),
                      style: AppText.statSmall.copyWith(
                        fontSize: 18,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
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
                    const Text(
                      'Caching Map Tiles...',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _totalToDownload > 0
                          ? '$_downloaded / $_totalToDownload'
                          : 'Preparing...',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: _totalToDownload > 0
                      ? (_downloaded / _totalToDownload)
                      : null,
                  backgroundColor: AppColors.surface2,
                  color: AppColors.accent,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
              ],
            ),
          ],

          const SizedBox(height: AppSpacing.s20),

          // Action Buttons
          if (AppConstants.allowTilePrefetch) ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.onAccent,
                  shape: RoundedRectangleBorder(borderRadius: AppSpacing.br14),
                ),
                icon: const Icon(Icons.download_rounded, size: 20),
                label: const Text(
                  'Pre-cache current area (1.2 km)',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                onPressed: _isDownloading ? null : _preDownloadCurrentSector,
              ),
            ),
            const SizedBox(height: AppSpacing.s10),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.s12),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: AppSpacing.br12,
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.accent,
                    size: 18,
                  ),
                  const SizedBox(width: AppSpacing.s10),
                  Expanded(
                    child: Text(
                      'OSM Tile Usage Policy viewing cache active. Viewed areas remain cached offline.',
                      style: AppText.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s12),
          ],

          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(borderRadius: AppSpacing.br14),
              ),
              icon: const Icon(Icons.delete_sweep_rounded, size: 18),
              label: const Text(
                'Purge Offline Map Cache',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
              onPressed: (_tileCount == 0 || _isDownloading)
                  ? null
                  : _clearCache,
            ),
          ),
        ],
      ),
    );
  }
}
