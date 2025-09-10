import 'package:flame/components.dart';
import 'package:flutter/widgets.dart';

import '../core/chunk.dart';
import 'tile_layer.dart';

class AnimatedTileLayer extends TileLayer {
  final Rect? Function(double noiseValue, int frame) spriteSelector;
  final int frameCount;
  final double frameDuration;

  final Map<int, double> _tileNoiseValues = {};
  late final Timer _timer;
  int _currentFrame = 0;

  AnimatedTileLayer({
    required super.chunkManager,
    required super.spriteBatch,
    required this.spriteSelector,
    required this.frameCount,
    required this.frameDuration,
    super.centerPositionProvider,
    super.children,
    super.key,
    super.priority,
  });

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _timer = Timer(frameDuration, repeat: true, onTick: _updateAnimations)
      ..start();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _timer.update(dt);
  }

  @override
  Future<void> onRemove() {
    _timer.stop();
    return super.onRemove();
  }

  @override
  Rect? selectSprite(double noiseValue, [int frame = 0]) {
    return spriteSelector(noiseValue, frame);
  }

  void _updateAnimations() {
    _currentFrame = (_currentFrame + 1) % frameCount;

    for (final entry in _tileNoiseValues.entries) {
      final index = entry.key;
      final noise = entry.value;
      final source = spriteSelector(noise, _currentFrame);
      if (source != null) spriteBatch.replace(index, source: source);
    }
  }

  @override
  void processChunk(Chunk chunk, List<int> recycledIndices) {
    for (int row = 0; row < chunk.chunkSize.y; row++) {
      for (int col = 0; col < chunk.chunkSize.x; col++) {
        final worldPos = chunk.getTileWorldPosition(col, row);
        final noise = chunk.getNoise(col, row);
        final source = selectSprite(noise, _currentFrame);
        if (source != null) {
          super.addOrUpdateTile(worldPos, source, recycledIndices);
          _tileNoiseValues[batchIndices[worldPos]!] = noise;
        }
      }
    }
  }
}
