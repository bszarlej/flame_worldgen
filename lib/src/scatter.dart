import 'dart:math';

import 'package:flame/components.dart';

import 'core/coords.dart';
import 'core/generation/biome.dart';
import 'core/generation/scatter.dart';

/// Spreads objects over a biome and spawns a component for each one when
/// its chunk loads.
///
/// ```dart
/// Biome(
///   'forest',
///   ground: grass,
///   scatter: [
///     Scatter(
///       'trees',
///       density: 0.05,
///       minDistance: 2,
///       spawn: (spot) => Tree(position: spot.position),
///     ),
///   ],
/// )
/// ```
///
/// The components are added to the map's parent, usually your `World`, so
/// they can be sorted together with the player. They're removed when their
/// chunk unloads, and spawned again, the same way, when it loads again.
class Scatter extends ScatterRule {
  /// Creates a rule called [name] that places about [density] objects per
  /// tile, never closer than [minDistance] tiles to each other, and calls
  /// [spawn] for each one.
  ///
  /// See [ScatterRule] for the largest [density] a [minDistance] allows.
  const Scatter(
    super.name, {
    required super.density,
    super.minDistance,
    required this.spawn,
  });

  /// Creates the component for [spot], or returns null to leave the spot
  /// empty.
  ///
  /// Called on the main isolate, so it can use sprites and images.
  final Component? Function(ScatterSpot spot) spawn;

  @override
  String toString() => 'Scatter($name)';
}

/// A place where a [ScatterRule] puts an object.
///
/// Spots are the same every time a chunk is generated. Use [random] to vary
/// the objects, so they're the same every time, too.
abstract interface class ScatterSpot {
  /// The rule that placed the spot.
  ScatterRule get rule;

  /// Where the spot is, in the map's coordinates (pixels). A new vector on
  /// every call, so it's safe to keep or change.
  Vector2 get position;

  /// The tile the spot is on.
  TileCoord get coord;

  /// The biome of [coord].
  Biome get biome;

  /// Random numbers for this spot, the same sequence every time its chunk
  /// loads.
  Random get random;
}
