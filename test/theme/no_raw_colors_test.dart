import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('No Color(0x or Colors.white outside lib/ui/theme (except designated migration list)', () {
    final libDir = Directory('lib');
    expect(libDir.existsSync(), isTrue, reason: 'lib directory must exist');

    final dartFiles = libDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

    // Zero files are whitelisted. All legacy colors have been completely migrated
    // to Charcoal + Ember semantic tokens across all phases (1-6).
    final allowedLegacyFiles = <String>{};

    final violations = <String>[];

    for (final file in dartFiles) {
      final normalizedPath = file.path.replaceAll('\\', '/');

      // Skip theme directory itself
      if (normalizedPath.startsWith('lib/ui/theme/')) {
        continue;
      }

      final lines = file.readAsLinesSync();
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        final lineNum = i + 1;

        if (line.contains('Colors.white') || line.contains('Color(0x')) {
          if (!allowedLegacyFiles.contains(normalizedPath)) {
            violations.add('$normalizedPath:$lineNum -> ${line.trim()}');
          }
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Raw Colors.white or Color(0x...) found in non-whitelisted files:\n${violations.join('\n')}',
    );
  });
}
