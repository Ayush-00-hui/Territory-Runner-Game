import 'dart:typed_data';

import 'package:gal/gal.dart';

import '../core/logging/app_logger.dart';

/// Result wrapper returned by [GallerySaverService.savePng].
class GallerySaveResult {
  final bool success;
  final String message;

  const GallerySaveResult({required this.success, required this.message});
}

/// Service managing image export directly into the device's public photo gallery.
class GallerySaverService {
  static final GallerySaverService _instance = GallerySaverService._internal();
  factory GallerySaverService() => _instance;

  GallerySaverService._internal();

  /// Saves PNG image bytes into the 'Territory Runner' photo album.
  /// Checks and requests necessary album permissions before writing.
  Future<GallerySaveResult> savePng(Uint8List bytes) async {
    try {
      final bool hasAccess = await Gal.hasAccess(toAlbum: true);
      if (!hasAccess) {
        final bool granted = await Gal.requestAccess(toAlbum: true);
        if (!granted) {
          return const GallerySaveResult(
            success: false,
            message: 'Gallery write permission denied',
          );
        }
      }

      await Gal.putImageBytes(bytes, album: 'Territory Runner');
      return const GallerySaveResult(
        success: true,
        message: 'Saved to gallery album "Territory Runner"',
      );
    } catch (e) {
      AppLogger.warning('Gallery save error: $e', tag: 'GallerySaverService');
      return GallerySaveResult(
        success: false,
        message: 'Failed to save image to gallery: $e',
      );
    }
  }
}
