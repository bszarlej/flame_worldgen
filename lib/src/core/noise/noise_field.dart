import '../hash.dart';
import 'perlin.dart';
import 'simplex.dart';

/// Samples a noise field at a position in tiles.
typedef NoiseFunction = double Function(double x, double y);

/// The noise that [NoiseField.fbm] layers.
enum NoiseBasis {
  /// Simplex noise: smooth, with few directional artifacts.
  simplex,

  /// Perlin noise: slightly more grid-aligned, blockier features.
  perlin,
}

/// Bends a noise field by offsetting where it's sampled, which turns round
/// blobs into more natural, twisting shapes.
class DomainWarp {
  /// Creates a domain warp that moves sample positions by up to [strength]
  /// tiles.
  ///
  /// [frequency] controls how quickly the offset changes, in cycles per tile.
  /// It defaults to the warped field's frequency.
  const DomainWarp({required this.strength, this.frequency});

  /// The largest offset, in tiles.
  final double strength;

  /// How quickly the offset changes, in cycles per tile, or null to use the
  /// warped field's frequency.
  final double? frequency;
}

/// A named source of smooth, seeded noise that gives every point in the
/// world a value between -1 and 1.
///
/// Each field gets its own seed, derived from the world seed and its [name].
/// Renaming a field changes its output; reordering fields doesn't.
sealed class NoiseField {
  NoiseField._(this.name) {
    if (name.isEmpty) {
      throw ArgumentError.value(name, 'name', 'must not be empty');
    }
  }

  /// Simplex noise. [frequency] is in cycles per tile; lower values give
  /// larger features.
  factory NoiseField.simplex(
    String name, {
    double frequency,
    DomainWarp? warp,
  }) = _FractalField.simplex;

  /// Perlin noise. [frequency] is in cycles per tile; lower values give
  /// larger features. At the same frequency, Perlin features are about twice
  /// the size of simplex features.
  factory NoiseField.perlin(String name, {double frequency, DomainWarp? warp}) =
      _FractalField.perlin;

  /// Fractal Brownian motion: [octaves] layers of [basis] noise, each
  /// [lacunarity] times the frequency and [gain] times the strength of the
  /// one before, which adds detail at smaller scales.
  factory NoiseField.fbm(
    String name, {
    double frequency,
    int octaves,
    double lacunarity,
    double gain,
    NoiseBasis basis,
    DomainWarp? warp,
  }) = _FractalField;

  /// A field computed by [sample], which receives the position in tiles and
  /// this field's seed.
  ///
  /// [sample] must be deterministic and should return values between -1
  /// and 1.
  factory NoiseField.custom(
    String name,
    double Function(double x, double y, int seed) sample,
  ) = _CustomField;

  /// Identifies the field and derives its seed.
  final String name;

  /// Returns a function that samples this field in the world with
  /// [worldSeed].
  NoiseFunction sampler(int worldSeed);

  @override
  String toString() => 'NoiseField($name)';
}

final class _FractalField extends NoiseField {
  _FractalField(
    super.name, {
    this.frequency = 0.01,
    this.octaves = 4,
    this.lacunarity = 2,
    this.gain = 0.5,
    this.basis = NoiseBasis.simplex,
    this.warp,
  }) : super._() {
    _checkPositive(frequency, 'frequency');
    _checkPositive(lacunarity, 'lacunarity');
    _checkPositive(gain, 'gain');
    if (octaves < 1 || octaves > 16) {
      throw RangeError.range(octaves, 1, 16, 'octaves');
    }
    if (warp case final warp?) {
      if (!warp.strength.isFinite || warp.strength < 0) {
        throw ArgumentError.value(
          warp.strength,
          'warp.strength',
          'must be finite and not negative',
        );
      }
      if (warp.frequency case final frequency?) {
        _checkPositive(frequency, 'warp.frequency');
      }
    }
  }

  _FractalField.simplex(
    String name, {
    double frequency = 0.01,
    DomainWarp? warp,
  }) : this(name, frequency: frequency, octaves: 1, warp: warp);

  _FractalField.perlin(String name, {double frequency = 0.01, DomainWarp? warp})
    : this(
        name,
        frequency: frequency,
        octaves: 1,
        basis: NoiseBasis.perlin,
        warp: warp,
      );

  final double frequency;
  final int octaves;
  final double lacunarity;
  final double gain;
  final NoiseBasis basis;
  final DomainWarp? warp;

  @override
  NoiseFunction sampler(int worldSeed) {
    final seed = deriveSeed(worldSeed, name);
    final noise = switch (basis) {
      NoiseBasis.simplex => simplex2,
      NoiseBasis.perlin => perlin2,
    };

    // Simplex and Perlin noise are 0 at their lattice points, and every
    // octave has a lattice point at the origin. Without an offset, every
    // field in every world would be exactly 0 at tile (0, 0).
    final octaveSeeds = [for (var i = 0; i < octaves; i++) hash2(i, 0, seed)];
    final offsetsX = [
      for (var i = 0; i < octaves; i++) hashToUnit(hash2(i, 1, seed)) * 256,
    ];
    final offsetsY = [
      for (var i = 0; i < octaves; i++) hashToUnit(hash2(i, 2, seed)) * 256,
    ];
    var totalAmplitude = 0.0;
    var amplitude = 1.0;
    for (var i = 0; i < octaves; i++) {
      totalAmplitude += amplitude;
      amplitude *= gain;
    }

    double fractal(double x, double y) {
      var sum = 0.0;
      var amplitude = 1.0;
      var scale = frequency;
      for (var i = 0; i < octaves; i++) {
        final nx = x * scale + offsetsX[i];
        final ny = y * scale + offsetsY[i];
        sum += amplitude * noise(nx, ny, octaveSeeds[i]);
        amplitude *= gain;
        scale *= lacunarity;
      }
      return sum / totalAmplitude;
    }

    final warp = this.warp;
    if (warp == null || warp.strength == 0) return fractal;

    final warpFrequency = warp.frequency ?? frequency;
    final strength = warp.strength;
    final seedX = deriveSeed(seed, 'warp x');
    final seedY = deriveSeed(seed, 'warp y');
    return (x, y) {
      final wx = x * warpFrequency;
      final wy = y * warpFrequency;
      return fractal(
        x + simplex2(wx, wy, seedX) * strength,
        y + simplex2(wx, wy, seedY) * strength,
      );
    };
  }
}

final class _CustomField extends NoiseField {
  _CustomField(super.name, this.sample) : super._();

  final double Function(double x, double y, int seed) sample;

  @override
  NoiseFunction sampler(int worldSeed) {
    final seed = deriveSeed(worldSeed, name);
    return (x, y) => sample(x, y, seed);
  }
}

void _checkPositive(double value, String name) {
  if (!value.isFinite || value <= 0) {
    throw ArgumentError.value(value, name, 'must be finite and positive');
  }
}
