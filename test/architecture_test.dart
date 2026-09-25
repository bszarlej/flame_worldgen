@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Imports that would stop `lib/src/core` from running in an isolate, on the
/// web, or under plain `dart test`.
const _forbiddenImports = [
  'package:flame/',
  'package:flutter/',
  'dart:ui',
  'dart:io',
  'dart:isolate',
  'dart:html',
];

final _directive = RegExp(r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''');

void main() {
  test('lib/src/core only depends on pure, web-safe Dart', () {
    final core = Directory('lib/src/core');
    if (!core.existsSync()) return;

    final violations = <String>[];
    final files = core
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final uri = _directive.firstMatch(lines[i])?.group(1);
        if (uri == null) continue;

        final location = '${file.path}:${i + 1}';
        if (_forbiddenImports.any(uri.startsWith)) {
          violations.add('$location imports $uri');
        } else if (uri.startsWith('package:flame_worldgen/')) {
          violations.add('$location uses a package import: $uri');
        } else if (!uri.contains(':')) {
          final target = file.absolute.uri.resolve(uri).toString();
          if (!target.startsWith(core.absolute.uri.toString())) {
            violations.add('$location imports $uri from outside core');
          }
        }
      }
    }

    expect(violations, isEmpty);
  });
}
