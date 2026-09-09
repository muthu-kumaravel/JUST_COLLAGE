import 'dart:io';
import 'package:flutter/services.dart';

const _channel = MethodChannel('com.justcollage.heic');

bool isHeicData(Uint8List bytes, {String? path}) {
  if (path != null) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) return true;
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
  // 1. Primary path: Native Apple ImageIO framework via MethodChannel
  // Hardware-accelerated, runs directly in-memory, fully permitted inside App Sandbox
  if (Platform.isMacOS || Platform.isIOS) {
    try {
      final Uint8List? result = await _channel.invokeMethod<Uint8List>(
        'convertHeicToJpeg',
        {'data': bytes},
      );
      if (result != null && result.isNotEmpty) {
        return result;
      }
    } catch (_) {
      // If MethodChannel is not registered (e.g. headless unit tests), fall back below
    }
  }

  // 2. Secondary fallback on macOS: system 'sips' utility
  if (Platform.isMacOS) {
    Directory? tempDir;
    try {
      tempDir = Directory.systemTemp.createTempSync('heic_conv_');
      final String inputPath;
      if (filePath != null && File(filePath).existsSync()) {
        inputPath = filePath;
      } else {
        inputPath = '${tempDir.path}/temp_in.heic';
        await File(inputPath).writeAsBytes(bytes);
      }

      final outPath = '${tempDir.path}/converted_${DateTime.now().microsecondsSinceEpoch}.jpg';
      final result = await Process.run('sips', [
        '-s',
        'format',
        'jpeg',
        inputPath,
        '--out',
        outPath,
      ]);

      if (result.exitCode == 0) {
        final outFile = File(outPath);
        if (outFile.existsSync()) {
          final convertedBytes = await outFile.readAsBytes();
          return convertedBytes;
        }
      }
    } catch (_) {
    } finally {
      if (tempDir != null && tempDir.existsSync()) {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    }
  }

  return null;
}
