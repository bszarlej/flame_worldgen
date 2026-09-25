import 'dart:math';

import '../coords.dart';
import '../hash.dart';

/// How densely and how far apart objects of one kind are spread in a biome.
///
/// In a Flame game, use `Scatter`, which extends this with a `spawn`
/// callback. This base class is all generation needs, so it also works
/// without Flame.
class ScatterRule {
  /// Creates a rule called [name] that places about [density] objects per
  /// tile, never closer than [minDistance] tiles to each other.
  ///
  /// The larger [minDistance], the fewer objects fit: [density] can be at
  /// most `0.95 / ((π - 0.5) · minDistance²)`, about 0.36 for a
  /// [minDistance] of 1 and 0.09 for 2.
  const ScatterRule(this.name, {required this.density, this.minDistance = 0});

  /// Identifies the rule. Must be unique within a world, and should stay
  /// stable once you've shipped, because saves refer to spots by it.
  final String name;

  /// The expected number of objects per tile.
  final double density;

  /// The smallest distance between two objects of this rule, in tiles.
  final double minDistance;

  @override
  String toString() => 'ScatterRule($name)';
}

/// A place where a [ScatterRule] puts an object.
class ScatterSpot {
  /// Creates a spot at ([x], [y]) for the rule with [ruleIndex].
  const ScatterSpot({
    required this.ruleIndex,
    required this.x,
    required this.y,
    required this.cellX,
    required this.cellY,
    required this.seed,
  });

  /// The index of the rule in the generator's list of scatter rules.
  final int ruleIndex;

  /// The horizontal position, in tiles. 12.5 is the middle of tile 12.
  final double x;

  /// The vertical position, in tiles.
  final double y;

  /// The rule's grid cell this spot was placed in. Together with the rule it
  /// identifies the spot permanently, for example in save files.
  final int cellX;

  /// See [cellX].
  final int cellY;

  /// A seed for this spot, for example to vary its size or sprite.
  final int seed;

  /// The tile the spot is on.
  TileCoord get coord => TileCoord(x.floor(), y.floor());

  @override
  String toString() => 'ScatterSpot($ruleIndex, $x, $y)';
}

/// Throws if [rule] can't be satisfied.
void checkScatterRule(ScatterRule rule) {
  if (rule.name.isEmpty) {
    throw ArgumentError.value(rule, 'scatter', 'names must not be empty');
  }
  if (!rule.minDistance.isFinite || rule.minDistance < 0) {
    throw ArgumentError.value(
      rule.minDistance,
      '${rule.name}.minDistance',
      'must be finite and not negative',
    );
  }
  if (!rule.density.isFinite || rule.density <= 0) {
    throw ArgumentError.value(
      rule.density,
      '${rule.name}.density',
      'must be finite and positive',
    );
  }
  final maxDensity = rule.minDistance > 0
      ? _maxCrowding / _neighbourhood(rule.minDistance)
      : 1.0;
  if (rule.density > maxDensity) {
    throw ArgumentError.value(
      rule.density,
      '${rule.name}.density',
      'is too high: with a minDistance of ${rule.minDistance}, at most '
          '${maxDensity.toStringAsFixed(3)} objects per tile fit',
    );
  }
}

/// How full the neighbourhood of a spot may get, see [_candidateChance].
const _maxCrowding = 0.95;

/// The area around a candidate where other candidates compete with it: a
/// disk of radius [minDistance], minus the candidate's own cell, which can't
/// hold another candidate.
double _neighbourhood(double minDistance) =>
    (pi - 0.5) * minDistance * minDistance;

/// The chance that a cell holds a candidate, chosen so that the spots that
/// survive have the rule's density on average.
///
/// A candidate survives if it has the highest priority among the μ other
/// candidates expected in its neighbourhood of area A, which happens with
/// probability (1 - e^-μ) / μ. Solving density = (1 - e^-μ) / A for μ gives
/// μ = -ln(1 - density · A).
double _candidateChance(ScatterRule rule) {
  if (rule.minDistance == 0) return rule.density;
  final area = _neighbourhood(rule.minDistance);
  final mu = _negativeLog1m(rule.density * area);
  final cellSize = _cellSize(rule);
  return mu / area * cellSize * cellSize;
}

/// -ln(1 - [x]) for 0 <= x <= 0.95, as the series x + x²/2 + x³/3 + ...
///
/// `dart:math`'s `log` isn't guaranteed to give bit-identical results on
/// every platform, and a difference in the last bit could add or remove a
/// spot on the web. This uses only `*`, `/` and `+`.
double _negativeLog1m(double x) {
  var sum = 0.0;
  var power = 1.0;
  for (var k = 1; k < 2000; k++) {
    power *= x;
    final term = power / k;
    if (term <= sum * 1e-17) break;
    sum += term;
  }
  return sum;
}

/// Places the spots of [rule] whose position is inside the square of [size]
/// tiles at ([originX], [originY]).
///
/// The result only depends on the rule, [ruleSeed] and the area, so
/// neighbouring areas agree along their borders.
List<ScatterSpot> scatterSpots(
  ScatterRule rule,
  int ruleIndex,
  int ruleSeed,
  int originX,
  int originY,
  int size,
) {
  final cellSize = _cellSize(rule);
  final chance = _candidateChance(rule);
  // Cells whose candidates can be within minDistance of each other.
  final reach = (rule.minDistance / cellSize).ceil();
  final minDistance2 = rule.minDistance * rule.minDistance;

  _Candidate? candidateAt(int cellX, int cellY) {
    if (hashToUnit(hash3(cellX, cellY, 0, ruleSeed)) >= chance) return null;
    return _Candidate(
      (cellX + hashToUnit(hash3(cellX, cellY, 1, ruleSeed))) * cellSize,
      (cellY + hashToUnit(hash3(cellX, cellY, 2, ruleSeed))) * cellSize,
      hash3(cellX, cellY, 3, ruleSeed),
    );
  }

  bool outranks(
    _Candidate other,
    int otherX,
    int otherY,
    _Candidate c,
    int x,
    int y,
  ) {
    if (other.priority != c.priority) return other.priority > c.priority;
    return otherY != y ? otherY > y : otherX > x;
  }

  final spots = <ScatterSpot>[];
  final firstX = (originX / cellSize).floor();
  final firstY = (originY / cellSize).floor();
  final lastX = ((originX + size) / cellSize).floor();
  final lastY = ((originY + size) / cellSize).floor();

  for (var cellY = firstY; cellY <= lastY; cellY++) {
    for (var cellX = firstX; cellX <= lastX; cellX++) {
      final candidate = candidateAt(cellX, cellY);
      if (candidate == null) continue;
      if (candidate.x < originX || candidate.x >= originX + size) continue;
      if (candidate.y < originY || candidate.y >= originY + size) continue;

      var survives = true;
      search:
      for (var dy = -reach; dy <= reach; dy++) {
        for (var dx = -reach; dx <= reach; dx++) {
          if (dx == 0 && dy == 0) continue;
          final other = candidateAt(cellX + dx, cellY + dy);
          if (other == null) continue;
          final distX = other.x - candidate.x;
          final distY = other.y - candidate.y;
          if (distX * distX + distY * distY >= minDistance2) continue;
          if (outranks(
            other,
            cellX + dx,
            cellY + dy,
            candidate,
            cellX,
            cellY,
          )) {
            survives = false;
            break search;
          }
        }
      }
      if (!survives) continue;

      spots.add(
        ScatterSpot(
          ruleIndex: ruleIndex,
          x: candidate.x,
          y: candidate.y,
          cellX: cellX,
          cellY: cellY,
          seed: hash3(cellX, cellY, 4, ruleSeed),
        ),
      );
    }
  }
  return spots;
}

/// Cells are small enough that one candidate per cell can't break
/// minDistance within the cell. Without a minDistance, cells are one tile.
double _cellSize(ScatterRule rule) =>
    rule.minDistance > 0 ? rule.minDistance / sqrt2 : 1;

class _Candidate {
  const _Candidate(this.x, this.y, this.priority);

  final double x;
  final double y;
  final int priority;
}
