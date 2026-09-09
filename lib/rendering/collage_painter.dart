import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/collage_settings.dart';
import '../models/crop_transform.dart';
import '../models/layout_result.dart';
import '../models/photo_asset.dart';

/// Renders a [LayoutResult] onto a Flutter [Canvas].
///
/// Features:
/// - Exact, pixel-consistent rendering for preview and high-resolution export.
/// - Full image border system: custom border width, solid color palette, or custom uploaded image texture.
/// - Drop shadows and smooth aspect-fill clipping.
class CollagePainter extends CustomPainter {
  final LayoutResult layoutResult;
  final CollageSettings settings;
  final Map<String, PhotoAsset> photosById;
  final ui.Image? backgroundUiImage;
  final ui.Image? borderUiImage;
  final bool isExport;

  CollagePainter({
    required this.layoutResult,
    required this.settings,
    required this.photosById,
    this.backgroundUiImage,
    this.borderUiImage,
    this.isExport = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Uniform scale strictly preserves aspect ratio without non-uniform stretching
    final double scale = min(
      size.width / (layoutResult.canvasWidth > 0 ? layoutResult.canvasWidth : 1),
      size.height / (layoutResult.canvasHeight > 0 ? layoutResult.canvasHeight : 1),
    );
    final double offsetX = (size.width - layoutResult.canvasWidth * scale) / 2.0;
    final double offsetY = (size.height - layoutResult.canvasHeight * scale) / 2.0;

    canvas.save();
    canvas.translate(offsetX, offsetY);
    canvas.scale(scale, scale);

    final canvasRect = Rect.fromLTWH(0, 0, layoutResult.canvasWidth, layoutResult.canvasHeight);

    // 1. Render Background
    _drawBackground(canvas, canvasRect);

    // 2. Render Photos
    if (settings.layoutMode == CollageLayoutMode.scattered) {
      _drawScatteredLayout(canvas);
    } else {
      _drawJustifiedOrUniformLayout(canvas);
    }

    canvas.restore();
  }

  void _drawBackground(Canvas canvas, Rect rect) {
    if (backgroundUiImage != null) {
      final img = backgroundUiImage!;
      final srcRect = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());

      final double scale = max(rect.width / img.width, rect.height / img.height);
      final double destW = img.width * scale;
      final double destH = img.height * scale;
      final double destX = rect.left + (rect.width - destW) / 2.0;
      final double destY = rect.top + (rect.height - destH) / 2.0;
      final dstRect = Rect.fromLTWH(destX, destY, destW, destH);

      canvas.save();
      canvas.clipRect(rect);

      if (settings.backgroundBlur > 0) {
        final blur = settings.backgroundBlur;
        final paint = Paint()
          ..imageFilter = ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur)
          ..filterQuality = ui.FilterQuality.medium;
        canvas.drawImageRect(img, srcRect, dstRect, paint);
      } else {
        final paint = Paint()..filterQuality = ui.FilterQuality.medium;
        canvas.drawImageRect(img, srcRect, dstRect, paint);
      }

      canvas.restore();
    } else {
      final bgPaint = Paint()..color = settings.backgroundColor;
      canvas.drawRect(rect, bgPaint);
    }
  }

  void _drawJustifiedOrUniformLayout(Canvas canvas) {
    final paint = Paint()
      ..isAntiAlias = true
      ..filterQuality = isExport ? ui.FilterQuality.high : ui.FilterQuality.medium;

    final double borderW = settings.borderWidth;

    for (final placement in layoutResult.placements) {
      final photo = photosById[placement.photoId];
      if (photo == null) continue;

      final ui.Image? image = photo.previewImage;
      if (image == null) continue;

      final frame = placement.rect;

      if (borderW > 0) {
        // Draw border under photo frame
        _drawBorderSurface(canvas, frame);

        // Deflate frame for image content
        final innerRect = frame.deflate(borderW);
        if (innerRect.width > 2 && innerRect.height > 2) {
          canvas.save();
          canvas.clipRect(innerRect);
          _drawImageAspectFill(
            canvas: canvas,
            image: image,
            destRect: innerRect,
            crop: placement.cropTransform,
            paint: paint,
          );
          canvas.restore();
        }
      } else {
        canvas.save();
        canvas.clipRect(frame);
        _drawImageAspectFill(
          canvas: canvas,
          image: image,
          destRect: frame,
          crop: placement.cropTransform,
          paint: paint,
        );
        canvas.restore();
      }
    }
  }

  void _drawScatteredLayout(Canvas canvas) {
    final sortedPlacements = List<CollageItemPlacement>.from(layoutResult.placements)
      ..sort((a, b) => a.zIndex.compareTo(b.zIndex));

    final paint = Paint()
      ..isAntiAlias = true
      ..filterQuality = isExport ? ui.FilterQuality.high : ui.FilterQuality.medium;

    final double borderW = settings.borderWidth;

    for (final placement in sortedPlacements) {
      final photo = photosById[placement.photoId];
      if (photo == null) continue;

      final ui.Image? image = photo.previewImage;
      if (image == null) continue;

      final center = placement.rect.center;
      final w = placement.rect.width;
      final h = placement.rect.height;

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(placement.rotation);

      // Card rect strictly matches frame bounds
      final cardRect = Rect.fromCenter(
        center: Offset.zero,
        width: w,
        height: h,
      );

      // Drop shadow around card
      final shadowPath = Path()..addRect(cardRect.shift(const Offset(0, 4)));
      canvas.drawShadow(shadowPath, Colors.black.withValues(alpha: 0.35), 8.0, true);

      // Draw border surface when border width > 0
      if (borderW > 0) {
        _drawBorderSurface(canvas, cardRect);
      }

      // Deflate inner rect to scale down the photo inside the border
      final innerRect = borderW > 0 ? cardRect.deflate(borderW) : cardRect;
      if (innerRect.width > 2 && innerRect.height > 2) {
        canvas.save();
        canvas.clipRect(innerRect);
        _drawImageAspectFill(
          canvas: canvas,
          image: image,
          destRect: innerRect,
          crop: placement.cropTransform,
          paint: paint,
        );
        canvas.restore();
      }

      canvas.restore();
    }
  }

  void _drawBorderSurface(Canvas canvas, Rect rect) {
    if (borderUiImage != null) {
      final img = borderUiImage!;
      final srcRect = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
      final double scale = max(rect.width / img.width, rect.height / img.height);
      final double destW = img.width * scale;
      final double destH = img.height * scale;
      final double destX = rect.left + (rect.width - destW) / 2.0;
      final double destY = rect.top + (rect.height - destH) / 2.0;
      final dstRect = Rect.fromLTWH(destX, destY, destW, destH);

      canvas.save();
      canvas.clipRect(rect);
      canvas.drawImageRect(img, srcRect, dstRect, Paint()..filterQuality = ui.FilterQuality.medium);
      canvas.restore();
    } else {
      final borderPaint = Paint()..color = settings.borderColor;
      canvas.drawRect(rect, borderPaint);
    }
  }

  void _drawImageAspectFill({
    required Canvas canvas,
    required ui.Image image,
    required Rect destRect,
    required CropTransform crop,
    required Paint paint,
  }) {
    final double srcW = image.width.toDouble();
    final double srcH = image.height.toDouble();

    final bool isRotatedSideways = crop.rotationQuarterTurns % 2 != 0;
    final double effectiveSrcW = isRotatedSideways ? srcH : srcW;
    final double effectiveSrcH = isRotatedSideways ? srcW : srcH;

    final double baseScale = max(destRect.width / effectiveSrcW, destRect.height / effectiveSrcH);
    final double totalScale = baseScale * max(1.0, crop.scale);
    final double effectiveScaledW = effectiveSrcW * totalScale;
    final double effectiveScaledH = effectiveSrcH * totalScale;

    final double maxOffsetX = max(0.0, (effectiveScaledW - destRect.width) / 2.0);
    final double maxOffsetY = max(0.0, (effectiveScaledH - destRect.height) / 2.0);

    final double panX = (crop.offset.dx * maxOffsetX).clamp(-maxOffsetX, maxOffsetX);
    final double panY = (crop.offset.dy * maxOffsetY).clamp(-maxOffsetY, maxOffsetY);

    final double centerX = destRect.center.dx + panX;
    final double centerY = destRect.center.dy + panY;

    canvas.save();
    canvas.translate(centerX, centerY);
    if (crop.flipHorizontal) {
      canvas.scale(-1.0, 1.0);
    }
    if (crop.rotationQuarterTurns != 0) {
      canvas.rotate(crop.rotationQuarterTurns * (pi / 2.0));
    }

    final srcRect = Rect.fromLTWH(0, 0, srcW, srcH);
    final drawRect = Rect.fromCenter(
      center: Offset.zero,
      width: srcW * totalScale,
      height: srcH * totalScale,
    );

    canvas.drawImageRect(image, srcRect, drawRect, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CollagePainter oldDelegate) {
    return oldDelegate.layoutResult != layoutResult ||
        oldDelegate.settings != settings ||
        oldDelegate.backgroundUiImage != backgroundUiImage ||
        oldDelegate.borderUiImage != borderUiImage;
  }
}
