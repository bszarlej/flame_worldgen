import 'package:fast_noise/fast_noise.dart';
import 'package:flame/components.dart';
import 'package:flame_procedural_generation/src/chunk_manager.dart';
import 'package:flutter/material.dart';

class ProceduralWorld2D extends World {
  final Noise2 noise;
  final ChunkManager chunkManager;
  final PositionComponent Function(Vector2 position, double noiseValue)
  tileMapper;

  ProceduralWorld2D({
    required this.noise,
    required this.chunkManager,
    required this.tileMapper,
  });

  void updatePlayerPosition(Vector2 position) {
    chunkManager.update(position);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    for (final chunk in chunkManager.loadedChunks.values) {
      for (int x = 0; x < chunk.tileCount.x; x++) {
        for (int y = 0; y < chunk.tileCount.y; y++) {
          final globalPosition = chunk.getGlobalTilePosition(x, y);
          final noiseValue = noise.getNoise2(
            globalPosition.x,
            globalPosition.y,
          );
          canvas.drawRect(
            Rect.fromLTWH(globalPosition.x, globalPosition.y, 16, 16),
            Paint()
              ..color = Color.fromARGB(
                255,
                (noiseValue * 255).toInt().abs(),
                (noiseValue * 255).toInt().abs(),
                (noiseValue * 255).toInt().abs(),
              ),
          );
        }
      }
    }
  }
}
