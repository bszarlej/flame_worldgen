import 'package:flame/extensions.dart';
import 'package:flame_worldgen/flame_worldgen.dart';
import 'package:test/test.dart';

void main() {
  group('Utility', () {
    test('world <-> chunk conversion works', () {
      const chunkWorldSize = Vector2i(32, 32);
      final worldPos = Vector2(192, 64);

      final chunkPos = worldToChunkPosition(worldPos, chunkWorldSize);

      expect(chunkPos, Vector2(6.0, 2.0));

      final result = chunkToWorldPosition(chunkPos, chunkWorldSize);

      expect(result.x, closeTo(worldPos.x, 1e-6));
      expect(result.y, closeTo(worldPos.y, 1e-6));
    });

    test('world <-> tile conversion works', () {
      const tileSize = Vector2i(16, 16);
      final worldPos = Vector2(208, 48);
      final tilePos = worldToTilePosition(worldPos, tileSize);
      final result = tileToWorldPosition(tilePos, tileSize);

      expect(result.x, closeTo(worldPos.x, 1e-6));
      expect(result.y, closeTo(worldPos.y, 1e-6));
    });
  });
}
