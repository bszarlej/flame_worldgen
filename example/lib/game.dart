import 'dart:async';
import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/image_composition.dart';
import 'package:flame/sprite.dart';
import 'package:flame_worldgen/flame_worldgen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'debug_overlay.dart';
import 'minimap.dart';
import 'player.dart';
import 'prop.dart';

class FlameWorldgenExample extends FlameGame
    with HasKeyboardHandlerComponents, ScrollDetector, HasCollisionDetection {
  late final Player player;
  late final ChunkManager chunkManager;

  final _rng = Random();

  late final int seed;

  late final WeightedSpriteSelector propSelector;

  @override
  FutureOr<void> onLoad() async {
    await super.onLoad();
    await images.loadAllImages();

    seed = _rng.nextInt(0x80000000);

    chunkManager = ChunkManager(
      noise: PerlinFractalNoise(
        seed: seed,
        frequency: 0.0005,
        octaves: 5,
        lacunarity: 2.0,
      ),
      chunkSize: const Vector2i(16, 16),
      tileSize: const Vector2i(16, 16),
      viewDistance: 2,
      onChunkLoaded: _onChunkLoaded,
      onChunkUnloaded: _onChunkUnloaded,
    );

    final waterLayer = TileLayer(
      chunkManager: chunkManager,
      spriteBatch: SpriteBatch(images.fromCache('water.png')),
      config: TileLayerConfig(
        animationController: TileAnimationController(frameDuration: 0.3),
        spriteSelector: AnimatedSpriteSelector((noise, _) {
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
              weight: (noise, _) => noise > 0.0 ? 2 : 10,
            ),
            WeightedSprite.single(
              const Rect.fromLTWH(0, 80, 16, 16),
              weight: (noise, _) => 1.5,
            ),
            WeightedSprite.single(
              const Rect.fromLTWH(16, 80, 16, 16),
              weight: (noise, _) => 1.5,
            ),
            WeightedSprite.single(
              const Rect.fromLTWH(32, 80, 16, 16),
              weight: (noise, _) => .1,
            ),
            WeightedSprite.single(
              const Rect.fromLTWH(48, 80, 16, 16),
              weight: (noise, _) => .1,
            ),
            WeightedSprite.single(
              const Rect.fromLTWH(64, 80, 16, 16),
              weight: (noise, _) => .1,
            ),
            WeightedSprite.single(
              const Rect.fromLTWH(80, 80, 16, 16),
              weight: (noise, _) => .1,
            ),
            WeightedSprite.single(
              const Rect.fromLTWH(0, 96, 16, 16),
              weight: (noise, _) => .1,
            ),
            WeightedSprite.single(
              const Rect.fromLTWH(16, 96, 16, 16),
              weight: (noise, _) => .1,
            ),
            WeightedSprite.single(
              const Rect.fromLTWH(32, 96, 16, 16),
              weight: (noise, _) => .1,
            ),
            WeightedSprite.single(
              const Rect.fromLTWH(48, 96, 16, 16),
              weight: (noise, _) => .1,
            ),
            WeightedSprite.single(
              const Rect.fromLTWH(64, 96, 16, 16),
              weight: (noise, _) => .1,
            ),
            WeightedSprite.single(
              const Rect.fromLTWH(80, 96, 16, 16),
              weight: (noise, _) => .1,
            ),
          ],
          predicate: (noise, _) => noise > -.08,
        ),
      ),
      priority: -0x7FFFFFFF,
    );
    world.add(groundLayer);

    player = Player();
    world.add(player);

    camera = CameraComponent.withFixedResolution(width: 640, height: 360)
      ..follow(player, snap: true);

    camera.viewport.add(
      DebugOverlay(position: Vector2.all(8))
        ..textRenderer = TextPaint(
          style: const TextStyle(fontSize: 16, backgroundColor: Colors.black54),
        ),
    );

    const miniMapRadius = 48.0;
    const miniMapMargin = 16.0;
    final minimap = Minimap(
      world: world,
      radius: miniMapRadius,
      position: Vector2(
        size.x - miniMapRadius - miniMapMargin,
        miniMapRadius + miniMapMargin,
      ),
    );
    minimap.follow(player);
    camera.viewport.add(minimap);

    propSelector = WeightedSpriteSelector(
      options: PropType.values.map((e) => e.toWeightedSprite()).toList(),
      predicate: (noise, worldPos) {
        final rng = Random(worldPos.hashCode ^ seed);
        return noise > -0.07 && rng.nextDouble() < 0.25;
      },
    );
  }

  @override
  void onScroll(PointerScrollInfo info) {
    final newZoom = camera.viewfinder.zoom + info.scrollDelta.global.y * -0.001;
    camera.viewfinder.zoom = newZoom.clamp(0.1, 5.0);
  }

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    if (keysPressed.contains(LogicalKeyboardKey.numpadAdd)) {
      chunkManager.viewDistance++;
    } else if (keysPressed.contains(LogicalKeyboardKey.numpadSubtract)) {
      chunkManager.viewDistance--;
    }

    return super.onKeyEvent(event, keysPressed);
  }

  void _onChunkLoaded(Chunk chunk) {
    for (int col = 0; col < chunk.size.y; col++) {
      for (int row = 0; row < chunk.size.x; row++) {
        final noise = chunk.getNoise(col, row);
        final pos = chunk.getTileWorldPosition(col, row);
        final tileSize = chunk.tileSize.toVector2();
        final rng = Random(pos.hashCode ^ seed);
        final randomOffset = Vector2(
          rng.nextDouble() * tileSize.x,
          rng.nextDouble() * tileSize.y,
        );
        final propRect = propSelector.select(noise, 0, pos);
        if (propRect != null) {
          world.add(
            Prop(
              type: PropType.fromRect(propRect),
              position: pos.toVector2()..add(randomOffset),
            ),
          );
        }
      }
    }
  }

  void _onChunkUnloaded(Chunk chunk) {
    final props = world.children.whereType<Prop>();

    for (final prop in props) {
      if (chunk.worldRect.containsPoint(prop.position)) {
        prop.removeFromParent();
      }
    }
  }
}
