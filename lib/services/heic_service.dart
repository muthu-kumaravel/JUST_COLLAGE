import 'dart:typed_data';

import 'heic_service_stub.dart'
    if (dart.library.io) 'heic_service_io.dart'
    if (dart.library.js_interop) 'heic_service_web.dart' as platform;

class HeicService {
  /// Returns true if the bytes or file path indicate HEIC / HEIF format.
  static bool isHeic(Uint8List bytes, {String? path}) {
    return platform.isHeicData(bytes, path: path);
  }

  /// Attempts to convert HEIC/HEIF bytes to standard JPEG bytes.
  /// Returns null if conversion is not supported or not needed on the current platform.
  static Future<Uint8List?> convertToJpeg(Uint8List bytes, {String? filePath}) async {
    return platform.convertHeicToJpeg(bytes, filePath: filePath);
  }
}
