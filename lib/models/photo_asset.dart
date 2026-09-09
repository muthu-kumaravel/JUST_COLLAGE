import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:image_picker/image_picker.dart';
import '../services/heic_service.dart';

/// Represents a photo selected by the user for the collage.
///
/// Designed to be privacy-preserving and memory-conscious:
/// - Source photos are not saved permanently.
/// - Previews are downsampled upon decoding to prevent GPU/RAM exhaustion.
/// - Full-resolution images are loaded on demand during high-resolution export.
class PhotoAsset {
  final String id;
  final String name;
  final int width;
  final int height;
  final double aspectRatio;
  final Uint8List bytes;
  final String? path;
  final XFile? xFile;

  // Cached downsampled ui.Image for fast preview rendering
  ui.Image? previewImage;

  PhotoAsset({
    required this.id,
    required this.name,
    required this.width,
    required this.height,
    required this.aspectRatio,
    required this.bytes,
    this.path,
    this.xFile,
    this.previewImage,
  });

  void setPreviewImage(ui.Image image) {
    previewImage = image;
  }

  /// Creates a [PhotoAsset] from an [XFile] by decoding its metadata
  /// and preparing a downsampled preview image.
  static Future<PhotoAsset> fromXFile(XFile file, {int previewMaxSize = 1024}) async {
    final bytes = await file.readAsBytes();
    return fromBytes(
      id: file.path.isNotEmpty ? file.path : '${file.name}_${DateTime.now().microsecondsSinceEpoch}',
      name: file.name,
      bytes: bytes,
      path: file.path.isNotEmpty ? file.path : null,
      xFile: file,
      previewMaxSize: previewMaxSize,
    );
  }

  /// Creates a [PhotoAsset] from raw bytes.
  static Future<PhotoAsset> fromBytes({
    required String id,
    required String name,
    required Uint8List bytes,
    String? path,
    XFile? xFile,
    int previewMaxSize = 1024,
  }) async {
    Uint8List effectiveBytes = bytes;
    ui.Codec? codec;

    // 1. Try decoding directly with Flutter's native codec
    try {
      codec = await ui.instantiateImageCodec(effectiveBytes);
    } catch (e) {
      // If direct decode failed, check if this is a HEIC image that can be converted
      if (HeicService.isHeic(effectiveBytes, path: path ?? xFile?.path ?? name)) {
        final converted = await HeicService.convertToJpeg(
          effectiveBytes,
          filePath: path ?? xFile?.path,
        );
        if (converted != null) {
          effectiveBytes = converted;
          codec = await ui.instantiateImageCodec(effectiveBytes);
        } else {
          throw UnsupportedError(
            'HEIC format is not supported on this platform. Please upload a JPG or PNG image.',
          );
        }
      } else {
        rethrow;
      }
    }

    final frame = await codec.getNextFrame();
    final fullImage = frame.image;
    final int origWidth = fullImage.width;
    final int origHeight = fullImage.height;

    // If already smaller than previewMaxSize, reuse fullImage as previewImage
    ui.Image previewImg;
    if (origWidth <= previewMaxSize && origHeight <= previewMaxSize) {
      previewImg = fullImage;
    } else {
      fullImage.dispose();
      // Calculate downsampled preview preserving exact aspect ratio with both dimensions
      int targetW;
      int targetH;
      if (origWidth >= origHeight) {
        targetW = previewMaxSize;
        targetH = (origWidth > 0) ? max(1, (previewMaxSize * origHeight / origWidth).round()) : previewMaxSize;
      } else {
        targetH = previewMaxSize;
        targetW = (origHeight > 0) ? max(1, (previewMaxSize * origWidth / origHeight).round()) : previewMaxSize;
      }

      final downsampledCodec = await ui.instantiateImageCodec(
        effectiveBytes,
        targetWidth: targetW,
        targetHeight: targetH,
      );
      final downsampledFrame = await downsampledCodec.getNextFrame();
      previewImg = downsampledFrame.image;
    }

    final double trueRatio = origWidth / (origHeight > 0 ? origHeight : 1);

    return PhotoAsset(
      id: id,
      name: name,
      width: origWidth,
      height: origHeight,
      aspectRatio: trueRatio,
      bytes: effectiveBytes,
      path: path,
      xFile: xFile,
      previewImage: previewImg,
    );
  }

  /// Loads the full-resolution [ui.Image] for high-resolution export rendering.
  /// Caller is responsible for disposing the returned image after export.
  Future<ui.Image> loadFullResolutionImage() async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  /// Disposes cached preview image to free memory.
  void dispose() {
    previewImage?.dispose();
    previewImage = null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhotoAsset && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'PhotoAsset(id: $id, name: $name, size: ${width}x$height, ratio: $aspectRatio)';
}
