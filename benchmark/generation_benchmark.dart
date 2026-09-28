// ignore_for_file: avoid_print

// Measures how long generating one chunk takes.
//
// On the VM:
//   dart run benchmark/generation_benchmark.dart
//
// As JavaScript, as on the web:
//   dart compile js -O2 -o build/benchmark.js benchmark/generation_benchmark.dart
//   node build/benchmark.js

import 'package:flame_worldgen/src/core/core.dart';

const _water = TileType('water', solid: true);
const _sand = TileType('sand');
const _grass = TileType('grass');
const _forest = TileType('forest floor');
const _stone = TileType('stone', solid: true);
const _dirt = TileType('dirt');

// Three fields, like a typical game: one with octaves, one warped.
final _elevation = NoiseField.fbm('elevation', frequency: 0.01, octaves: 5);
final _moisture = NoiseField.simplex(
  'moisture',
  frequency: 0.02,
  warp: const DomainWarp(strength: 20),
);
final _temperature = NoiseField.perlin('temperature', frequency: 0.005);

final _generator = WorldGenerator(
  fields: [_elevation, _moisture, _temperature],
  biomes: [
    Biome('ocean', ground: _water, when: (s) => s[_elevation] < -0.05),
    Biome('beach', ground: _sand, when: (s) => s[_elevation] < 0.02),
    Biome(
      'mountains',
      ground: _stone,
      when: (s) => s[_elevation] > 0.35,
      scatter: const [ScatterRule('rocks', density: 0.05, minDistance: 2)],
    ),
    Biome(
      'forest',
      ground: _forest,
      when: (s) => s[_moisture] > 0.2 && s[_temperature] > -0.3,
      scatter: const [ScatterRule('trees', density: 0.15, minDistance: 1.5)],
    ),
    const Biome(
      'plains',
      ground: _grass,
      scatter: [ScatterRule('bushes', density: 0.02, minDistance: 3)],
    ),
  ],
  passes: const [_RoadPass()],
);

class _RoadPass extends GenerationPass {
  const _RoadPass();

  @override
  void apply(ChunkBuilder chunk) {
    for (final coord in chunk.coords) {
      final biome = chunk.biomeAt(coord).name;
      if (coord.y % 64 == 0 && (biome == 'plains' || biome == 'forest')) {
        chunk.setTile(coord, _dirt);
      }
    }
  }
}

void main() {
  const chunkSize = 32;
  final grid = ChunkGrid(chunkSize);
  final chunks = ChunkGenerator(
    _generator,
    seed: 42,
    grid: grid,
    tiles: const [_dirt],
  );
  final fields = ChunkFields(_generator.fields, 42, grid);

  // Warm up, so the VM's and the JS engine's compilers are done.
  _run(20, (coord) => chunks.generate(coord), offset: 1000);

  final fieldTimes = _run(50, fields.evaluate);
  final chunkTimes = _run(50, (coord) => chunks.generate(coord));

  print('$chunkSize × $chunkSize chunks, ${_generator.fields.length} fields');
  print('fields only:  ${_summary(fieldTimes)}');
  print('whole chunk:  ${_summary(chunkTimes)}');
  print('checksum:     ${_checksum(chunks)}');
}

/// A hash of some generated chunks, which must be the same on every
/// platform.
String _checksum(ChunkGenerator chunks) {
  var checksum = 0;
  for (var y = -2; y <= 2; y++) {
    for (var x = -2; x <= 2; x++) {
      final chunk = chunks.generate(ChunkCoord(x, y));
      for (var i = 0; i < chunk.tiles.length; i++) {
        checksum = hash3(checksum, chunk.tiles[i], chunk.biomes[i], 0);
      }
      for (final spot in chunk.spots) {
        checksum = hash3(checksum, spot.cellX, spot.cellY, spot.ruleIndex);
      }
    }
  }
  return checksum.toRadixString(16).padLeft(8, '0');
}

/// Runs [body] for [batches] batches of 10 different chunks and returns the
/// average time per chunk of each batch, in microseconds.
///
/// Batches, because compiled to JavaScript the stopwatch may only count whole
/// milliseconds.
List<double> _run(
  int batches,
  void Function(ChunkCoord) body, {
  int offset = 0,
}) {
  const batchSize = 10;
  final times = <double>[];
  final stopwatch = Stopwatch();
  for (var batch = 0; batch < batches; batch++) {
    stopwatch
      ..reset()
      ..start();
    for (var i = 0; i < batchSize; i++) {
      // A 25-chunk-wide block, so every chunk is a different one.
      final n = batch * batchSize + i;
      body(ChunkCoord(offset + n % 25 - 12, n ~/ 25 - 10));
    }
    stopwatch.stop();
    times.add(stopwatch.elapsedMicroseconds / batchSize);
  }
  return times;
}

String _summary(List<double> micros) {
  final sorted = [...micros]..sort();
  String ms(double us) => '${(us / 1000).toStringAsFixed(2)} ms';
  final mean = sorted.reduce((a, b) => a + b) / sorted.length;
  final median = sorted[sorted.length ~/ 2];
  return 'mean ${ms(mean)}, median ${ms(median)}, '
      'slowest batch ${ms(sorted.last)} per chunk';
}
