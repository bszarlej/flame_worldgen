import 'dart:math';

import 'package:flutter/widgets.dart';

import '../math/vector2i.dart';

/// Abstract base class for selecting a sprite from a tileset.
///
/// Implementations decide which sprite to return based on noise, animation frame,
/// and optionally the world position of the tile.
abstract class SpriteSelector {
  /// Returns a [Rect] representing the portion of a sprite sheet to use.
  ///
  /// - [noise] is a procedural value for this tile, typically from Perlin or Simplex noise.
  /// - [frame] is the current animation frame.
  /// - [worldPos] is the tile's position in the world (in tile coordinates).
  Rect? select(double noise, int frame, Vector2i worldPos);
}

/// Always returns a static sprite regardless of frame or world position.
class StaticSpriteSelector implements SpriteSelector {
  final Rect? Function(double noise) _selector;

  /// Creates a new [StaticSpriteSelector].
  ///
  /// [_selector] should return a [Rect] from the tileset based on [noise].
  StaticSpriteSelector(this._selector);

  @override
  Rect? select(double noise, int frame, Vector2i worldPos) => _selector(noise);
}

/// Selects a sprite based on a list of frames for animation.
///
/// The frame returned is determined by `frame % frames.length`.
class AnimatedSpriteSelector implements SpriteSelector {
  final List<Rect>? Function(double noise) _frames;

  /// Creates a new [AnimatedSpriteSelector].
  ///
  /// - [_frames] should return a list of frames for the given noise value.
  AnimatedSpriteSelector(this._frames);

  @override
  Rect? select(double noise, int frame, Vector2i worldPos) {
    final frames = _frames(noise);
    return frames?.isEmpty != false ? null : frames![frame % frames.length];
  }
}

/// Selects a sprite randomly from a list of weighted sprites.
///
/// The selected sprite may have multiple frames, in which case the frame
/// is selected using `frame % frames.length`.
class WeightedSpriteSelector implements SpriteSelector {
  /// List of weighted sprite options.
  final List<WeightedSprite> options;

  /// Predicate to determine whether a sprite should be selected for a given noise value.
  final bool Function(double noise) predicate;

  /// Creates a new [WeightedSpriteSelector].
  ///
  /// [options] must contain at least one [WeightedSprite].
  WeightedSpriteSelector({required this.options, required this.predicate})
    : assert(
        options.isNotEmpty,
        'WeightedSpriteSelector requires at least one option in "options".',
      );

  @override
  Rect? select(double noise, int frame, Vector2i worldPos) {
    if (!predicate(noise)) return null;

    final rand = Random(worldPos.hashCode);
    final totalWeight = options.fold<double>(
      0,
      (sum, opt) => sum + opt.weight(noise),
    );
    double roll = rand.nextDouble() * totalWeight;

    for (final opt in options) {
      final weight = opt.weight(noise);
      if (roll < weight) return opt.frames[frame % opt.frames.length];
      roll -= weight;
    }

    return options.first.frames[frame % options.first.frames.length];
  }
}

/// Represents a sprite with one or more frames and a weight function.
///
/// The weight function can optionally depend on the noise value to make
/// selection probability dynamic per tile.
class WeightedSprite {
  /// Frames associated with this sprite.
  final List<Rect> frames;

  /// Function returning the weight of this sprite for a given noise value.
  final double Function(double noise) weight;

  /// Creates a weighted sprite with a single frame.
  WeightedSprite.single(Rect rect, {required this.weight}) : frames = [rect];

  /// Creates a weighted sprite with multiple frames.
  WeightedSprite.multi(this.frames, {required this.weight});
}
