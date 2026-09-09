import 'dart:js_interop';
import 'dart:typed_data';

@JS('convertHeicToJpeg')
external JSPromise<JSAny?>? _convertHeicToJpeg(JSAny heicBytes);

bool isHeicData(Uint8List bytes, {String? path}) {
  if (path != null) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) return true;
  }
  if (bytes.length >= 12) {
    // 'ftyp' in bytes 4..7
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
      // Also inspect compatible brands in the rest of the ftyp box
      final text = String.fromCharCodes(bytes.sublist(4, bytes.length > 64 ? 64 : bytes.length)).toLowerCase();
      if (text.contains('heic') || text.contains('mif1') || text.contains('msf1')) {
        return true;
      }
    }
  }
  return false;
}

Future<Uint8List?> convertHeicToJpeg(Uint8List bytes, {String? filePath}) async {
  try {
    final jsBytes = bytes.toJS;
    final promise = _convertHeicToJpeg(jsBytes);
    if (promise == null) return null;
    final result = await promise.toDart;
    if (result != null && result.isA<JSUint8Array>()) {
      return (result as JSUint8Array).toDart;
    }
  } catch (_) {}
  return null;
}
