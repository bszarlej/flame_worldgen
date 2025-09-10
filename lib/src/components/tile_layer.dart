import 'dart:async';

import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/widgets.dart';

import '../core/chunk.dart';
import '../core/chunk_manager.dart';
import '../math/vector2i.dart';

abstract class TileLayer extends Component with HasGameReference {
  final ChunkManager chunkManager;
  final SpriteBatch spriteBatch;
  final Vector2 Function()? centerPositionProvider;

  @protected
  final Map<Vector2i, int> batchIndices = {};

  int _currentIndex = 0;
  late final StreamSubscription<ChunkUpdateInfo> _chunkUpdateSubscription;

  TileLayer({
    required this.chunkManager,
    required this.spriteBatch,
    this.centerPositionProvider,
    super.children,
    super.key,
    super.priority,
  });

  @override
  @mustCallSuper
  Future<void> onLoad() async {
    await super.onLoad();
    _chunkUpdateSubscription = chunkManager.onChunkUpdate.listen(
      (info) => _onChunkUpdate(info),
    );
  }

  @override
  @mustCallSuper
  void update(double dt) {
    super.update(dt);
    final centerPosition =
        centerPositionProvider?.call() ?? game.camera.viewfinder.position;

    chunkManager.updateVisibleChunks(centerPosition);
  }

  @override
  @mustCallSuper
  void render(Canvas canvas) {
    super.render(canvas);
    spriteBatch.render(canvas);
  }

  @override
  @mustCallSuper
  Future<void> onRemove() async {
    await _chunkUpdateSubscription.cancel();
    super.onRemove();
  }

  /// SpriteLayer child classes implement how a sprite is selected for each tile
  Rect? selectSprite(double noiseValue, [int frame = 0]);

  /// Called whenever chunks are updated
  void _onChunkUpdate(ChunkUpdateInfo info) {
    final List<int> recycledIndices = [];

    for (final chunk in info.unloadedChunks) {
      for (int row = 0; row < chunk.chunkSize.y; row++) {
        for (int col = 0; col < chunk.chunkSize.x; col++) {
          final worldPos = chunk.getTileWorldPosition(col, row);
          final index = batchIndices.remove(worldPos);
          if (index != null) recycledIndices.add(index);
        }
      }
    }

    for (final chunk in info.loadedChunks) {
      processChunk(chunk, recycledIndices);
    }

    if (recycledIndices.isNotEmpty) {
      _rebuildBatch();
    }
  }

  void _rebuildBatch() {
    spriteBatch.clear();
    batchIndices.clear();
    _currentIndex = 0;

    for (final chunk in chunkManager.loadedChunks.values) {
      processChunk(chunk, []);
    }
  }

  @protected
  void processChunk(Chunk chunk, List<int> recycledIndices) {
    for (int row = 0; row < chunk.chunkSize.y; row++) {
      for (int col = 0; col < chunk.chunkSize.x; col++) {
        final worldPos = chunk.getTileWorldPosition(col, row);
        final noise = chunk.getNoise(col, row);
        final source = selectSprite(noise);
        if (source != null) {
          addOrUpdateTile(worldPos, source, recycledIndices);
        }
      }
    }
  }

  @protected
  void addOrUpdateTile(
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
      spriteBatch.replace(index, source: source, transform: transform);
    } else {
      spriteBatch.addTransform(source: source, transform: transform);
      index = _currentIndex++;
    }

    batchIndices[worldPos] = index;
  }
}
