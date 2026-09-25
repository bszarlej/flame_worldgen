import 'package:flame_worldgen/src/core/noise/noise_field.dart';
import 'package:flame_worldgen/src/core/noise/perlin.dart';
import 'package:flame_worldgen/src/core/noise/simplex.dart';
import 'package:test/test.dart';

// Golden values come from an independent Python implementation that follows
// the same operations in the same order. They're compared exactly: the noise
// must be bit-identical on the VM and on the web (`dart test -p chrome`).

void main() {
  group('simplex2', () {
    const golden = [
      (0.0, 0.0, 0.0),
      (0.5, 0.25, -0.268659241579093),
      (-1.75, 3.1, 0.757558386053116),
      (10.3, -7.7, -0.638975985120542),
      (123.456, 789.012, -0.7378641884861802),
      (-1000.5, -2000.25, -0.48378592338769627),
    ];

    for (final (x, y, value) in golden) {
      test('($x, $y) is $value', () {
        expect(simplex2(x, y, 42), value);
      });
    }

    _testRangeAndSmoothness(simplex2);
  });

  group('perlin2', () {
    const golden = [
      (0.0, 0.0, 0.0),
      (0.5, 0.25, -0.36602492113760005),
      (-1.75, 3.1, -0.06376992167593853),
      (10.3, -7.7, 0.13907993709190383),
      (123.456, 789.012, -0.21246198685472334),
      (-1000.5, -2000.25, -0.2128272946616692),
    ];

    for (final (x, y, value) in golden) {
      test('($x, $y) is $value', () {
        expect(perlin2(x, y, 42), value);
      });
    }

    _testRangeAndSmoothness(perlin2);
  });

  group('NoiseField', () {
    final fields = {
      NoiseField.simplex('simplex'): [
        0.6403450455884331,
        0.672530747497474,
        -0.5822464222455886,
        -0.16576637444532405,
        -0.33079266570436655,
      ],
      NoiseField.perlin('perlin'): [
        -0.16552844976953968,
        -0.1705500210638252,
        -0.11522315398560938,
        -0.24891819880511035,
        -0.14379769900586956,
      ],
      NoiseField.fbm('fbm', frequency: 0.004, octaves: 5): [
        0.41843011322898,
        0.4162782895839737,
        0.0442501992404035,
        -0.09809869454773454,
        -0.2866777046727282,
      ],
      NoiseField.fbm(
        'fbmPerlin',
        frequency: 0.02,
        octaves: 3,
        lacunarity: 2.5,
        gain: 0.4,
        basis: NoiseBasis.perlin,
      ): [
        -0.26035228178332503,
        -0.29053343334070364,
        0.21481932349472205,
        -0.27901431222474554,
        0.3292895356798196,
      ],
      NoiseField.perlin(
        'warped',
        frequency: 0.002,
        warp: const DomainWarp(strength: 40),
      ): [
        0.20020165529820655,
        0.20080785799944847,
        0.1656411111770105,
        -0.1640630369591172,
        -0.097663997606197,
      ],
    };
    const tiles = [(0, 0), (1, 0), (-37, 12), (250, -900), (-4096, 4095)];

    for (final MapEntry(key: field, value: golden) in fields.entries) {
      test('${field.name} matches the reference', () {
        final sample = field.sampler(7);
        final values = [
          for (final (x, y) in tiles) sample(x.toDouble(), y.toDouble()),
        ];
        expect(values, golden);
      });
    }

    test('fbm stays in range', () {
      final sample = NoiseField.fbm('fbm', octaves: 6).sampler(3);
      for (var y = -200; y < 200; y += 3) {
        for (var x = -200; x < 200; x += 3) {
          expect(sample(x.toDouble(), y.toDouble()), inInclusiveRange(-1, 1));
        }
      }
    });

    test('the seed depends on the name, not the instance', () {
      final a = NoiseField.simplex('elevation').sampler(1);
      final b = NoiseField.simplex('elevation').sampler(1);
      final other = NoiseField.simplex('moisture').sampler(1);
      final otherWorld = NoiseField.simplex('elevation').sampler(2);
      expect(a(12, 34), b(12, 34));
      expect(a(12, 34), isNot(other(12, 34)));
      expect(a(12, 34), isNot(otherWorld(12, 34)));
    });

    test('a warp with strength 0 changes nothing', () {
      final plain = NoiseField.simplex('a').sampler(1);
      final warped = NoiseField.simplex(
        'a',
        warp: const DomainWarp(strength: 0),
      ).sampler(1);
      expect(warped(5, 6), plain(5, 6));
    });

    test('custom fields receive the derived seed', () {
      final seeds = <int>{};
      final field = NoiseField.custom('rivers', (x, y, seed) {
        seeds.add(seed);
        return x + y;
      });
      final sample = field.sampler(1);
      expect(sample(1, 2), 3);
      expect(field.sampler(2)(0, 0), 0);
      expect(seeds, hasLength(2));
    });

    test('rejects invalid parameters', () {
      expect(() => NoiseField.simplex(''), throwsArgumentError);
      expect(() => NoiseField.simplex('a', frequency: 0), throwsArgumentError);
      expect(
        () => NoiseField.perlin('a', frequency: double.nan),
        throwsArgumentError,
      );
      expect(() => NoiseField.fbm('a', octaves: 0), throwsRangeError);
      expect(() => NoiseField.fbm('a', octaves: 17), throwsRangeError);
      expect(() => NoiseField.fbm('a', gain: -1), throwsArgumentError);
      expect(() => NoiseField.fbm('a', lacunarity: 0), throwsArgumentError);
      expect(
        () => NoiseField.simplex('a', warp: const DomainWarp(strength: -1)),
        throwsArgumentError,
      );
      expect(
        () => NoiseField.simplex(
          'a',
          warp: const DomainWarp(strength: 1, frequency: 0),
        ),
        throwsArgumentError,
      );
    });
  });
}

void _testRangeAndSmoothness(double Function(double, double, int) noise) {
  test('stays in [-1, 1] and averages about 0', () {
    var sum = 0.0;
    var count = 0;
    for (var y = 0; y < 150; y++) {
      for (var x = 0; x < 150; x++) {
        final value = noise(x * 0.37 - 20, y * 0.41 + 7, 5);
        expect(value, inInclusiveRange(-1, 1));
        sum += value;
        count++;
      }
    }
    expect(sum / count, closeTo(0, 0.02));
  });

  test('changes smoothly', () {
    for (var i = 0; i < 1000; i++) {
      final x = i * 0.173 - 50;
      final y = i * 0.091 + 20;
      final step = noise(x + 0.001, y, 5) - noise(x, y, 5);
      expect(step.abs(), lessThan(0.02));
    }
  });

  test('is 0 on lattice points', () {
    expect(noise(0, 0, 5), 0);
  });

  test('depends on the seed', () {
    expect(noise(3.3, 4.4, 1), isNot(noise(3.3, 4.4, 2)));
  });
}
