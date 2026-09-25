import 'package:flame_worldgen/src/core/random.dart';
import 'package:test/test.dart';

// Golden values come from the same Python reference as hash_test.dart.

void main() {
  group('nextInt', () {
    test('matches the reference sequence', () {
      final random = WorldRandom(42);
      expect(List.generate(10, (_) => random.nextInt(100)), [
        48,
        37,
        98,
        63,
        82,
        45,
        99,
        59,
        47,
        8,
      ]);
    });

    test('supports the full 32-bit range', () {
      final random = WorldRandom(42);
      expect(List.generate(3, (_) => random.nextInt(4294967296)), [
        3563366748,
        3603261737,
        3772225298,
      ]);
    });

    test('rejects values that would bias the result', () {
      final random = WorldRandom(42);
      expect(List.generate(5, (_) => random.nextInt(3000000000)), [
        290622763,
        2243478882,
        2689332299,
        571595659,
        1880180247,
      ]);
    });

    test('stays in range', () {
      final random = WorldRandom(1);
      for (var i = 0; i < 1000; i++) {
        expect(random.nextInt(7), inInclusiveRange(0, 6));
      }
    });

    test('throws for max outside 1 to 2^32', () {
      final random = WorldRandom(1);
      expect(() => random.nextInt(0), throwsRangeError);
      expect(() => random.nextInt(-5), throwsRangeError);
      expect(() => random.nextInt(4294967297), throwsRangeError);
    });
  });

  test('nextDouble matches the reference sequence', () {
    final random = WorldRandom(-1);
    expect(List.generate(3, (_) => random.nextDouble()), [
      0.6318598403224709,
      0.48293027650859877,
      0.7634566194504616,
    ]);
  });

  test('nextBool matches the reference sequence', () {
    final random = WorldRandom(7);
    expect(List.generate(10, (_) => random.nextBool()), [
      false,
      true,
      false,
      true,
      false,
      false,
      true,
      true,
      false,
      false,
    ]);
  });

  test('the same seed gives the same sequence', () {
    final a = WorldRandom(123);
    final b = WorldRandom(123);
    for (var i = 0; i < 100; i++) {
      expect(a.nextDouble(), b.nextDouble());
    }
  });
}
