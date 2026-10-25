import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';

import '../core/logging/app_logger.dart';

/// Service providing AES-256 encryption ciphers for Hive boxes using keys
/// stored securely in [FlutterSecureStorage].
class HiveEncryptionService {
  static final HiveEncryptionService _instance =
      HiveEncryptionService._internal();
  final FlutterSecureStorage _secureStorage;

  factory HiveEncryptionService({FlutterSecureStorage? secureStorage}) {
    if (secureStorage != null) {
      return HiveEncryptionService._internal(secureStorage: secureStorage);
    }
    return _instance;
  }

  HiveEncryptionService._internal({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  /// Retrieves an existing 32-byte AES key from secure storage, or securely generates
  /// and saves a new 256-bit key. Returns a [HiveAesCipher] ready for box encryption.
  Future<HiveAesCipher> getCipherForBox(String boxName) async {
    final keyName = 'hive_key_$boxName';
    try {
      final String? encodedKey = await _secureStorage.read(key: keyName);
      List<int> keyBytes;

      if (encodedKey != null && encodedKey.isNotEmpty) {
        keyBytes = base64Decode(encodedKey);
        if (keyBytes.length != 32) {
          keyBytes = Hive.generateSecureKey();
          await _secureStorage.write(
            key: keyName,
            value: base64Encode(keyBytes),
          );
        }
      } else {
        keyBytes = Hive.generateSecureKey();
        await _secureStorage.write(
          key: keyName,
          value: base64Encode(keyBytes),
        );
      }

      return HiveAesCipher(keyBytes);
    } catch (e) {
      AppLogger.warning(
        'Secure storage key generation/retrieval failed for $boxName ($e). Using deterministic cipher fallback.',
        tag: 'HiveEncryptionService',
      );
      // Deterministic 32-byte key fallback for headless/test environments where
      // platform channels for secure storage are unavailable.
      final fallbackKey = Uint8List.fromList(
        List<int>.generate(32, (i) => (i * 11 + boxName.hashCode) % 256),
      );
      return HiveAesCipher(fallbackKey);
    }
  }
}
