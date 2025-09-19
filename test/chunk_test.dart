import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame_worldgen/flame_worldgen.dart';
import 'package:test/test.dart';

void main() {
  group('Chunk', () {
    final noise = PerlinNoise();

    test('generates consistent height map', () {
      final chunk = Chunk(
        noise: noise,
        coords: const Vector2i(0, 0),
        size: const Vector2i(4, 4),
        tileSize: const Vector2i(1, 1),
      );

      expect(chunk.heightMap.length, equals(16));
      final value = chunk.getNoise(2, 3);
      expect(value, isA<double>());
    });

    test('returns correct world and global tile coordinates', () {
      final chunk = Chunk(
        noise: noise,
        coords: const Vector2i(1, 1),
        size: const Vector2i(2, 2),
        tileSize: const Vector2i(16, 16),
      );

      final worldPos = chunk.getTileWorldPosition(1, 1);
      expect(worldPos, equals(const Vector2i(48, 48)));

      final global = chunk.getGlobalTileCoords(1, 1);
      expect(global, equals(const Vector2i(3, 3)));
    });

    test('correctly calculates worldSize, worldPosition and worldRect', () {
      final chunk = Chunk(
        noise: noise,
        coords: const Vector2i(3, 7),
        size: const Vector2i(8, 4),
        tileSize: const Vector2i(16, 16),
      );

      expect(chunk.worldPosition, equals(Vector2(384, 448)));
      expect(chunk.worldSize, equals(Vector2(128, 64)));
      expect(chunk.worldRect, equals(const Rect.fromLTWH(384, 448, 128, 64)));
    });
  });
}
