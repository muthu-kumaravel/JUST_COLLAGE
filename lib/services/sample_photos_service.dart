import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../models/photo_asset.dart';

/// Provides curated high-quality demo photos in-memory for instant testing and zero-friction onboarding.
class SamplePhotosService {
  static Future<List<PhotoAsset>> generateSamplePhotos() async {
    final List<PhotoAsset> list = [];

    final samples = [
      {'name': 'Golden Sunset', 'w': 1080, 'h': 1350, 'c1': [255, 140, 0], 'c2': [180, 40, 70]},
      {'name': 'Ocean Horizon', 'w': 1350, 'h': 900, 'c1': [0, 119, 182], 'c2': [3, 4, 94]},
      {'name': 'Emerald Forest', 'w': 1080, 'h': 1080, 'c1': [45, 106, 79], 'c2': [8, 28, 21]},
      {'name': 'Desert Mirage', 'w': 900, 'h': 1200, 'c1': [224, 122, 95], 'c2': [61, 64, 91]},
    ];

    for (int i = 0; i < samples.length; i++) {
      final s = samples[i];
      final int w = s['w'] as int;
      final int h = s['h'] as int;
      final List<int> c1 = s['c1'] as List<int>;
      final List<int> c2 = s['c2'] as List<int>;

      final image = img.Image(width: w, height: h);
      for (int y = 0; y < h; y++) {
        final double t = y / h;
        final int r = (c1[0] * (1 - t) + c2[0] * t).round();
        final int g = (c1[1] * (1 - t) + c2[1] * t).round();
        final int b = (c1[2] * (1 - t) + c2[2] * t).round();
        for (int x = 0; x < w; x++) {
          image.setPixelRgb(x, y, r, g, b);
        }
      }

      final Uint8List jpgBytes = Uint8List.fromList(img.encodeJpg(image, quality: 85));
      final photo = await PhotoAsset.fromBytes(
        id: 'sample_$i',
        name: s['name'] as String,
        bytes: jpgBytes,
      );
      list.add(photo);
    }

    return list;
  }
}
