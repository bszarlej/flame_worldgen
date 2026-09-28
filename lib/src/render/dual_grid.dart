import 'dart:ui';

import '../core/tile_type.dart';

/// Where the tile for each corner mask is in a dual-grid block, as an index
/// row by row into the 4 × 4 block.
///
/// A mask has a bit for each corner of a display cell that shows the upper
/// terrain: 8 for top left, 4 top right, 2 bottom left and 1 bottom right.
const dualGridLayout = [12, 13, 0, 3, 8, 1, 14, 5, 15, 4, 11, 2, 9, 10, 7, 6];

/// Orders the terrains of [pairs], each (upper, lower), from the lowest to
/// the highest, so every upper terrain comes after its lower one.
///
/// Terrains that aren't ordered by the pairs keep the order in which they
/// first appear. Throws if the pairs contradict each other.
List<TileType> orderTerrains(List<(TileType, TileType)> pairs) {
  final terrains = <TileType>{
    for (final (upper, lower) in pairs) ...[lower, upper],
  };
  final below = {for (final terrain in terrains) terrain: <TileType>{}};
  for (final (upper, lower) in pairs) {
    below[upper]!.add(lower);
  }

  final ordered = <TileType>[];
  final remaining = terrains.toList();
  while (remaining.isNotEmpty) {
    final next = remaining.indexWhere(
      (terrain) => below[terrain]!.every(ordered.contains),
    );
    if (next == -1) {
      throw ArgumentError.value(
        pairs.map((p) => '${p.$1.name} over ${p.$2.name}').join(', '),
        'transitions',
        'contradict each other: '
            '${remaining.map((t) => t.name).join(', ')} are each drawn '
            'above one another',
      );
    }
    ordered.add(remaining.removeAt(next));
  }
  return ordered;
}

/// The terrains and transitions of one world, by tile id.
class DualGrid {
  /// Creates a dual grid where tile id `i` is called `names[i]` and has
  /// terrain rank `ranks[i]`, or -1 if it isn't a terrain, and [transitions]
  /// maps (upper, lower) tile ids to the atlas rects of their block, indexed
  /// by corner mask.
  DualGrid(this._names, this._ranks, this._transitions);

  final List<String> _names;
  final List<int> _ranks;
  final Map<(int, int), List<Rect>> _transitions;

  /// The name of the tile type with [id], for messages.
  String name(int id) => _names[id];

  /// The terrain rank of tile [id]: higher terrains are drawn on top. -1 if
  /// the tile isn't a terrain and is drawn with hard edges.
  int rank(int id) => _ranks[id];

  /// The atlas rects of the transition from [lower] to [upper], indexed by
  /// corner mask, or null if there is none.
  List<Rect>? transition(int upper, int lower) => _transitions[(upper, lower)];
}
