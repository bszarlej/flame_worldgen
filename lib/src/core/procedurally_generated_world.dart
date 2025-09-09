import 'dart:async';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/sprite.dart';

import '../../flame_worldgen.dart';

class ProcedurallyGeneratedWorld extends World with HasGameReference {
  final ChunkManager chunkManager;
  final SpriteBatch tileSpriteBatch;
  final Rect Function(double noiseValue) tileSpriteSelector;

  late final StreamSubscription<ChunkUpdateInfo> _chunkUpdateSubscription;

  final Map<Vector2i, int> _batchIndices = {};
  int _currentIndex = 0;

  ProcedurallyGeneratedWorld({
    required this.chunkManager,
    required this.tileSpriteBatch,
    required this.tileSpriteSelector,
  });

  @override
  FutureOr<void> onLoad() async {
    await super.onLoad();
    _chunkUpdateSubscription = chunkManager.onChunkUpdate.listen(
      _onChunkUpdate,
    );
  }

  @override
  Future<void> onRemove() async {
    await _chunkUpdateSubscription.cancel();
    await chunkManager.dispose();
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

  void _onChunkUpdate(ChunkUpdateInfo info) {
    final List<int> recycledIndices = [];

    for (final chunk in info.unloadedChunks) {
      for (int row = 0; row < chunk.chunkSize.y; row++) {
        for (int col = 0; col < chunk.chunkSize.x; col++) {
          final worldPos = chunk.getTileWorldPosition(col, row);
          final index = _batchIndices.remove(worldPos);
          if (index != null) recycledIndices.add(index);
        }
      }
    }

    for (final chunk in info.loadedChunks) {
      _processChunk(chunk, recycledIndices);
    }

    if (recycledIndices.isNotEmpty) {
      _rebuildBatch();
    }
  }

  void _processChunk(Chunk chunk, List<int> recycledIndices) {
    for (int row = 0; row < chunk.chunkSize.y; row++) {
      for (int col = 0; col < chunk.chunkSize.x; col++) {
        final worldPos = chunk.getTileWorldPosition(col, row);
        final noise = chunk.getNoise(col, row);
        final source = tileSpriteSelector(noise);
        _addOrUpdateTile(worldPos, source, recycledIndices);
      }
    }
  }

  void _addOrUpdateTile(
    Vector2i worldPos,
    Rect source,
    List<int> recycledIndices,
  ) {
    final transform = RSTransform.fromComponents(
      rotation: 0,
      scale: 1.0,
      anchorX: 0,
      anchorY: 0,
      translateX: worldPos.x.toDouble(),
      translateY: worldPos.y.toDouble(),
    );

    int index;
    if (recycledIndices.isNotEmpty) {
      index = recycledIndices.removeLast();
      tileSpriteBatch.replace(index, source: source, transform: transform);
    } else {
      tileSpriteBatch.addTransform(source: source, transform: transform);
      index = _currentIndex++;
    }

    _batchIndices[worldPos] = index;
  }

  void _rebuildBatch() {
    tileSpriteBatch.clear();
    _batchIndices.clear();
    _currentIndex = 0;

    for (final chunk in chunkManager.loadedChunks.values) {
      _processChunk(chunk, []);
    }
  }
}
