import 'dart:async';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/sprite.dart';

import '../../flame_worldgen.dart';

class ProcedurallyGeneratedWorld extends World with HasGameReference {
  final ChunkManager chunkManager;
  final SpriteBatch tileSpriteBatch;
  final Rect Function(double noiseValue) tileSpriteSelector;

  late final StreamSubscription<void> _chunkUpdateSubscription;

  ProcedurallyGeneratedWorld({
    required this.chunkManager,
    required this.tileSpriteBatch,
    required this.tileSpriteSelector,
  });

  @override
  FutureOr<void> onLoad() async {
    await super.onLoad();
    _chunkUpdateSubscription = chunkManager.onChunkUpdate.listen(
      (_) => _onChunkUpdate(),
    );
  }

  @override
  Future<void> onRemove() async {
    await _chunkUpdateSubscription.cancel();
    chunkManager.dispose();
    super.onRemove();
  }

  @override
  void update(double dt) {
    super.update(dt);
    chunkManager.updateVisibleChunks(game.camera.viewfinder.position);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    tileSpriteBatch.render(canvas);
  }

  void _onChunkUpdate() {
    tileSpriteBatch.clear();
    for (final chunk in chunkManager.loadedChunks.values) {
      for (int col = 0; col < chunk.chunkSize.x; col++) {
        for (int row = 0; row < chunk.chunkSize.y; row++) {
          final noiseValue = chunk.getNoise(col, row);
          final tileWorldPosition = chunk.getTileWorldPosition(col, row);
          tileSpriteBatch.add(
            source: tileSpriteSelector(noiseValue),
            offset: tileWorldPosition,
          );
        }
      }
    }
  }
}
