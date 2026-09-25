// The hash is SquirrelNoise5 by Squirrel Eiserloh, used under CC-BY-3.0 US:
// https://creativecommons.org/licenses/by/3.0/us/
//
// Everything here works on unsigned 32-bit values and produces the same
// results on the VM, AOT, wasm and JS. On JS, `int`s are doubles, so products
// above 2^53 lose precision. Multiplications go through [_mul32], which keeps
// every intermediate value below that limit.

import 'dart:convert';

const _mask32 = 0xFFFFFFFF;

const _noise1 = 0xD2A80A3F;
const _noise2 = 0xA884F197;
const _noise3 = 0x6C736F4B;
const _noise4 = 0xB79F3ABB;
const _noise5 = 0x1B56C4F5;

const _primeY = 198491317;
const _primeZ = 6542989;

/// 2^-32, turns a 32-bit hash into a double in [0, 1).
const _toUnit = 1 / 4294967296;

/// Hashes [x] with [seed] into an unsigned 32-bit integer.
///
/// [x] and [seed] may be any integer; only their low 32 bits are used.
int hash1(int x, int seed) {
  var bits = _mul32(x & _mask32, _noise1);
  bits = (bits + (seed & _mask32)) & _mask32;
  bits ^= bits >>> 9;
  bits = (bits + _noise2) & _mask32;
  bits ^= bits >>> 11;
  bits = _mul32(bits, _noise3);
  bits ^= bits >>> 13;
  bits = (bits + _noise4) & _mask32;
  bits ^= bits >>> 15;
  bits = _mul32(bits, _noise5);
  bits ^= bits >>> 17;
  return bits;
}

/// Hashes the point ([x], [y]) with [seed] into an unsigned 32-bit integer.
///
/// Distinct points only collide when they are tens of thousands of units
/// apart (the closest pair is 1784 apart on x and 48664 on y).
int hash2(int x, int y, int seed) {
  return hash1(x + _mul32(y & _mask32, _primeY), seed);
}

/// Hashes the point ([x], [y], [z]) with [seed] into an unsigned 32-bit
/// integer.
int hash3(int x, int y, int z, int seed) {
  return hash1(
    x + _mul32(y & _mask32, _primeY) + _mul32(z & _mask32, _primeZ),
    seed,
  );
}

/// Derives an independent seed for the thing called [name] from [worldSeed].
///
/// Noise fields, scatters and passes each get their own seed this way, so
/// they don't produce correlated patterns. The result depends only on the
/// name, so adding or reordering things doesn't change existing ones.
int deriveSeed(int worldSeed, String name) {
  // 32-bit FNV-1a over the UTF-8 bytes of the name.
  var nameHash = 0x811C9DC5;
  for (final byte in utf8.encode(name)) {
    nameHash = _mul32(nameHash ^ byte, 0x01000193);
  }
  return hash1(nameHash, worldSeed);
}

/// Maps a 32-bit [hash] to a double in the range [0, 1).
double hashToUnit(int hash) => hash * _toUnit;

/// Maps a 32-bit [hash] to a double in the range [-1, 1).
double hashToSigned(int hash) => hash * (2 * _toUnit) - 1;

/// Multiplies two unsigned 32-bit integers modulo 2^32.
///
/// [a] is split into 16-bit halves so no intermediate product exceeds 2^48,
/// which a double represents exactly.
int _mul32(int a, int b) {
  final low = (a & 0xFFFF) * b;
  final high = (((a >>> 16) * b) & 0xFFFF) << 16;
  return (low + high) & _mask32;
}
