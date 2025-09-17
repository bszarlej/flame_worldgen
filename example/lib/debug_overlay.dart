import 'dart:async';

import 'package:flame/components.dart';
import 'package:flame_worldgen/flame_worldgen.dart';

import 'game.dart';

class DebugOverlay extends TextComponent
    with HasGameReference<FlameWorldgenExample> {
  late final FpsComponent fpsComponent;

  DebugOverlay({super.position});

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    fpsComponent = FpsComponent();
    add(fpsComponent);
  }

  @override
  void update(double dt) {
    super.update(dt);
    final playerPosition = game.player.position;
    final chunkManager = game.chunkManager;
    final chunkPos = worldToChunkPosition(
      playerPosition,
      chunkManager.chunkWorldSize,
    );
    final tilePos = worldToTilePosition(playerPosition, chunkManager.tileSize);
    final tileLayers = game.world.children.whereType<TileLayer>();
    final totalTiles = tileLayers.fold(
      0,
      (prev, layer) => prev + layer.spriteBatch.sources.length,
    );
    text =
        '${fpsComponent.fps.toStringAsFixed(0)} FPS\n'
        'Chunk: ${chunkPos.x.toStringAsFixed(5)}, ${chunkPos.y.toStringAsFixed(5)}\n'
        'Tile: ${tilePos.x.toStringAsFixed(5)}, ${tilePos.y.toStringAsFixed(5)}\n'
        'World: ${playerPosition.x.toStringAsFixed(5)}, ${playerPosition.y.toStringAsFixed(5)}\n'
        'Chunks Total: ${chunkManager.loadedChunks.length}; Tiles Total: $totalTiles\n'
        'Components Total: ${game.world.children.length}';
  }
}
