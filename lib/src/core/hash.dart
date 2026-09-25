// The hash is SquirrelNoise5 by Squirrel Eiserloh, used under CC-BY-3.0 US:
// https://creativecommons.org/licenses/by/3.0/us/
//
// Everything here works on unsigned 32-bit values and produces the same
// results on the VM, AOT, wasm and JS. On JS, `int`s are doubles, so products
// above 2^53 lose precision. Multiplications go through [_mul32], which keeps
// every intermediate value below that limit.

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
