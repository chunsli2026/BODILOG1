import 'dart:convert';

/// Configuration for a single reactive pad on the test strip.
class PadConfig {
  /// Zero-based index of this pad on the strip.
  final int index;

  /// Human-readable parameter name (e.g. "Glucose", "pH").
  final String parameterName;

  /// Fractional position along the strip from top (0.0) to bottom (1.0).
  final double relativePosition;

  /// Pad width expressed as a fraction of the strip width.
  final double relativeWidth;

  /// Pad height expressed as a fraction of the strip height.
  final double relativeHeight;

  const PadConfig({
    required this.index,
    required this.parameterName,
    required this.relativePosition,
    required this.relativeWidth,
    required this.relativeHeight,
  });

  /// Deserialise from a JSON map.
  factory PadConfig.fromJson(Map<String, dynamic> json) {
    return PadConfig(
      index: json['index'] as int,
      parameterName: json['parameterName'] as String,
      relativePosition: (json['relativePosition'] as num).toDouble(),
      relativeWidth: (json['relativeWidth'] as num).toDouble(),
      relativeHeight: (json['relativeHeight'] as num).toDouble(),
    );
  }

  /// Serialise to a JSON-compatible map.
  Map<String, dynamic> toJson() {
    return {
      'index': index,
      'parameterName': parameterName,
      'relativePosition': relativePosition,
      'relativeWidth': relativeWidth,
      'relativeHeight': relativeHeight,
    };
  }
}

/// Describes the full geometric layout of a urinalysis test strip.
///
/// Layouts are loaded from JSON asset files under
/// `assets/strip_configs/<name>.json`.
class StripLayout {
  /// Unique identifier, e.g. `"standard_10"` or `"extended_14"`.
  final String name;

  /// Total number of reactive pads on this strip.
  final int padCount;

  /// Ordered list of pad configurations (top → bottom).
  final List<PadConfig> pads;

  /// Relative spacing between adjacent pads (0.0–1.0).
  final double padSpacing;

  /// Width-to-height aspect ratio of each pad.
  final double padAspectRatio;

  const StripLayout({
    required this.name,
    required this.padCount,
    required this.pads,
    required this.padSpacing,
    required this.padAspectRatio,
  });

  /// Deserialise from a JSON map (e.g. loaded from an asset file).
  factory StripLayout.fromJson(Map<String, dynamic> json) {
    final rawPads = json['pads'] as List<dynamic>;
    return StripLayout(
      name: json['name'] as String,
      padCount: json['padCount'] as int,
      padSpacing: (json['padSpacing'] as num).toDouble(),
      padAspectRatio: (json['padAspectRatio'] as num).toDouble(),
      pads: rawPads
          .map((p) => PadConfig.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Deserialise from a raw JSON string.
  factory StripLayout.fromJsonString(String source) {
    return StripLayout.fromJson(
      jsonDecode(source) as Map<String, dynamic>,
    );
  }

  /// Serialise to a JSON-compatible map.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'padCount': padCount,
      'padSpacing': padSpacing,
      'padAspectRatio': padAspectRatio,
      'pads': pads.map((p) => p.toJson()).toList(),
    };
  }
}
