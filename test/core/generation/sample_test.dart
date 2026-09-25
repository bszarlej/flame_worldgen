import 'package:flame_worldgen/src/core/coords.dart';
import 'package:flame_worldgen/src/core/generation/sample.dart';
import 'package:flame_worldgen/src/core/noise/noise_field.dart';
import 'package:test/test.dart';

void main() {
  final grid = ChunkGrid(16);
  final elevation = NoiseField.fbm('elevation', frequency: 0.05, octaves: 3);
  final moisture = NoiseField.simplex('moisture', frequency: 0.1);

  test('matches sampling each field directly, in every tile', () {
    final fields = ChunkFields([elevation, moisture], 42, grid);
    final elevationAt = elevation.sampler(42);
    final moistureAt = moisture.sampler(42);

    for (final chunk in const [ChunkCoord(0, 0), ChunkCoord(-3, 2)]) {
      fields.evaluate(chunk);
      for (var index = 0; index < grid.area; index++) {
        fields.moveTo(index);
        final tile = grid.tileAt(chunk, index);
        final x = tile.x.toDouble();
        final y = tile.y.toDouble();
        expect(fields.sample.coord, tile);
        expect(fields.sample[elevation], elevationAt(x, y));
        expect(fields.sample[moisture], moistureAt(x, y));
      }
    }
  });

  test('reusing the buffers for another chunk leaves nothing behind', () {
    final fields = ChunkFields([elevation], 42, grid);
    fields.evaluate(const ChunkCoord(5, 5));
    fields.evaluate(const ChunkCoord(0, 0));
    final fresh = ChunkFields([elevation], 42, grid)
      ..evaluate(const ChunkCoord(0, 0));

    for (var index = 0; index < grid.area; index++) {
      fields.moveTo(index);
      fresh.moveTo(index);
      expect(fields.sample[elevation], fresh.sample[elevation]);
    }
  });

  test('the world seed changes the values', () {
    final a = ChunkFields([elevation], 1, grid)
      ..evaluate(const ChunkCoord(0, 0))
      ..moveTo(0);
    final b = ChunkFields([elevation], 2, grid)
      ..evaluate(const ChunkCoord(0, 0))
      ..moveTo(0);
    expect(a.sample[elevation], isNot(b.sample[elevation]));
  });

  test('throws for fields the generator does not know', () {
    final fields = ChunkFields([elevation], 42, grid)
      ..evaluate(const ChunkCoord(0, 0));
    expect(
      () => fields.sample[moisture],
      throwsA(
        isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('WorldGenerator(fields:'),
        ),
      ),
    );
  });

  test('allows the same field twice', () {
    expect(
      () => ChunkFields([elevation, elevation], 42, grid),
      returnsNormally,
    );
  });

  test('rejects different fields with the same name', () {
    expect(
      () => ChunkFields([elevation, NoiseField.perlin('elevation')], 42, grid),
      throwsArgumentError,
    );
  });
}
