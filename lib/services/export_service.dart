import 'dart:io' as io;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'web_download.dart';

/// Platform-specific export actions: Save to Photos, Save to Files, Share, and Web Download.
class ExportService {
  const ExportService();

  /// Saves the image bytes directly to the device photo library / gallery.
  /// On Web, initiates a browser download.
  /// On macOS, if Gal encounters permission restrictions, seamlessly falls back to ~/Pictures.
  Future<bool> saveToPhotoLibrary(Uint8List bytes, {String? filename}) async {
    final name = filename ?? 'collage_${DateTime.now().millisecondsSinceEpoch}.jpg';

    if (kIsWeb) {
      triggerWebDownload(bytes, name);
      return true;
    }

    try {
      // Check/request permission through Gal
      final hasAccess = await Gal.hasAccess(toAlbum: false);
      if (!hasAccess) {
        final granted = await Gal.requestAccess(toAlbum: false);
        if (!granted) {
          // If macOS Photos access is restricted, attempt fallback to user's Pictures folder
          if (io.Platform.isMacOS) {
            return await _saveToMacPictures(bytes, name);
          }
          return false;
        }
      }

      await Gal.putImageBytes(bytes, name: name);
      return true;
    } catch (e) {
      debugPrint('Error saving to photo library via Gal: $e');
      if (io.Platform.isMacOS) {
        return await _saveToMacPictures(bytes, name);
      }
      return false;
    }
  }

  /// Direct fallback on macOS to write into the user's Pictures directory (~/Pictures).
  Future<bool> _saveToMacPictures(Uint8List bytes, String filename) async {
    try {
      final home = io.Platform.environment['HOME'];
      if (home != null && home.isNotEmpty) {
        final picturesDir = io.Directory('$home/Pictures');
        if (picturesDir.existsSync()) {
          final file = io.File('${picturesDir.path}/$filename');
          await file.writeAsBytes(bytes);
          debugPrint('Saved collage successfully to macOS Pictures: ${file.path}');
          return true;
        }
      }
      // Or try application documents or downloads
      final dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
      final file = io.File('${dir.path}/$filename');
      await file.writeAsBytes(bytes);
      debugPrint('Saved collage successfully to: ${file.path}');
      return true;
    } catch (e) {
      debugPrint('macOS Pictures fallback failed: $e');
      return false;
    }
  }

  /// Opens the native platform "Save As..." dialog (macOS / Windows / Linux / iOS Files)
  /// allowing the user to select the exact destination folder and filename.
  Future<String?> saveToFilePicker(Uint8List bytes, {String? filename}) async {
    final name = filename ?? 'collage_${DateTime.now().millisecondsSinceEpoch}.jpg';

    if (kIsWeb) {
      triggerWebDownload(bytes, name);
      return name;
    }

    try {
      final uri = await FilePicker.saveFile(
        dialogTitle: 'Save Collage',
        fileName: name,
        bytes: bytes,
        mimeType: 'image/jpeg',
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg'],
      );

      if (uri != null) {
        return uri.path.isNotEmpty ? uri.path : uri.toString();
      }
    } catch (e) {
      debugPrint('Error saving via file picker: $e');
    }
    return null;
  }

  /// Opens the native platform share sheet.
  Future<void> shareImage(Uint8List bytes, {String? filename}) async {
    final name = filename ?? 'collage_${DateTime.now().millisecondsSinceEpoch}.jpg';

    if (kIsWeb) {
      triggerWebDownload(bytes, name);
      return;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final tempFile = io.File('${tempDir.path}/$name');
      await tempFile.writeAsBytes(bytes);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(tempFile.path, mimeType: 'image/jpeg', name: name)],
          subject: 'My Photo Collage',
        ),
      );
    } catch (e) {
      debugPrint('Error sharing image: $e');
    }
  }

  /// Triggers a browser download on Web.
  void downloadOnWeb(Uint8List bytes, {String? filename}) {
    final name = filename ?? 'collage_${DateTime.now().millisecondsSinceEpoch}.jpg';
    triggerWebDownload(bytes, name);
  }
}
