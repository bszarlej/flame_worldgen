import 'package:flame/extensions.dart';
import 'package:flame_procedural_generation/flame_procedural_generation.dart';
import 'package:test/test.dart';

void main() {
  group('Utility', () {
    test('pack and unpack key round trip', () {
      const x = 1234;
      const y = -5678;
      final packed = packKey(x, y);
      final point = unpackKey(packed);
      expect(point.x, equals(x));
      expect(point.y, equals(y));
    });

    test('world <-> chunk conversion works', () {
      const chunkWorldSize = (x: 32, y: 32);
      final worldPos = Vector2(192, 64);

      final chunkPos = worldToChunkPosition(worldPos, chunkWorldSize);

      expect(chunkPos, Vector2(6.0, 1.0));

      final result = chunkToWorldPosition(chunkPos, chunkWorldSize);

      expect(result.x, closeTo(worldPos.x, 1e-6));
      expect(result.y, closeTo(worldPos.y, 1e-6));
    });

    test('world <-> tile conversion works', () {
      const tileSize = (x: 16, y: 16);
      final worldPos = Vector2(208, 48);
      final tilePos = worldToTilePosition(worldPos, tileSize);
      final result = tileToWorldPosition(tilePos, tileSize);

      expect(result.x, closeTo(worldPos.x, 1e-6));
      expect(result.y, closeTo(worldPos.y, 1e-6));
    });
  });
}
