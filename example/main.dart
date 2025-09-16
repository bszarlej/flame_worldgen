import 'dart:async';
import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/sprite.dart';
import 'package:flame_worldgen/flame_worldgen.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(GameWidget(game: FlameWorldgenGame()));
}

class FlameWorldgenGame extends FlameGame with HasKeyboardHandlerComponents {
  late final ChunkManager chunkManager;

  final _rng = Random();

  @override
  FutureOr<void> onLoad() async {
    await super.onLoad();
    await images.loadAllImages();

    final seed = _rng.nextInt(0x80000000);

    chunkManager = ChunkManager(
      noise: PerlinFractalNoise(
        seed: seed,
        frequency: 0.0005,
        octaves: 5,
        lacunarity: 2.0,
      ),
      chunkSize: const Vector2i(16, 16),
      tileSize: const Vector2i(16, 16),
      viewDistance: 4,
    );

    final waterLayer = TileLayer(
      chunkManager: chunkManager,
      spriteBatch: SpriteBatch(images.fromCache('water.png')),
      config: TileLayerConfig(
        animationController: TileAnimationController(frameDuration: 0.3),
        spriteSelector: AnimatedSpriteSelector((noise) {
          if (noise <= -0.08) {
            return [
              const Rect.fromLTWH(0, 0, 16, 16),
              const Rect.fromLTWH(16, 0, 16, 16),
              const Rect.fromLTWH(32, 0, 16, 16),
              const Rect.fromLTWH(48, 0, 16, 16),
            ];
          }
          return null;
        }),
      ),
      priority: -0x80000000,
    );
    world.add(waterLayer);

    final groundLayer = TileLayer(
      chunkManager: chunkManager,
      spriteBatch: SpriteBatch(images.fromCache('grass.png')),
      config: TileLayerConfig(
        animationController: TileAnimationController(frameDuration: 0.3),
        spriteSelector: WeightedSpriteSelector(
          options: [
            WeightedSprite.single(
              const Rect.fromLTWH(16, 16, 16, 16),
              weight: (noise) => noise > 0.0 ? 2 : 10,
            ),
            WeightedSprite.single(
              const Rect.fromLTWH(0, 80, 16, 16),
              weight: (noise) => 1.5,
            ),
            WeightedSprite.single(
              const Rect.fromLTWH(16, 80, 16, 16),
              weight: (noise) => 1.5,
            ),
            WeightedSprite.multi([
              const Rect.fromLTWH(32, 96, 16, 16),
              const Rect.fromLTWH(48, 96, 16, 16),
              const Rect.fromLTWH(64, 96, 16, 16),
              const Rect.fromLTWH(80, 96, 16, 16),
            ], weight: (noise) => .1),
          ],
          predicate: (noise) => noise > -.08,
        ),
      ),
      priority: -0x7FFFFFFF,
    );
    world.add(groundLayer);

    camera = CameraComponent.withFixedResolution(width: 640, height: 360);
  }
}
