// Noise must give identical results on every platform. IEEE 754 guarantees
// that for + - * / and sqrt, but not for sin, cos or pow, which can differ in
// the last bit between the VM and JS. So the gradient directions are written
// out as literals instead of being computed.

const _a = 0.9238795325112867; // cos(22.5°)
const _b = 0.3826834323650898; // sin(22.5°)
const _c = 0.7071067811865476; // cos(45°)

/// 16 unit vectors, 22.5° apart, stored as x, y pairs.
const _gradients = <double>[
  1, 0, _a, _b, _c, _c, _b, _a, //
  0, 1, -_b, _a, -_c, _c, -_a, _b, //
  -1, 0, -_a, -_b, -_c, -_c, -_b, -_a, //
  0, -1, _b, -_a, _c, -_c, _a, -_b, //
];

/// Returns the dot product of ([x], [y]) with the gradient that [hash]
/// selects.
///
/// The top 4 bits of the hash choose one of 16 unit vectors.
double gradientDot(int hash, double x, double y) {
  final index = (hash >>> 28) << 1;
  return _gradients[index] * x + _gradients[index + 1] * y;
}
