import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import '../models/photo_asset.dart';

/// Service for picking photos locally from the device photo library (Photos app)
/// or from the Files app / document manager.
///
/// Adheres strictly to the privacy model:
/// - Photos are never copied permanently into persistent storage.
/// - Photos are never uploaded or sent over a network.
class PhotoPickerService {
  final ImagePicker _picker;

  PhotoPickerService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  /// Default photo picking: prompts from Photo Library (backward compatible).
  Future<List<PhotoAsset>> pickPhotos({void Function(String errorMessage)? onError}) async {
    return pickPhotosFromLibrary(onError: onError);
  }

  /// Prompts the user to select multiple photos from their device photo library (iOS Photos, Android Gallery).
  Future<List<PhotoAsset>> pickPhotosFromLibrary({void Function(String errorMessage)? onError}) async {
    final List<XFile> pickedFiles = await _picker.pickMultiImage(
      imageQuality: 98,
    );
    return _processPickedFiles(pickedFiles, onError: onError);
  }

  /// Prompts the user to select multiple image files from the Files app (iOS Files / iCloud Drive, Finder, Documents).
  Future<List<PhotoAsset>> pickPhotosFromFiles({void Function(String errorMessage)? onError}) async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'heic', 'heif', 'webp', 'gif'],
    );
    if (files.isEmpty) return [];

    final List<PhotoAsset> assets = [];
    final List<String> failedNames = [];

    for (final file in files) {
      try {
        final bytes = await file.readAsBytes();
        final asset = await PhotoAsset.fromBytes(
          id: DateTime.now().microsecondsSinceEpoch.toString() + file.name,
          name: file.name,
          bytes: bytes,
          path: file.path,
          xFile: file.xFile,
        );
        assets.add(asset);
      } catch (e) {
        failedNames.add(file.name);
      }
    }

    if (failedNames.isNotEmpty) {
      onError?.call(
        failedNames.length == 1
            ? 'Could not load "${failedNames.first}". Unsupported image format.'
            : 'Could not load ${failedNames.length} photos (${failedNames.join(', ')}). Unsupported image format.',
      );
    }

    return assets;
  }

  /// Displays an authentic Apple iOS ActionSheet prompting the user to choose
  /// between "Photo Library" (Apple Photos) or "Choose Files" (iOS Files / iCloud).
  Future<List<PhotoAsset>> showPhotoSourcePickerSheet(
    BuildContext context, {
    void Function(String errorMessage)? onError,
  }) async {
    final source = await showCupertinoModalPopup<String>(
      context: context,
      builder: (BuildContext ctx) => CupertinoActionSheet(
        title: const Text('Add Photos', style: TextStyle(fontWeight: FontWeight.w600)),
        message: const Text('Choose photos from your Photo Library or Files app'),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, 'photos'),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.photo_on_rectangle, size: 20),
                SizedBox(width: 10),
                Text('Photo Library'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, 'files'),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.folder, size: 20),
                SizedBox(width: 10),
                Text('Choose Files'),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx, null),
          child: const Text('Cancel'),
        ),
      ),
    );

    if (source == 'photos') {
      return pickPhotosFromLibrary(onError: onError);
    } else if (source == 'files') {
      return pickPhotosFromFiles(onError: onError);
    }
    return [];
  }

  /// Prompts the user to select a single photo as the collage background image.
  Future<PhotoAsset?> pickBackgroundImage({void Function(String errorMessage)? onError}) async {
    return pickBackgroundImageFromLibrary(onError: onError);
  }

  /// Prompts for background image from Photo Library.
  Future<PhotoAsset?> pickBackgroundImageFromLibrary({void Function(String errorMessage)? onError}) async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 98,
    );
    if (file == null) return null;

    try {
      return await PhotoAsset.fromXFile(file);
    } catch (e) {
      onError?.call('Could not load "${file.name}". Unsupported image format.');
      return null;
    }
  }

  /// Prompts for background image from Files.
  Future<PhotoAsset?> pickBackgroundImageFromFiles({void Function(String errorMessage)? onError}) async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'heic', 'heif', 'webp', 'gif'],
    );
    if (file == null) return null;

    try {
      final bytes = await file.readAsBytes();
      return await PhotoAsset.fromBytes(
        id: DateTime.now().microsecondsSinceEpoch.toString() + file.name,
        name: file.name,
        bytes: bytes,
        path: file.path,
        xFile: file.xFile,
      );
    } catch (e) {
      onError?.call('Could not load "${file.name}". Unsupported image format.');
    }
    return null;
  }

  /// ActionSheet for choosing background photo from Photo Library or Files.
  Future<PhotoAsset?> showBackgroundPhotoSourcePickerSheet(
    BuildContext context, {
    void Function(String errorMessage)? onError,
  }) async {
    final source = await showCupertinoModalPopup<String>(
      context: context,
      builder: (BuildContext ctx) => CupertinoActionSheet(
        title: const Text('Select Background Photo', style: TextStyle(fontWeight: FontWeight.w600)),
        message: const Text('Choose photo from Photo Library or Files app'),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, 'photos'),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.photo_on_rectangle, size: 20),
                SizedBox(width: 10),
                Text('Photo Library'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, 'files'),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.folder, size: 20),
                SizedBox(width: 10),
                Text('Choose Files'),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx, null),
          child: const Text('Cancel'),
        ),
      ),
    );

    if (source == 'photos') {
      return pickBackgroundImageFromLibrary(onError: onError);
    } else if (source == 'files') {
      return pickBackgroundImageFromFiles(onError: onError);
    }
    return null;
  }

  Future<List<PhotoAsset>> _processPickedFiles(
    List<XFile> pickedFiles, {
    void Function(String errorMessage)? onError,
  }) async {
    if (pickedFiles.isEmpty) return [];

    final List<PhotoAsset> assets = [];
    final List<String> failedNames = [];

    for (final file in pickedFiles) {
      try {
        final asset = await PhotoAsset.fromXFile(file);
        assets.add(asset);
      } catch (e) {
        failedNames.add(file.name);
      }
    }

    if (failedNames.isNotEmpty) {
      onError?.call(
        failedNames.length == 1
            ? 'Could not load "${failedNames.first}". Unsupported image format.'
            : 'Could not load ${failedNames.length} photos (${failedNames.join(', ')}). Unsupported image format.',
      );
    }

    return assets;
  }
}
