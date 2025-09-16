import 'package:flame_worldgen/flame_worldgen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StaticSpriteSelector', () {
    test('returns correct rect for given noise', () {
      final selector = StaticSpriteSelector((noise) {
        if (noise > 0.5) {
          return const Rect.fromLTWH(0, 0, 16, 16);
        }
        return null;
      });

      expect(
        selector.select(0.6, 0, const Vector2i(0, 0)),
        const Rect.fromLTWH(0, 0, 16, 16),
      );
      expect(selector.select(0.4, 0, const Vector2i(0, 0)), isNull);
    });
  });

  group('AnimatedSpriteSelector', () {
    test('cycles through frames correctly', () {
      final frames = [
        const Rect.fromLTWH(0, 0, 16, 16),
        const Rect.fromLTWH(16, 0, 16, 16),
      ];

      final selector = AnimatedSpriteSelector((_) => frames);

      // frame 0 → first rect
      expect(selector.select(0.5, 0, const Vector2i(0, 0)), frames[0]);

      // frame 1 → second rect
      expect(selector.select(0.5, 1, const Vector2i(0, 0)), frames[1]);

      // frame 2 → wrap back to first
      expect(selector.select(0.5, 2, const Vector2i(0, 0)), frames[0]);
    });

    test('returns null when no frames available', () {
      final selector = AnimatedSpriteSelector((_) => []);
      expect(selector.select(0.5, 0, const Vector2i(0, 0)), isNull);
    });
  });

  group('WeightedSpriteSelector', () {
    test('selects based on weights deterministically by worldPos', () {
      final options = [
        WeightedSprite.single(
          const Rect.fromLTWH(0, 0, 16, 16),
          weight: (_) => 0.7,
        ),
        WeightedSprite.single(
          const Rect.fromLTWH(16, 0, 16, 16),
          weight: (_) => 0.3,
        ),
      ];

      final selector = WeightedSpriteSelector(
        options: options,
        predicate: (_) => true,
      );

      // Because Random(worldPos.hashCode) is seeded,
      // the same worldPos should always yield the same result.
      const pos = Vector2i(1, 1);
      final rect1 = selector.select(0.5, 0, pos);
      final rect2 = selector.select(0.5, 1, pos);

      expect(rect1, isNotNull);
      expect(rect1, rect2); // deterministic per worldPos
    });

    test('returns null if predicate fails', () {
      final selector = WeightedSpriteSelector(
        options: [
          WeightedSprite.single(
            const Rect.fromLTWH(0, 0, 16, 16),
            weight: (_) => 1.0,
          ),
        ],
        predicate: (_) => false,
      );

      expect(selector.select(0.5, 0, const Vector2i(0, 0)), isNull);
    });

    test('respects noise-dependent weights', () {
      final selector = WeightedSpriteSelector(
        options: [
          WeightedSprite.single(
            const Rect.fromLTWH(0, 0, 16, 16),
            weight: (noise) => noise > 0 ? 1.0 : 0.0,
          ),
          WeightedSprite.single(
            const Rect.fromLTWH(16, 0, 16, 16),
            weight: (noise) => noise > 0 ? 0.0 : 1.0,
          ),
        ],
        predicate: (_) => true,
      );

      const rectPos = Vector2i(5, 5);

      // noise > 0 → first rect
      expect(
        selector.select(1.0, 0, rectPos),
        const Rect.fromLTWH(0, 0, 16, 16),
      );

      // noise <= 0 → second rect
      expect(
        selector.select(-1.0, 0, rectPos),
        const Rect.fromLTWH(16, 0, 16, 16),
      );
    });
  });
}
