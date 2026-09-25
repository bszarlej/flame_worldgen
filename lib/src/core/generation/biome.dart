import '../tile_type.dart';
import 'sample.dart';

/// A region of the world with its own ground tile, chosen per tile by a
/// condition on the noise fields.
///
/// ```dart
/// Biome('ocean', ground: water, when: (s) => s[elevation] < -0.1)
/// ```
///
/// A world's biomes are checked in order and the first one whose [when]
/// matches is used. A biome without [when] matches every tile, so it must be
/// the last one.
class Biome {
  /// Creates a biome called [name] whose tiles are [ground].
  const Biome(this.name, {required this.ground, this.when});

  /// Identifies the biome. Must be unique within a world.
  final String name;

  /// The tile type placed on every tile of this biome.
  final TileType ground;

  /// Whether a tile belongs to this biome, or null to match every tile.
  ///
  /// Must be deterministic: it may only depend on the sample.
  final bool Function(Sample s)? when;

  @override
  String toString() => 'Biome($name)';
}
