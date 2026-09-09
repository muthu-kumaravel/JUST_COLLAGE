import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/collage_settings.dart';
import '../models/layout_result.dart';
import '../models/photo_asset.dart';
import '../rendering/collage_painter.dart';

/// The interactive collage canvas preview supporting pinch-to-zoom, pan,
/// and tap-to-adjust for individual photos.
class CollagePreview extends StatelessWidget {
  final LayoutResult layoutResult;
  final CollageSettings settings;
  final Map<String, PhotoAsset> photosById;
  final ui.Image? backgroundUiImage;
  final ui.Image? borderUiImage;
  final EdgeInsets padding;
  final void Function(PhotoAsset photo, CollageItemPlacement placement)? onPhotoTapped;

  const CollagePreview({
    super.key,
    required this.layoutResult,
    required this.settings,
    required this.photosById,
    this.backgroundUiImage,
    this.borderUiImage,
    this.padding = EdgeInsets.zero,
    this.onPhotoTapped,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double availW = (constraints.maxWidth - padding.horizontal).clamp(100.0, constraints.maxWidth);
        final double availH = (constraints.maxHeight - padding.vertical).clamp(100.0, constraints.maxHeight);

        // Determine preview display size that fits within available unobstructed area with padding
        final double canvasAspect = layoutResult.canvasAspectRatio;
        double displayW = availW - 32;
        double displayH = displayW / canvasAspect;

        if (displayH > availH - 32) {
          displayH = availH - 32;
          displayW = displayH * canvasAspect;
        }

        displayW = displayW.clamp(100.0, availW);
        displayH = displayH.clamp(100.0, availH);

        final displaySize = Size(displayW, displayH);

        return Padding(
          padding: padding,
          child: Center(
            child: InteractiveViewer(
              clipBehavior: Clip.none,
              boundaryMargin: const EdgeInsets.all(double.infinity),
              minScale: 0.5,
              maxScale: 5.0,
            child: GestureDetector(
              onTapUp: (details) {
                if (onPhotoTapped == null) return;
                // Convert local tap coordinate to canonical canvas coordinate
                final scaleX = layoutResult.canvasWidth / displayW;
                final scaleY = layoutResult.canvasHeight / displayH;
                final canvasTap = Offset(
                  details.localPosition.dx * scaleX,
                  details.localPosition.dy * scaleY,
                );

                // Find top-most hit item (reverse z-order)
                final sorted = List<CollageItemPlacement>.from(layoutResult.placements)
                  ..sort((a, b) => b.zIndex.compareTo(a.zIndex));

                for (final placement in sorted) {
                  if (placement.rect.contains(canvasTap)) {
                    final photo = photosById[placement.photoId];
                    if (photo != null) {
                      onPhotoTapped!(photo, placement);
                    }
                    break;
                  }
                }
              },
              child: Container(
                width: displayW,
                height: displayH,
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 20,
                      spreadRadius: 2,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: CustomPaint(
                  size: displaySize,
                  painter: CollagePainter(
                    layoutResult: layoutResult,
                    settings: settings,
                    photosById: photosById,
                    backgroundUiImage: backgroundUiImage,
                    borderUiImage: borderUiImage,
                    isExport: false,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      },
    );
  }
}
