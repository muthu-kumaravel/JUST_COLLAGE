import 'dart:typed_data';

bool isHeicData(Uint8List bytes, {String? path}) {
  if (path != null) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.heic') || lower.endsWith('.heif') || lower.contains('.heic') || lower.contains('.heif')) {
      return true;
    }
  }
  if (bytes.length >= 12) {
    if (bytes[4] == 0x66 && bytes[5] == 0x74 && bytes[6] == 0x79 && bytes[7] == 0x70) {
      final brand = String.fromCharCodes(bytes.sublist(8, 12)).toLowerCase();
      if (brand == 'heic' ||
          brand == 'heix' ||
          brand == 'heim' ||
          brand == 'heis' ||
          brand == 'mif1' ||
          brand == 'msf1') {
        return true;
      }
      final headerLimit = bytes.length > 64 ? 64 : bytes.length;
      final text = String.fromCharCodes(bytes.sublist(4, headerLimit)).toLowerCase();
      if (text.contains('heic') || text.contains('mif1') || text.contains('msf1')) {
        return true;
      }
    }
  }
  return false;
}

Future<Uint8List?> convertHeicToJpeg(Uint8List bytes, {String? filePath}) async {
  return null;
}
