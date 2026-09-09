import 'dart:ui';

/// Represents a pan/zoom crop transform applied to an image inside a frame,
/// with support for 90° rotation increments and horizontal flipping.
///
/// [scale] is the zoom level (>= 1.0, where 1.0 is the aspect-fill fit).
/// [offset] is the normalized translation offset in range [-1.0, 1.0],
/// where (0, 0) means centered.
/// [rotationQuarterTurns] is the number of 90-degree clockwise rotations (0, 1, 2, 3).
/// [flipHorizontal] indicates whether the image is mirrored horizontally.
class CropTransform {
  final double scale;
  final Offset offset;
  final int rotationQuarterTurns;
  final bool flipHorizontal;

  const CropTransform({
    this.scale = 1.0,
    this.offset = Offset.zero,
    this.rotationQuarterTurns = 0,
    this.flipHorizontal = false,
  });

  static const CropTransform identity = CropTransform();

  CropTransform copyWith({
    double? scale,
    Offset? offset,
    int? rotationQuarterTurns,
    bool? flipHorizontal,
  }) {
    return CropTransform(
      scale: scale ?? this.scale,
      offset: offset ?? this.offset,
      rotationQuarterTurns: rotationQuarterTurns ?? this.rotationQuarterTurns,
      flipHorizontal: flipHorizontal ?? this.flipHorizontal,
    );
  }

  Map<String, dynamic> toJson() => {
        'scale': scale,
        'dx': offset.dx,
        'dy': offset.dy,
        'rot': rotationQuarterTurns,
        'flip': flipHorizontal,
      };

  factory CropTransform.fromJson(Map<String, dynamic> json) => CropTransform(
        scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
        offset: Offset(
          (json['dx'] as num?)?.toDouble() ?? 0.0,
          (json['dy'] as num?)?.toDouble() ?? 0.0,
        ),
        rotationQuarterTurns: (json['rot'] as num?)?.toInt() ?? 0,
        flipHorizontal: (json['flip'] as bool?) ?? false,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CropTransform &&
          runtimeType == other.runtimeType &&
          scale == other.scale &&
          offset == other.offset &&
          rotationQuarterTurns == other.rotationQuarterTurns &&
          flipHorizontal == other.flipHorizontal;

  @override
  int get hashCode => Object.hash(scale, offset, rotationQuarterTurns, flipHorizontal);

  @override
  String toString() =>
      'CropTransform(scale: $scale, offset: $offset, rot: $rotationQuarterTurns, flip: $flipHorizontal)';
}
