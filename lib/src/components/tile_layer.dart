import 'dart:async';

import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/widgets.dart';

import '../core/chunk.dart';
import '../core/chunk_manager.dart';
import '../core/sprite_selector.dart';
import '../math/vector2i.dart';

/// Signature for providing a transform for rendering a tile at [worldPos].
typedef TileTransformProvider = RSTransform Function(Vector2i worldPos);

/// Default transform provider.
///
/// Places each tile at its world position with no scaling or rotation.
RSTransform _defaultTransformProvider(Vector2i pos) {
  return RSTransform.fromComponents(
    rotation: 0,
    scale: 1.0,
    anchorX: 0,
    anchorY: 0,
    translateX: pos.x.toDouble(),
    translateY: pos.y.toDouble(),
  );
}

/// Controls animation frames for a tile layer.
///
/// Increments the current frame every [frameDuration] seconds
/// and notifies listeners whenever the frame changes.
class TileAnimationController {
  /// Duration of each frame in seconds.
  final double frameDuration;

  final _listeners = <VoidCallback>[];
  int _currentFrame = 0;
  late final Timer _timer;

  /// Creates a new [TileAnimationController].
  TileAnimationController({required this.frameDuration}) {
    _timer = Timer(frameDuration, repeat: true, onTick: _tick);
  }

  /// The current animation frame index.
  int get currentFrame => _currentFrame;

  /// Registers a callback to be called whenever the frame changes.
  void addListener(VoidCallback listener) => _listeners.add(listener);

  /// Updates the internal timer.
  ///
  /// Must be called every frame with the delta time [dt].
  void update(double dt) => _timer.update(dt);

  void _tick() {
    _currentFrame++;
    for (final l in _listeners) {
      l();
    }
  }
}

/// Configuration for a [TileLayer].
///
/// Defines how tiles are selected, transformed, animated, and rendered.
class TileLayerConfig {
  /// Selects which sprite to use for each tile.
  final SpriteSelector spriteSelector;

  /// Provides a transform for positioning and transforming tiles.
  ///
  /// Defaults to [_defaultTransformProvider].
  final TileTransformProvider transformProvider;

  /// Optional animation controller to advance tile frames over time.
  final TileAnimationController? animationController;

  /// Optional paint used when rendering the sprite batch.
  final Paint? paint;

  const TileLayerConfig({
    required this.spriteSelector,
    this.transformProvider = _defaultTransformProvider,
    this.animationController,
    this.paint,
  });
}

/// A renderable tile layer backed by a [SpriteBatch].
///
/// Tiles are generated from chunks managed by [ChunkManager].
/// The layer automatically updates visible chunks based on the camera
/// or a custom [centerPositionProvider].
class TileLayer extends Component with HasGameReference {
  /// Provides chunk data for this layer.
  final ChunkManager chunkManager;

  /// The sprite batch used for efficient tile rendering.
  final SpriteBatch spriteBatch;

  /// Layer configuration (sprite selector, transforms, animation).
  final TileLayerConfig config;

  /// Optional override for the position used as the "center" of visibility.
  ///
  /// Defaults to the camera viewfinder position.
  final Vector2 Function()? centerPositionProvider;

  /// Maps world positions to sprite batch indices.
  final Map<Vector2i, int> batchIndices = {};

  /// Stores noise values per sprite batch index (used for animation updates).
  final Map<int, double> _tileNoiseValues = {};

  int _currentIndex = 0;
  late final StreamSubscription<ChunkUpdateInfo> _chunkUpdateSubscription;

  TileLayer({
    required this.chunkManager,
    required this.spriteBatch,
    required this.config,
    this.centerPositionProvider,
    super.children,
    super.key,
    super.priority,
  });

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _chunkUpdateSubscription = chunkManager.onChunkUpdate.listen(
      (info) => _onChunkUpdate(info),
    );

    config.animationController?.addListener(_updateAnimations);
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Update visible chunks relative to camera or custom center.
    final centerPosition =
        centerPositionProvider?.call() ?? game.camera.viewfinder.position;
    chunkManager.updateVisibleChunks(centerPosition);

    config.animationController?.update(dt);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    spriteBatch.render(canvas, paint: config.paint);
  }

  @override
  Future<void> onRemove() async {
    await _chunkUpdateSubscription.cancel();
    super.onRemove();
  }

  /// Handles loading and unloading of chunks.
  void _onChunkUpdate(ChunkUpdateInfo info) {
    final List<int> recycledIndices = [];

    // Remove unloaded chunks and recycle their indices.
    for (final chunk in info.unloadedChunks) {
      for (int row = 0; row < chunk.size.y; row++) {
        for (int col = 0; col < chunk.size.x; col++) {
          final worldPos = chunk.getTileWorldPosition(col, row);
          final index = batchIndices.remove(worldPos);
          if (index != null) {
            recycledIndices.add(index);
            _tileNoiseValues.remove(index);
          }
        }
      }
    }

    // Add new chunks.
    for (final chunk in info.loadedChunks) {
      _processChunk(chunk, recycledIndices);
    }

    if (recycledIndices.isNotEmpty) {
      _rebuildBatch();
    }
  }

  /// Rebuilds the entire sprite batch from loaded chunks.
  void _rebuildBatch() {
    spriteBatch.clear();
    batchIndices.clear();
    _tileNoiseValues.clear();
    _currentIndex = 0;

    for (final chunk in chunkManager.loadedChunks.values) {
      _processChunk(chunk, []);
    }
  }

  /// Processes a chunk, adding its tiles to the sprite batch.
  void _processChunk(Chunk chunk, List<int> recycledIndices) {
    for (int row = 0; row < chunk.size.y; row++) {
      for (int col = 0; col < chunk.size.x; col++) {
        final worldPos = chunk.getTileWorldPosition(col, row);
        final noise = chunk.getNoise(col, row);
        final source = config.spriteSelector.select(
          noise,
          config.animationController?.currentFrame ?? 0,
          worldPos,
        );

        if (source != null) {
          _addOrUpdateTile(worldPos, source, recycledIndices, noise);
        }
      }
    }
  }

  /// Adds a new tile or updates an existing tile at [worldPos].
  void _addOrUpdateTile(
    Vector2i worldPos,
    Rect source,
    List<int> recycledIndices,
    double noise,
  ) {
    final transform = config.transformProvider(worldPos);

    int index;
    if (recycledIndices.isNotEmpty) {
      index = recycledIndices.removeLast();
      spriteBatch.replace(index, source: source, transform: transform);
    } else {
      spriteBatch.addTransform(source: source, transform: transform);
      index = _currentIndex++;
    }

    batchIndices[worldPos] = index;
    if (config.animationController != null) {
      _tileNoiseValues[index] = noise;
    }
  }

  /// Updates all animated tiles to the current animation frame.
  void _updateAnimations() {
    final frame = config.animationController!.currentFrame;
    for (final entry in batchIndices.entries) {
      final index = entry.value;
      final noise = _tileNoiseValues[index];
      if (noise == null) continue;
      final source = config.spriteSelector.select(noise, frame, entry.key);
      if (source != null) {
        spriteBatch.replace(index, source: source);
      }
    }
  }
}
