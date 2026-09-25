import 'package:flame_worldgen/src/core/hash.dart';
import 'package:flutter_test/flutter_test.dart';

// Golden values come from an independent Python implementation of
// SquirrelNoise5 using arbitrary-precision integers. They must match on every
// platform, so this file also runs on Chrome in CI.

void main() {
  group('hash1', () {
    const golden = {
      (0, 0): 377036288,
      (1, 0): 3365260061,
      (-1, 0): 4210126164,
      (0, 1): 603375697,
      (12345, 42): 3320562864,
      (-987654, 42): 3796546802,
      (2147483647, 7): 1027351897,
      (-2147483648, 7): 2576341466,
      (0, -1): 2713817374,
    };

    for (final MapEntry(key: (x, seed), :value) in golden.entries) {
      test('($x, $seed) is $value', () {
        expect(hash1(x, seed), value);
      });
    }

    test('only uses the low 32 bits of x', () {
      expect(hash1(4294967301, 0), hash1(5, 0));
    });
  });

  group('hash2', () {
    const golden = {
      (0, 0, 0): 377036288,
      (1, 0, 0): 3365260061,
      (0, 1, 0): 2397028398,
      (-1, -1, 0): 1346327262,
      (100, -200, 42): 1420677780,
      (-31, 17, 123456789): 3883350432,
      (1048576, -1048576, 99): 3772380315,
    };

    for (final MapEntry(key: (x, y, seed), :value) in golden.entries) {
      test('($x, $y, $seed) is $value', () {
        expect(hash2(x, y, seed), value);
      });
    }

    test('has no collisions in a 256x256 area', () {
      final seen = <int>{};
      for (var y = -128; y < 128; y++) {
        for (var x = -128; x < 128; x++) {
          seen.add(hash2(x, y, 42));
        }
      }
      expect(seen, hasLength(256 * 256));
    });
  });

  group('hash3', () {
    const golden = {
      (0, 0, 0, 0): 377036288,
      (1, 2, 3, 0): 2197340503,
      (-5, 6, -7, 42): 3109983711,
      (1000, -1000, 1, 99): 2004873331,
    };

    for (final MapEntry(key: (x, y, z, seed), :value) in golden.entries) {
      test('($x, $y, $z, $seed) is $value', () {
        expect(hash3(x, y, z, seed), value);
      });
    }
  });

  test('hashes are unsigned 32-bit integers', () {
    for (var x = -1000; x < 1000; x++) {
      final hash = hash2(x, -x * 7, x);
      expect(hash, inInclusiveRange(0, 0xFFFFFFFF));
    }
  });

  test('hashes are evenly distributed', () {
    const buckets = 16;
    const samples = 16000;
    final counts = List.filled(buckets, 0);
    for (var i = 0; i < samples; i++) {
      counts[(hashToUnit(hash1(i, 1)) * buckets).floor()]++;
    }
    for (final count in counts) {
      expect(count, closeTo(samples / buckets, samples / buckets * 0.1));
    }
  });

  group('hashToUnit', () {
    test('maps to [0, 1)', () {
      expect(hashToUnit(0), 0);
      expect(hashToUnit(0x80000000), 0.5);
      expect(hashToUnit(0xFFFFFFFF), lessThan(1));
    });
  });

  group('hashToSigned', () {
    test('maps to [-1, 1)', () {
      expect(hashToSigned(0), -1);
      expect(hashToSigned(0x80000000), 0);
      expect(hashToSigned(0xFFFFFFFF), lessThan(1));
    });
  });
}
