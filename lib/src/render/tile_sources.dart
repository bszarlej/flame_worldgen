import 'dart:ui';

import '../core/hash.dart';

/// Which part of a tileset's atlas to draw for each tile of one world.
///
/// Built by `Tileset.sources` for a palette and world seed. Tile ids index
/// the palette.
class TileSources {
  /// Creates sources from, for each tile id:
  ///
  /// * [rects]: the atlas rects of its sprite, its variants or its frames.
  /// * [cumulativeWeights]: for variants, the running totals of their
  ///   weights, otherwise null.
  /// * [stepTimes]: for animations, the seconds per frame, otherwise null.
  TileSources({
    required List<List<Rect>> rects,
    required List<List<double>?> cumulativeWeights,
    required List<double?> stepTimes,
    required int seed,
  }) : _rects = rects,
       _cumulativeWeights = cumulativeWeights,
       _stepTimes = stepTimes,
       _variantSeed = deriveSeed(seed, 'tile variants'),
       animatedIds = List.unmodifiable([
         for (var id = 0; id < rects.length; id++)
           if (stepTimes[id] != null) id,
       ]);

  final List<List<Rect>> _rects;
  final List<List<double>?> _cumulativeWeights;
  final List<double?> _stepTimes;
  final int _variantSeed;

  /// The ids of the animated tile types.
  final List<int> animatedIds;

  /// The number of tile ids.
  int get length => _rects.length;

  /// Whether tile [id] is animated.
  bool isAnimated(int id) => _stepTimes[id] != null;

  /// The part of the atlas to draw for the tile [id] at ([x], [y]), [time]
  /// seconds after animations started.
  Rect rectAt(int id, int x, int y, double time) {
    final rects = _rects[id];
    if (_stepTimes[id] != null) return rects[frameAt(id, time)];
    final weights = _cumulativeWeights[id];
    if (weights == null) return rects.first;
    return rects[pickVariant(weights, hash2(x, y, _variantSeed))];
  }

  /// The frame the animated tile [id] shows [time] seconds after animations
  /// started.
  int frameAt(int id, double time) =>
      (time / _stepTimes[id]!).floor() % _rects[id].length;

  /// The part of the atlas that frame [frame] of the animated tile [id]
  /// shows.
  Rect frameRect(int id, int frame) => _rects[id][frame];
}

/// Picks an index into [cumulativeWeights], the running totals of some
/// weights, using [hash].
///
/// Each index is picked in proportion to its weight.
int pickVariant(List<double> cumulativeWeights, int hash) {
  final target = hashToUnit(hash) * cumulativeWeights.last;
  final last = cumulativeWeights.length - 1;
  var index = 0;
  while (index < last && target >= cumulativeWeights[index]) {
    index++;
  }
  return index;
}
