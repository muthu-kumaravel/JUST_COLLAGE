import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:just_collage/services/heic_service.dart';
import 'package:just_collage/layout/natural_layout_engine.dart';
import 'package:just_collage/layout/scattered_layout_engine.dart';
import 'package:just_collage/layout/uniform_layout_engine.dart';
import 'package:just_collage/models/canvas_aspect_ratio.dart';
import 'package:just_collage/models/collage_settings.dart';
import 'package:just_collage/models/photo_asset.dart';
import 'package:just_collage/rendering/collage_painter.dart';

PhotoAsset createMockPhoto(String id, double aspectRatio) {
  final width = (aspectRatio >= 1.0) ? 1200 : (1200 * aspectRatio).round();
  final height = (aspectRatio >= 1.0) ? (1200 / aspectRatio).round() : 1200;
  return PhotoAsset(
    id: id,
    name: 'photo_$id.jpg',
    width: width,
    height: height,
    aspectRatio: aspectRatio,
    bytes: Uint8List(0),
  );
}

void main() {
  group('Edge Cases & Stress Tests', () {
    const naturalEngine = NaturalLayoutEngine();
    const uniformEngine = UniformLayoutEngine();
    const scatteredEngine = ScatteredLayoutEngine();

    test('All standard aspect ratio presets support portrait and landscape flipping', () {
      for (final preset in CanvasAspectRatio.presets) {
        final portrait = preset.withOrientation(CanvasOrientation.portrait);
        final landscape = preset.withOrientation(CanvasOrientation.landscape);

        if (preset.id == '1:1') {
          expect(portrait.ratio, equals(1.0));
          expect(landscape.ratio, equals(1.0));
        } else {
          expect(portrait.ratio, lessThan(1.0));
          expect(landscape.ratio, greaterThan(1.0));
          expect(portrait.ratio * landscape.ratio, closeTo(1.0, 0.001));
        }
      }
    });

    test('Natural mode: 5 portrait photos fill edge-to-edge without overflow in 1:1, 4:5, 16:9', () {
      final photos = [
        createMockPhoto('1', 0.67), // 2:3 portrait
        createMockPhoto('2', 0.75), // 3:4 portrait
        createMockPhoto('3', 0.8),  // 4:5 portrait
        createMockPhoto('4', 0.7),
        createMockPhoto('5', 0.65),
      ];

      final testRatios = [
        CanvasAspectRatio.square1x1,
        CanvasAspectRatio.ratio4x5,
        CanvasAspectRatio.ratio9x16.withOrientation(CanvasOrientation.landscape),
      ];

      for (final ratio in testRatios) {
        final settings = CollageSettings(
          layoutMode: CollageLayoutMode.natural,
          canvasAspectRatio: ratio,
          spacing: 12,
          outerMargin: 12,
        );

        final canvasW = ratio.ratio >= 1.0 ? 1200.0 : 1200.0 * ratio.ratio;
        final canvasH = ratio.ratio >= 1.0 ? 1200.0 / ratio.ratio : 1200.0;

        final result = naturalEngine.computeLayout(
          photos: photos,
          settings: settings,
          targetCanvasSize: ui.Size(canvasW, canvasH),
        );

        expect(result.placements.length, equals(5));

        for (final p in result.placements) {
          expect(p.rect.left, greaterThanOrEqualTo(11.9));
          expect(p.rect.right, lessThanOrEqualTo(canvasW + 0.1));
          expect(p.rect.top, greaterThanOrEqualTo(11.9));
          expect(p.rect.bottom, lessThanOrEqualTo(canvasH + 0.1));
        }
      }
    });

    test('Uniform mode: Best-Fit matches majority photo ratio and balances canvas utilization', () {
      final photos = List.generate(5, (i) => createMockPhoto('$i', 0.7));
      final settings = const CollageSettings(
        layoutMode: CollageLayoutMode.uniform,
        canvasAspectRatio: CanvasAspectRatio.square1x1,
        spacing: 10,
        outerMargin: 10,
      );

      final result = uniformEngine.computeLayout(
        photos: photos,
        settings: settings,
        targetCanvasSize: const ui.Size(1200, 1200),
      );

      expect(result.placements.length, equals(5));

      // Best-fit frame ratio must stay close to the majority photo ratio (0.7)
      expect(result.bestFitFrameRatio, isNotNull);
      expect(result.bestFitFrameRatio!, closeTo(0.7, 0.05),
          reason: 'Best-fit must stay close to the majority photo aspect ratio');

      final minLeft = result.placements.map((p) => p.rect.left).reduce((a, b) => a < b ? a : b);
      final maxRight = result.placements.map((p) => p.rect.right).reduce((a, b) => a > b ? a : b);
      final minTop = result.placements.map((p) => p.rect.top).reduce((a, b) => a < b ? a : b);
      final maxBottom = result.placements.map((p) => p.rect.bottom).reduce((a, b) => a > b ? a : b);

      // Width touches margins and height is centered within margins
      expect(minLeft, closeTo(10.0, 0.5), reason: 'Left edge must touch margin');
      expect(maxRight, closeTo(1190.0, 0.5), reason: 'Right edge must touch margin');
      expect(minTop, greaterThanOrEqualTo(10.0), reason: 'Top must be within margin');
      expect(maxBottom, lessThanOrEqualTo(1190.0), reason: 'Bottom must be within margin');
    });

    test('Scattered mode: Zero bleed - every photo stays strictly inside canvas', () {
      final photos = List.generate(8, (i) => createMockPhoto('$i', 0.6 + i * 0.2));
      final settings = const CollageSettings(
        layoutMode: CollageLayoutMode.scattered,
        canvasAspectRatio: CanvasAspectRatio.square1x1,
        borderWidth: 6.0,
      );

      final result = scatteredEngine.computeLayout(
        photos: photos,
        settings: settings,
        targetCanvasSize: const ui.Size(1200, 1200),
      );

      expect(result.placements.length, equals(8));
      for (final p in result.placements) {
        expect(p.rect.left, greaterThanOrEqualTo(0.0));
        expect(p.rect.right, lessThanOrEqualTo(1200.0));
        expect(p.rect.top, greaterThanOrEqualTo(0.0));
        expect(p.rect.bottom, lessThanOrEqualTo(1200.0));
      }
    });

    test('Handles extreme portrait and extreme landscape photos gracefully', () {
      final photos = [
        createMockPhoto('p_extreme_tall', 0.25), // 1:4 tall banner
        createMockPhoto('p_extreme_wide', 4.0),  // 4:1 panoramic
        createMockPhoto('p_normal', 1.0),
      ];

      for (final mode in CollageLayoutMode.values) {
        final settings = CollageSettings(layoutMode: mode);
        final canvasSize = const ui.Size(1200, 1200);

        final result = switch (mode) {
          CollageLayoutMode.natural => naturalEngine.computeLayout(
              photos: photos, settings: settings, targetCanvasSize: canvasSize),
          CollageLayoutMode.uniform => uniformEngine.computeLayout(
              photos: photos, settings: settings, targetCanvasSize: canvasSize),
          CollageLayoutMode.scattered => scatteredEngine.computeLayout(
              photos: photos, settings: settings, targetCanvasSize: canvasSize),
        };

        expect(result.placements.length, equals(3));
        for (final p in result.placements) {
          expect(p.rect.width, greaterThan(0));
          expect(p.rect.height, greaterThan(0));
          expect(p.rect.left.isFinite, isTrue);
          expect(p.rect.top.isFinite, isTrue);
        }
      }
    });

    test('High photo count (40 photos) executes quickly without degradation', () {
      final photos = List.generate(
        40,
        (i) => createMockPhoto('photo_$i', 0.5 + (i % 5) * 0.4),
      );

      final stopwatch = Stopwatch()..start();

      final naturalResult = naturalEngine.computeLayout(
        photos: photos,
        settings: const CollageSettings(layoutMode: CollageLayoutMode.natural),
        targetCanvasSize: const ui.Size(1200, 1200),
      );

      final uniformResult = uniformEngine.computeLayout(
        photos: photos,
        settings: const CollageSettings(layoutMode: CollageLayoutMode.uniform),
        targetCanvasSize: const ui.Size(1200, 1200),
      );

      final scatteredResult = scatteredEngine.computeLayout(
        photos: photos,
        settings: const CollageSettings(layoutMode: CollageLayoutMode.scattered),
        targetCanvasSize: const ui.Size(1200, 1200),
      );

      stopwatch.stop();

      expect(naturalResult.placements.length, equals(40));
      expect(uniformResult.placements.length, equals(40));
      expect(scatteredResult.placements.length, equals(40));
      expect(stopwatch.elapsedMilliseconds, lessThan(500),
          reason: 'Layout calculation for 40 photos should complete in <500ms');
    });

    test('Repeated shuffle produces valid compositions with seeds', () {
      final photos = List.generate(6, (i) => createMockPhoto('$i', 1.3));
      CollageSettings settings = const CollageSettings(layoutMode: CollageLayoutMode.scattered, seed: 1);

      final Set<int> distinctSeeds = {settings.seed};

      for (int step = 0; step < 10; step++) {
        settings = settings.nextShuffleSeed();
        distinctSeeds.add(settings.seed);

        final result = scatteredEngine.computeLayout(
          photos: photos,
          settings: settings,
          targetCanvasSize: const ui.Size(1200, 1200),
        );

        expect(result.placements.length, equals(6));
        for (final p in result.placements) {
          expect(p.rotation.abs(), lessThanOrEqualTo(ScatteredLayoutEngine.maxRotationRadians + 0.001));
        }
      }

      expect(distinctSeeds.length, equals(11), reason: 'Each shuffle should produce a new seed');
    });

    test('CollagePainter correctly instantiates with border settings', () {
      final photos = [createMockPhoto('1', 1.0), createMockPhoto('2', 1.5)];
      final photosById = {for (var p in photos) p.id: p};
      final settings = const CollageSettings(
        layoutMode: CollageLayoutMode.natural,
        canvasAspectRatio: CanvasAspectRatio.square1x1,
        borderWidth: 8.0,
      );

      final layoutResult = naturalEngine.computeLayout(
        photos: photos,
        settings: settings,
        targetCanvasSize: const ui.Size(1200, 1200),
      );

      final painter = CollagePainter(
        layoutResult: layoutResult,
        settings: settings,
        photosById: photosById,
      );

      expect(painter.layoutResult, equals(layoutResult));
      expect(painter.settings, equals(settings));
    });

    test('Natural mode minimizes area variance: 5 photos have balanced area without extreme disparity', () {
      final photos = [
        createMockPhoto('1', 0.67), // 2:3 portrait
        createMockPhoto('2', 0.75), // 3:4 portrait
        createMockPhoto('3', 0.8),  // 4:5 portrait
        createMockPhoto('4', 0.7),
        createMockPhoto('5', 0.65),
      ];

      final settings = const CollageSettings(
        layoutMode: CollageLayoutMode.natural,
        canvasAspectRatio: CanvasAspectRatio.square1x1,
        spacing: 10,
        outerMargin: 10,
      );

      final result = naturalEngine.computeLayout(
        photos: photos,
        settings: settings,
        targetCanvasSize: const ui.Size(1200, 1200),
      );

      expect(result.placements.length, equals(5));

      final areas = result.placements.map((p) => p.rect.width * p.rect.height).toList();
      final minArea = areas.reduce((a, b) => a < b ? a : b);
      final maxArea = areas.reduce((a, b) => a > b ? a : b);
      final disparity = maxArea / minArea;

      // Ensure no photo is 3x or 16x larger than any other (area variance minimization)
      expect(disparity, lessThanOrEqualTo(2.2),
          reason: 'Area disparity between photos must remain <= 2.2 so all photos get equal importance');

      // Ensure no single photo dominates by spanning the entire width (no wide banner row)
      const availW = 1200.0 - 20.0;
      for (final p in result.placements) {
        expect(p.rect.width, lessThan(availW * 0.85),
            reason: 'No single photo should occupy the entire canvas width as a banner');
      }
    });

    test('Scattered mode evenly distributes photos on distinct grid centers with zero bleed', () {
      final photos = [
        createMockPhoto('1', 0.67),
        createMockPhoto('2', 0.75),
        createMockPhoto('3', 0.8),
        createMockPhoto('4', 0.7),
        createMockPhoto('5', 0.65),
      ];

      final settings = const CollageSettings(
        layoutMode: CollageLayoutMode.scattered,
        canvasAspectRatio: CanvasAspectRatio.square1x1,
        outerMargin: 16,
      );

      final result = scatteredEngine.computeLayout(
        photos: photos,
        settings: settings,
        targetCanvasSize: const ui.Size(1200, 1200),
      );

      expect(result.placements.length, equals(5));

      // 1. Verify all centers are distinctly distributed (no photos stacked on top of each other)
      final centers = result.placements.map((p) => p.rect.center).toList();
      for (int i = 0; i < centers.length; i++) {
        for (int j = i + 1; j < centers.length; j++) {
          final dist = (centers[i] - centers[j]).distance;
          expect(dist, greaterThan(150.0),
              reason: 'Photo centers must be distinctly spaced across the grid (dist=$dist)');
        }
      }

      // 2. Verify all photos stay strictly within canvas bounds
      for (final p in result.placements) {
        expect(p.rect.left, greaterThanOrEqualTo(0.0));
        expect(p.rect.right, lessThanOrEqualTo(1200.0));
        expect(p.rect.top, greaterThanOrEqualTo(0.0));
        expect(p.rect.bottom, lessThanOrEqualTo(1200.0));
      }
    });

    test('PhotoAsset downsampling preserves exact aspect ratio without stretching or shrinking', () async {
      // 1. Portrait image: 400 wide x 800 high (ratio = 0.5)
      final portraitImg = img.Image(width: 400, height: 800);
      final portraitBytes = Uint8List.fromList(img.encodeJpg(portraitImg));
      final portraitAsset = await PhotoAsset.fromBytes(
        id: 'test_portrait',
        name: 'portrait.jpg',
        bytes: portraitBytes,
        previewMaxSize: 200,
      );

      expect(portraitAsset.width, equals(400));
      expect(portraitAsset.height, equals(800));
      expect(portraitAsset.aspectRatio, closeTo(0.5, 0.001));
      expect(portraitAsset.previewImage, isNotNull);
      expect(portraitAsset.previewImage!.width, equals(100));
      expect(portraitAsset.previewImage!.height, equals(200));
      expect(
        portraitAsset.previewImage!.width / portraitAsset.previewImage!.height,
        closeTo(portraitAsset.aspectRatio, 0.001),
        reason: 'Portrait preview must preserve exact 0.5 aspect ratio without vertical shrinking or horizontal stretching',
      );

      // 2. Landscape image: 800 wide x 400 high (ratio = 2.0)
      final landscapeImg = img.Image(width: 800, height: 400);
      final landscapeBytes = Uint8List.fromList(img.encodeJpg(landscapeImg));
      final landscapeAsset = await PhotoAsset.fromBytes(
        id: 'test_landscape',
        name: 'landscape.jpg',
        bytes: landscapeBytes,
        previewMaxSize: 200,
      );

      expect(landscapeAsset.width, equals(800));
      expect(landscapeAsset.height, equals(400));
      expect(landscapeAsset.aspectRatio, closeTo(2.0, 0.001));
      expect(landscapeAsset.previewImage, isNotNull);
      expect(landscapeAsset.previewImage!.width, equals(200));
      expect(landscapeAsset.previewImage!.height, equals(100));
      expect(
        landscapeAsset.previewImage!.width / landscapeAsset.previewImage!.height,
        closeTo(landscapeAsset.aspectRatio, 0.001),
        reason: 'Landscape preview must preserve exact 2.0 aspect ratio without horizontal stretching',
      );

      portraitAsset.dispose();
      landscapeAsset.dispose();
    });

    test('HeicService correctly identifies HEIC file extensions and byte signatures', () {
      expect(HeicService.isHeic(Uint8List(0), path: 'photo.heic'), isTrue);
      expect(HeicService.isHeic(Uint8List(0), path: 'PHOTO.HEIC'), isTrue);
      expect(HeicService.isHeic(Uint8List(0), path: 'image.heif'), isTrue);
      expect(HeicService.isHeic(Uint8List(0), path: 'IMG.HEIF'), isTrue);
      expect(HeicService.isHeic(Uint8List(0), path: 'normal.jpg'), isFalse);
      expect(HeicService.isHeic(Uint8List(0), path: 'photo.png'), isFalse);

      // HEIC brand signature: [0, 0, 0, 24, 'f', 't', 'y', 'p', 'h', 'e', 'i', 'c']
      final heicMagic = Uint8List.fromList([
        0, 0, 0, 24,
        0x66, 0x74, 0x79, 0x70, // 'ftyp'
        0x68, 0x65, 0x69, 0x63, // 'heic'
      ]);
      expect(HeicService.isHeic(heicMagic), isTrue);

      final jpegMagic = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0, 0x10, 0x4A, 0x46, 0x49, 0x46]);
      expect(HeicService.isHeic(jpegMagic), isFalse);
    });

    test('Real iPhone HEIC file decode diagnostic', () async {
      final samplePaths = [
        '/Users/muthu/Pictures/Post Pics/IMG_2580.HEIC',
        '/Users/muthu/Pictures/Post Pics/IMG_5729.heic',
        '/Users/muthu/Pictures/Post Pics/IMG_6112.HEIC',
        '/Users/muthu/Pictures/Post Pics/IMG_6573.HEIC',
        '/Users/muthu/Pictures/Post Pics/IMG_8825.HEIC',
        '/Users/muthu/Pictures/Post Pics/IMG_8842.HEIC',
      ];

      for (final path in samplePaths) {
        final file = File(path);
        if (!file.existsSync()) continue;
        final xFile = XFile(file.path);
        final asset = await PhotoAsset.fromXFile(xFile);
        expect(asset.width, greaterThan(0));
        expect(asset.height, greaterThan(0));
        expect(asset.previewImage, isNotNull);
        asset.dispose();
      }
    });
  });
}
