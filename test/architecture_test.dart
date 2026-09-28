@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';

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

/// Imports that would stop `test/core` from compiling for
/// `dart test -p chrome`, which has no `dart:ui`.
const _forbiddenTestImports = [
  'package:flame/',
  'package:flame_test/',
  'package:flutter/',
  'package:flutter_test/',
  'package:flame_worldgen/flame_worldgen.dart',
  'dart:ui',
];

final _directive = RegExp(r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''');

/// Returns every import and export in the Dart files under [directory], as
/// (location, uri) pairs.
Iterable<(String, String, File)> _directives(Directory directory) sync* {
  final files = directory
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'));
  for (final file in files) {
    final lines = file.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      final uri = _directive.firstMatch(lines[i])?.group(1);
      if (uri != null) yield ('${file.path}:${i + 1}', uri, file);
    }
  }
}

void main() {
  test('lib/src/core only depends on pure, web-safe Dart', () {
    final core = Directory('lib/src/core');
    final violations = <String>[];

    for (final (location, uri, file) in _directives(core)) {
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

    expect(violations, isEmpty);
  });

  test('test/core does not need Flutter, so it can run on Chrome', () {
    final violations = [
      for (final (location, uri, _) in _directives(Directory('test/core')))
        if (_forbiddenTestImports.any(uri.startsWith)) '$location imports $uri',
    ];

    expect(violations, isEmpty);
  });
}
