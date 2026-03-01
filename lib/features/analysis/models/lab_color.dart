import 'dart:math' as math;

/// CIE LAB colour representation used for spectrophotometric analysis.
///
/// - [l]: L* (lightness) in the range 0–100
/// - [a]: a* (green–red axis), roughly −128 to +127
/// - [b]: b* (blue–yellow axis), roughly −128 to +127
class LabColor {
  const LabColor({required this.l, required this.a, required this.b});

  /// L* – perceptual lightness (0 = black, 100 = diffuse white).
  final double l;

  /// a* – green (negative) to red (positive).
  final double a;

  /// b* – blue (negative) to yellow (positive).
  final double b;

  /// Converts to a map keyed by 'L', 'a', 'b'.
  Map<String, double> toMap() => {'L': l, 'a': a, 'b': b};

  /// Constructs a [LabColor] from a map with keys 'L', 'a', 'b'.
  factory LabColor.fromMap(Map<String, dynamic> map) {
    return LabColor(
      l: (map['L'] as num).toDouble(),
      a: (map['a'] as num).toDouble(),
      b: (map['b'] as num).toDouble(),
    );
  }

  /// Constructs a [LabColor] from a list `[L, a, b]`.
  factory LabColor.fromList(List<dynamic> values) {
    return LabColor(
      l: (values[0] as num).toDouble(),
      a: (values[1] as num).toDouble(),
      b: (values[2] as num).toDouble(),
    );
  }

  /// Euclidean distance in CIELAB space (quick approximation).
  double distanceTo(LabColor other) {
    final dl = l - other.l;
    final da = a - other.a;
    final db = b - other.b;
    return math.sqrt(dl * dl + da * da + db * db);
  }

  @override
  String toString() => 'LabColor(L: $l, a: $a, b: $b)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LabColor &&
          runtimeType == other.runtimeType &&
          l == other.l &&
          a == other.a &&
          b == other.b;

  @override
  int get hashCode => Object.hash(l, a, b);
}
