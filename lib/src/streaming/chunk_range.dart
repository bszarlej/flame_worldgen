import '../core/coords.dart';

/// An inclusive rectangle of chunk coordinates.
class ChunkRange {
  /// Creates the range from ([left], [top]) to ([right], [bottom]),
  /// inclusive.
  const ChunkRange(this.left, this.top, this.right, this.bottom);

  /// The leftmost column.
  final int left;

  /// The topmost row.
  final int top;

  /// The rightmost column, inclusive.
  final int right;

  /// The bottom row, inclusive.
  final int bottom;

  /// This range with [margin] more chunks on every side.
  ChunkRange expand(int margin) =>
      ChunkRange(left - margin, top - margin, right + margin, bottom + margin);

  /// Whether [coord] is inside this range.
  bool contains(ChunkCoord coord) =>
      coord.x >= left &&
      coord.x <= right &&
      coord.y >= top &&
      coord.y <= bottom;

  /// Every chunk in this range, row by row.
  Iterable<ChunkCoord> get coords sync* {
    for (var y = top; y <= bottom; y++) {
      for (var x = left; x <= right; x++) {
        yield ChunkCoord(x, y);
      }
    }
  }

  /// The squared distance from the centre of this range to the centre of
  /// [coord], in chunks. Used to load the nearest chunks first.
  double distanceSquaredTo(ChunkCoord coord) {
    final dx = coord.x - (left + right) / 2;
    final dy = coord.y - (top + bottom) / 2;
    return dx * dx + dy * dy;
  }

  @override
  bool operator ==(Object other) =>
      other is ChunkRange &&
      other.left == left &&
      other.top == top &&
      other.right == right &&
      other.bottom == bottom;

  @override
  int get hashCode => Object.hash(left, top, right, bottom);

  @override
  String toString() => 'ChunkRange($left, $top, $right, $bottom)';
}
