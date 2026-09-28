import 'dart:ui';

import '../core/hash.dart';

/// Which part of a tileset's atlas to draw for each tile of one world.
///
/// Built by `Tileset.sources` for a palette and world seed. Tile ids index
/// the palette.
class TileSources {
  /// Creates sources from the atlas rects of each tile id, and for tile ids
  /// with variants, the running totals of their weights.
  TileSources(this._rects, this._cumulativeWeights, {required int seed})
    : _variantSeed = deriveSeed(seed, 'tile variants');

  final List<List<Rect>> _rects;
  final List<List<double>?> _cumulativeWeights;
  final int _variantSeed;

  /// The number of tile ids.
  int get length => _rects.length;

  /// The part of the atlas to draw for the tile [id] at ([x], [y]).
  Rect rectAt(int id, int x, int y) {
    final rects = _rects[id];
    final weights = _cumulativeWeights[id];
    if (weights == null) return rects.first;
    return rects[pickVariant(weights, hash2(x, y, _variantSeed))];
  }
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
