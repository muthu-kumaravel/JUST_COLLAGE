import 'dart:ui';
import '../models/collage_settings.dart';
import '../models/layout_result.dart';
import '../models/photo_asset.dart';

/// Abstract base class for all collage layout engines.
abstract class CollageLayoutEngine {
  /// Computes the layout placements for [photos] based on [settings]
  /// within the coordinate space of [targetCanvasSize].
  LayoutResult computeLayout({
    required List<PhotoAsset> photos,
    required CollageSettings settings,
    required Size targetCanvasSize,
  });

  /// Computes the canonical canvas size based on canvas aspect ratio settings.
  static Size resolveCanvasSize(CollageSettings settings, List<PhotoAsset> photos, {double baseDimension = 1200.0}) {
    double ratio = settings.canvasAspectRatio.ratio;

    if (settings.canvasAspectRatio.isAuto) {
      if (photos.isEmpty) {
        ratio = 1.0;
      } else {
        // Average aspect ratio of photos
        final sumRatio = photos.fold<double>(0.0, (acc, p) => acc + p.aspectRatio);
        final avgRatio = sumRatio / photos.length;
        // Clamp to sensible auto bounds [0.5, 2.0]
        ratio = avgRatio.clamp(0.5, 2.0);
      }
    }

    if (ratio >= 1.0) {
      // Landscape or square: width is baseDimension, height is baseDimension / ratio
      return Size(baseDimension, baseDimension / ratio);
    } else {
      // Portrait: height is baseDimension, width is baseDimension * ratio
      return Size(baseDimension * ratio, baseDimension);
    }
  }
}
