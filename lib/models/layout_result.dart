import 'dart:ui';
import 'crop_transform.dart';

/// Defines the placement of a single photo on the collage canvas.
class CollageItemPlacement {
  final String photoId;
  /// The bounding box frame of this item on the normalized or absolute canvas coordinate space.
  final Rect rect;
  /// Crop transform (pan & zoom) applied to the image inside this frame.
  final CropTransform cropTransform;
  /// Rotation in radians (strictly in range [-15°, +15°] for scattered layout; 0 for others).
  final double rotation;
  /// Additional scale factor applied to the item.
  final double scale;
  /// Stacking order (z-index) for layered layouts like scattered.
  final int zIndex;
  /// Source aspect ratio (width / height) of the photo.
  final double sourceAspectRatio;

  const CollageItemPlacement({
    required this.photoId,
    required this.rect,
    this.cropTransform = CropTransform.identity,
    this.rotation = 0.0,
    this.scale = 1.0,
    this.zIndex = 0,
    required this.sourceAspectRatio,
  });

  CollageItemPlacement copyWith({
    String? photoId,
    Rect? rect,
    CropTransform? cropTransform,
    double? rotation,
    double? scale,
    int? zIndex,
    double? sourceAspectRatio,
  }) {
    return CollageItemPlacement(
      photoId: photoId ?? this.photoId,
      rect: rect ?? this.rect,
      cropTransform: cropTransform ?? this.cropTransform,
      rotation: rotation ?? this.rotation,
      scale: scale ?? this.scale,
      zIndex: zIndex ?? this.zIndex,
      sourceAspectRatio: sourceAspectRatio ?? this.sourceAspectRatio,
    );
  }

  @override
  String toString() =>
      'CollageItemPlacement(photoId: $photoId, rect: $rect, rot: ${rotation.toStringAsFixed(2)}, z: $zIndex)';
}

/// The deterministic result of a layout calculation.
/// Both preview and export renderers consume this exact object.
class LayoutResult {
  /// Target canvas width.
  final double canvasWidth;
  /// Target canvas height.
  final double canvasHeight;
  /// Ordered list of item placements.
  final List<CollageItemPlacement> placements;
  /// Canvas aspect ratio (width / height).
  final double canvasAspectRatio;
  /// Viable frame aspect ratios (for Uniform layout candidate selection).
  final List<double> candidateFrameRatios;
  /// The selected or default frame aspect ratio in Uniform layout.
  final double? activeFrameRatio;
  /// The calculated "Best Fit" frame ratio that touches all 4 edges of the canvas.
  final double? bestFitFrameRatio;

  const LayoutResult({
    required this.canvasWidth,
    required this.canvasHeight,
    required this.placements,
    required this.canvasAspectRatio,
    this.candidateFrameRatios = const [],
    this.activeFrameRatio,
    this.bestFitFrameRatio,
  });

  Size get canvasSize => Size(canvasWidth, canvasHeight);

  @override
  String toString() =>
      'LayoutResult(size: ${canvasWidth}x$canvasHeight, items: ${placements.length})';
}
