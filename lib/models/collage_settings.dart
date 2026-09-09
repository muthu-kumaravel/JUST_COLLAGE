import 'package:flutter/material.dart';
import 'canvas_aspect_ratio.dart';
import 'crop_transform.dart';
import 'photo_asset.dart';

/// Supported collage layout modes.
enum CollageLayoutMode {
  natural('Natural'),
  uniform('Uniform'),
  scattered('Scattered');

  final String label;
  const CollageLayoutMode(this.label);
}

/// Holds all user-configurable settings and state for the collage.
class CollageSettings {
  final CollageLayoutMode layoutMode;
  final CanvasAspectRatio canvasAspectRatio;
  final double spacing;
  final double outerMargin;
  final Color backgroundColor;
  final PhotoAsset? backgroundImage;
  final double backgroundBlur;
  final double? uniformFrameAspectRatio;
  final CanvasOrientation uniformFrameOrientation;
  final double borderWidth;
  final Color borderColor;
  final PhotoAsset? borderImage;
  final Map<String, CropTransform> cropTransforms;
  final int seed;

  const CollageSettings({
    this.layoutMode = CollageLayoutMode.natural,
    this.canvasAspectRatio = CanvasAspectRatio.square1x1,
    this.spacing = 12.0,
    this.outerMargin = 12.0,
    this.backgroundColor = Colors.white,
    this.backgroundImage,
    this.backgroundBlur = 0.0,
    this.uniformFrameAspectRatio,
    this.uniformFrameOrientation = CanvasOrientation.portrait,
    this.borderWidth = 0.0,
    this.borderColor = Colors.white,
    this.borderImage,
    this.cropTransforms = const {},
    this.seed = 42,
  });

  CollageSettings copyWith({
    CollageLayoutMode? layoutMode,
    CanvasAspectRatio? canvasAspectRatio,
    double? spacing,
    double? outerMargin,
    Color? backgroundColor,
    PhotoAsset? backgroundImage,
    bool clearBackgroundImage = false,
    double? backgroundBlur,
    double? uniformFrameAspectRatio,
    bool clearUniformFrameAspectRatio = false,
    CanvasOrientation? uniformFrameOrientation,
    double? borderWidth,
    Color? borderColor,
    PhotoAsset? borderImage,
    bool clearBorderImage = false,
    Map<String, CropTransform>? cropTransforms,
    int? seed,
  }) {
    return CollageSettings(
      layoutMode: layoutMode ?? this.layoutMode,
      canvasAspectRatio: canvasAspectRatio ?? this.canvasAspectRatio,
      spacing: spacing ?? this.spacing,
      outerMargin: outerMargin ?? this.outerMargin,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      backgroundImage: clearBackgroundImage ? null : (backgroundImage ?? this.backgroundImage),
      backgroundBlur: backgroundBlur ?? this.backgroundBlur,
      uniformFrameAspectRatio: clearUniformFrameAspectRatio
          ? null
          : (uniformFrameAspectRatio ?? this.uniformFrameAspectRatio),
      uniformFrameOrientation: uniformFrameOrientation ?? this.uniformFrameOrientation,
      borderWidth: borderWidth ?? this.borderWidth,
      borderColor: borderColor ?? this.borderColor,
      borderImage: clearBorderImage ? null : (borderImage ?? this.borderImage),
      cropTransforms: cropTransforms ?? this.cropTransforms,
      seed: seed ?? this.seed,
    );
  }

  /// Sets or updates the crop transform for a specific photo.
  CollageSettings withCropTransform(String photoId, CropTransform transform) {
    final updated = Map<String, CropTransform>.from(cropTransforms);
    updated[photoId] = transform;
    return copyWith(cropTransforms: updated);
  }

  /// Returns a new settings instance with a regenerated seed for shuffling.
  CollageSettings nextShuffleSeed() {
    // Generate a fresh pseudo-random seed
    final newSeed = (seed * 1664525 + 1013904223) & 0x7FFFFFFF;
    return copyWith(seed: newSeed == seed ? seed + 1 : newSeed);
  }
}
