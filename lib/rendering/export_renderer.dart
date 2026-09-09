import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:image/image.dart' as img;
import '../models/collage_settings.dart';
import '../models/layout_result.dart';
import '../models/photo_asset.dart';
import 'collage_painter.dart';

/// Renders a high-resolution export of the collage independently of the screen UI.
///
/// Features:
/// - Produces high-resolution images (target 3000-4000px on longest edge).
/// - Memory-conscious: decodes photos to optimal tile resolutions rather than bloating RAM.
/// - Encodes to high-quality JPEG (quality 92-95).
class ExportRenderer {
  static const int defaultMaxExportDimension = 3600;
  static const int defaultJpegQuality = 93;

  /// Renders [layoutResult] and [photos] to high-quality JPEG bytes.
  static Future<Uint8List> renderToJpeg({
    required LayoutResult layoutResult,
    required CollageSettings settings,
    required List<PhotoAsset> photos,
    int maxDimension = defaultMaxExportDimension,
    int jpegQuality = defaultJpegQuality,
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0.1);

    // 1. Calculate target export dimensions
    final double aspect = layoutResult.canvasAspectRatio;
    int exportW;
    int exportH;
    if (aspect >= 1.0) {
      exportW = maxDimension;
      exportH = (maxDimension / aspect).round();
    } else {
      exportH = maxDimension;
      exportW = (maxDimension * aspect).round();
    }

    final double exportScale = exportW / layoutResult.canvasWidth;

    // 2. Load high-res images for each photo scaled to its export tile size
    final Map<String, PhotoAsset> exportPhotosById = {};
    final List<ui.Image> imagesToDispose = [];

    final photosMap = {for (var p in photos) p.id: p};

    for (int i = 0; i < layoutResult.placements.length; i++) {
      final placement = layoutResult.placements[i];
      final original = photosMap[placement.photoId];
      if (original == null) continue;

      // Target pixel dimension for this placement's export rect
      final targetTileW = (placement.rect.width * exportScale * 1.5).round().clamp(200, 4000);
      final targetTileH = (placement.rect.height * exportScale * 1.5).round().clamp(200, 4000);
      final maxTileDim = max(targetTileW, targetTileH);

      int targetW;
      int targetH;
      if (original.width >= original.height) {
        targetW = maxTileDim;
        targetH = (original.width > 0) ? max(1, (maxTileDim * original.height / original.width).round()) : maxTileDim;
      } else {
        targetH = maxTileDim;
        targetW = (original.height > 0) ? max(1, (maxTileDim * original.width / original.height).round()) : maxTileDim;
      }

      final codec = await ui.instantiateImageCodec(
        original.bytes,
        targetWidth: targetW,
        targetHeight: targetH,
      );
      final frame = await codec.getNextFrame();
      final hiResImage = frame.image;
      imagesToDispose.add(hiResImage);

      exportPhotosById[original.id] = PhotoAsset(
        id: original.id,
        name: original.name,
        width: hiResImage.width,
        height: hiResImage.height,
        aspectRatio: original.aspectRatio,
        bytes: original.bytes,
        previewImage: hiResImage,
      );

      onProgress?.call(0.1 + 0.5 * ((i + 1) / layoutResult.placements.length));
    }

    // 3. Load background image if present
    ui.Image? hiResBgImage;
    if (settings.backgroundImage != null) {
      final bg = settings.backgroundImage!;
      int bgW;
      int bgH;
      if (bg.width >= bg.height) {
        bgW = exportW;
        bgH = (bg.width > 0) ? max(1, (exportW * bg.height / bg.width).round()) : exportW;
      } else {
        bgH = exportH;
        bgW = (bg.height > 0) ? max(1, (exportH * bg.width / bg.height).round()) : exportH;
      }
      final bgCodec = await ui.instantiateImageCodec(
        bg.bytes,
        targetWidth: bgW,
        targetHeight: bgH,
      );
      final bgFrame = await bgCodec.getNextFrame();
      hiResBgImage = bgFrame.image;
      imagesToDispose.add(hiResBgImage);
    }

    // 4. Load border texture image if present
    ui.Image? hiResBorderImage;
    if (settings.borderImage != null) {
      final border = settings.borderImage!;
      int borderW;
      int borderH;
      if (border.width >= border.height) {
        borderW = exportW;
        borderH = (border.width > 0) ? max(1, (exportW * border.height / border.width).round()) : exportW;
      } else {
        borderH = exportH;
        borderW = (border.height > 0) ? max(1, (exportH * border.width / border.height).round()) : exportH;
      }
      final borderCodec = await ui.instantiateImageCodec(
        border.bytes,
        targetWidth: borderW,
        targetHeight: borderH,
      );
      final borderFrame = await borderCodec.getNextFrame();
      hiResBorderImage = borderFrame.image;
      imagesToDispose.add(hiResBorderImage);
    }

    onProgress?.call(0.65);

    // 5. Record high-res drawing commands
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    final painter = CollagePainter(
      layoutResult: layoutResult,
      settings: settings,
      photosById: exportPhotosById,
      backgroundUiImage: hiResBgImage,
      borderUiImage: hiResBorderImage,
      isExport: true,
    );

    painter.paint(canvas, ui.Size(exportW.toDouble(), exportH.toDouble()));

    final picture = recorder.endRecording();
    final exportedUiImage = await picture.toImage(exportW, exportH);
    picture.dispose();
    imagesToDispose.add(exportedUiImage);

    onProgress?.call(0.8);

    // 5. Convert ui.Image to RGBA bytes and encode to JPEG
    final byteData = await exportedUiImage.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) {
      throw StateError('Failed to obtain image byte data for export');
    }

    final rawBytes = byteData.buffer.asUint8List();
    final imgImage = img.Image.fromBytes(
      width: exportW,
      height: exportH,
      bytes: rawBytes.buffer,
      order: img.ChannelOrder.rgba,
    );

    final jpgBytes = Uint8List.fromList(img.encodeJpg(imgImage, quality: jpegQuality));

    // Clean up temporary high-res images
    for (final img in imagesToDispose) {
      img.dispose();
    }

    onProgress?.call(1.0);
    return jpgBytes;
  }
}
