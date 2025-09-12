import 'dart:ui';

import 'tile_layer.dart';

class StaticTileLayer extends TileLayer {
  final Rect? Function(double noiseValue) spriteSelector;

  StaticTileLayer({
    required super.chunkManager,
    required super.spriteBatch,
    required this.spriteSelector,
    super.centerPositionProvider,
    super.paint,
    super.children,
    super.key,
    super.priority,
  });

  @override
  Rect? selectSprite(double noiseValue, [int frame = 0]) {
    return spriteSelector(noiseValue);
  }
}
