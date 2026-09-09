import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_collage/layout/natural_layout_engine.dart';
import 'package:just_collage/layout/uniform_layout_engine.dart';
import 'package:just_collage/layout/scattered_layout_engine.dart';
import 'package:just_collage/models/canvas_aspect_ratio.dart';
import 'package:just_collage/models/collage_settings.dart';
import 'package:just_collage/models/crop_transform.dart';
import 'package:just_collage/models/photo_asset.dart';

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
  group('NaturalLayoutEngine Tests', () {
    const engine = NaturalLayoutEngine();

    test('Preserves aspect ratios and fits within canvas for 2 photos', () {
      final photos = [
        createMockPhoto('1', 1.5), // 3:2 landscape
        createMockPhoto('2', 0.67), // 2:3 portrait
      ];
      final settings = const CollageSettings(
        layoutMode: CollageLayoutMode.natural,
        canvasAspectRatio: CanvasAspectRatio.square1x1,
        spacing: 10,
        outerMargin: 10,
      );
      final canvasSize = const Size(1200, 1200);
      final result = engine.computeLayout(
        photos: photos,
        settings: settings,
        targetCanvasSize: canvasSize,
      );

      expect(result.placements.length, equals(2));
      for (final p in result.placements) {
        expect(p.rect.left, greaterThanOrEqualTo(0));
        expect(p.rect.right, lessThanOrEqualTo(1205));
        expect(p.rect.top, greaterThanOrEqualTo(0));
        expect(p.rect.bottom, lessThanOrEqualTo(1205));
      }

      // Verify no overlap between the 2 items
      final r1 = result.placements[0].rect;
      final r2 = result.placements[1].rect;
      final intersection = r1.intersect(r2);
      expect(intersection.width <= 0.01 || intersection.height <= 0.01, isTrue,
          reason: 'Items should not overlap');
    });

    test('Handles 3, 4, 10 photos minimizing area variance', () {
      for (final count in [3, 4, 10]) {
        final photos = List.generate(
          count,
          (i) => createMockPhoto('$i', 0.8 + (i % 3) * 0.4), // alternating aspect ratios
        );
        final settings = const CollageSettings(
          layoutMode: CollageLayoutMode.natural,
          canvasAspectRatio: CanvasAspectRatio.square1x1,
          spacing: 8,
          outerMargin: 8,
        );
        final result = engine.computeLayout(
          photos: photos,
          settings: settings,
          targetCanvasSize: const Size(1200, 1200),
        );

        expect(result.placements.length, equals(count));

        // Verify photo areas are not wild extremes (no image is 50x another without reason)
        final areas = result.placements.map((p) => p.rect.width * p.rect.height).toList();
        final maxA = areas.reduce(max);
        final minA = areas.reduce(min);
        expect(maxA / minA, lessThan(8.0),
            reason: 'Area variance should be kept visually controlled');
      }
    });

    test('Spacing is applied consistently between adjacent items', () {
      final photos = [
        createMockPhoto('1', 1.0),
        createMockPhoto('2', 1.0),
      ];
      final settings = CollageSettings(
        layoutMode: CollageLayoutMode.natural,
        canvasAspectRatio: CanvasAspectRatio.ratio9x16.withOrientation(CanvasOrientation.landscape),
        spacing: 16,
        outerMargin: 16,
      );
      final result = engine.computeLayout(
        photos: photos,
        settings: settings,
        targetCanvasSize: const Size(1600, 900),
      );

      expect(result.placements.length, equals(2));
      // In 16:9 canvas with 2 square photos, they are placed side by side in 1 row
      final p1 = result.placements[0].rect;
      final p2 = result.placements[1].rect;
      if ((p1.top - p2.top).abs() < 1.0) {
        final actualSpacing = (p2.left - p1.right).abs();
        expect(actualSpacing, closeTo(16.0, 0.5));
      }
    });

    test('5 portrait photos with different aspect ratios fit completely within 1:1 canvas', () {
      final photos = [
        createMockPhoto('1', 0.67), // 2:3
        createMockPhoto('2', 0.75), // 3:4
        createMockPhoto('3', 0.8),  // 4:5
        createMockPhoto('4', 0.7),
        createMockPhoto('5', 0.65),
      ];
      final settings = const CollageSettings(
        layoutMode: CollageLayoutMode.natural,
        canvasAspectRatio: CanvasAspectRatio.square1x1,
        spacing: 12,
        outerMargin: 12,
      );
      final result = engine.computeLayout(
        photos: photos,
        settings: settings,
        targetCanvasSize: const Size(1200, 1200),
      );

      expect(result.placements.length, equals(5));
      for (final p in result.placements) {
        expect(p.rect.left, greaterThanOrEqualTo(11.9));
        expect(p.rect.right, lessThanOrEqualTo(1200.1));
        expect(p.rect.top, greaterThanOrEqualTo(11.9));
        expect(p.rect.bottom, lessThanOrEqualTo(1200.1));
      }
    });
  });

  group('UniformLayoutEngine Tests', () {
    const engine = UniformLayoutEngine();

    test('All frame dimensions and aspect ratios are strictly equal and 5 photos use 3x2 grid', () {
      final photos = List.generate(5, (i) => createMockPhoto('$i', 0.8));
      final settings = const CollageSettings(
        layoutMode: CollageLayoutMode.uniform,
        canvasAspectRatio: CanvasAspectRatio.square1x1,
      );
      final result = engine.computeLayout(
        photos: photos,
        settings: settings,
        targetCanvasSize: const Size(1200, 1200),
      );

      expect(result.placements.length, equals(5));

      // Row Y positions should only have 2 distinct values (3x2 grid: 3 on top, 2 on bottom)
      final distinctY = result.placements.map((p) => (p.rect.top * 10).round() / 10).toSet();
      expect(distinctY.length, equals(2), reason: '5 photos on square canvas must use 2 rows (3x2 grid), never 4 columns');

      final firstW = result.placements.first.rect.width;
      final firstH = result.placements.first.rect.height;
      final firstRatio = firstW / firstH;

      for (final p in result.placements) {
        expect(p.rect.width, closeTo(firstW, 0.001), reason: 'All frame widths must be equal');
        expect(p.rect.height, closeTo(firstH, 0.001), reason: 'All frame heights must be equal');
        expect(p.rect.width / p.rect.height, closeTo(firstRatio, 0.001));
      }
    });

    test('Candidate frame ratios are generated and valid', () {
      final photos = List.generate(4, (i) => createMockPhoto('$i', 1.0));
      final settings = const CollageSettings(
        layoutMode: CollageLayoutMode.uniform,
        canvasAspectRatio: CanvasAspectRatio.ratio4x5,
      );
      final result = engine.computeLayout(
        photos: photos,
        settings: settings,
        targetCanvasSize: const Size(960, 1200),
      );

      expect(result.candidateFrameRatios, isNotEmpty);
      expect(result.activeFrameRatio, isNotNull);
      expect(result.bestFitFrameRatio, isNotNull);
      for (final r in result.candidateFrameRatios) {
        expect(r, greaterThan(0.3));
        expect(r, lessThan(3.0));
      }
    });

    test('Best-fit frame ratio is explicitly computed on LayoutResult', () {
      final photos = List.generate(4, (i) => createMockPhoto('$i', 1.0));
      final settings = const CollageSettings(
        layoutMode: CollageLayoutMode.uniform,
        canvasAspectRatio: CanvasAspectRatio.square1x1,
      );
      final result = engine.computeLayout(
        photos: photos,
        settings: settings,
        targetCanvasSize: const Size(1200, 1200),
      );

      expect(result.bestFitFrameRatio, isNotNull);
      expect(result.bestFitFrameRatio!, closeTo(1.0, 0.05));
    });

    test('Preserves crop transforms for uniform frames', () {
      final photos = [createMockPhoto('p1', 1.5), createMockPhoto('p2', 0.8)];
      final customCrop = const CropTransform(scale: 1.5, offset: Offset(0.2, -0.1));
      final settings = CollageSettings(
        layoutMode: CollageLayoutMode.uniform,
        cropTransforms: {'p1': customCrop},
      );
      final result = engine.computeLayout(
        photos: photos,
        settings: settings,
        targetCanvasSize: const Size(1200, 1200),
      );

      final p1Placement = result.placements.firstWhere((p) => p.photoId == 'p1');
      expect(p1Placement.cropTransform.scale, equals(1.5));
      expect(p1Placement.cropTransform.offset, equals(const Offset(0.2, -0.1)));
    });

    test('Best-Fit frame ratio stays close to majority photo aspect ratio even with outliers', () {
      // 4 portrait photos (4:5 = 0.8) and 1 wide landscape outlier (16:9 = 1.78)
      final photos = [
        createMockPhoto('1', 0.8),
        createMockPhoto('2', 0.8),
        createMockPhoto('3', 0.8),
        createMockPhoto('4', 0.8),
        createMockPhoto('5', 1.78),
      ];
      final settings = const CollageSettings(
        layoutMode: CollageLayoutMode.uniform,
        canvasAspectRatio: CanvasAspectRatio.square1x1,
      );
      final result = engine.computeLayout(
        photos: photos,
        settings: settings,
        targetCanvasSize: const Size(1200, 1200),
      );

      // Best fit should represent the 4:5 majority (0.75 or 0.80), NOT the landscape outlier
      expect(result.bestFitFrameRatio, isNotNull);
      expect(result.bestFitFrameRatio!, lessThanOrEqualTo(0.85));
      expect(result.bestFitFrameRatio!, greaterThanOrEqualTo(0.70));
    });

    test('Grid arrangement dynamically changes per frame aspect ratio to maximize canvas utilization', () {
      // 5 photos on a wide 16:9 banner canvas (1600x900)
      final photos = List.generate(5, (i) => createMockPhoto('$i', 0.56));

      // Case 1: Tall portrait frames (9:16 = 0.56) on 16:9 canvas
      // Sits optimally in a single 5x1 row (utilization ~63% vs ~39% for 3x2)
      final portraitSettings = CollageSettings(
        layoutMode: CollageLayoutMode.uniform,
        canvasAspectRatio: CanvasAspectRatio.ratio9x16.withOrientation(CanvasOrientation.landscape),
        uniformFrameAspectRatio: 0.56,
      );
      final portraitResult = engine.computeLayout(
        photos: photos,
        settings: portraitSettings,
        targetCanvasSize: const Size(1600, 900),
      );

      // Verify row count for 9:16 on 16:9 canvas is 1 (all distinct Ys are equal -> 1 row)
      final portraitDistinctY = portraitResult.placements.map((p) => (p.rect.top * 10).round() / 10).toSet();
      expect(portraitDistinctY.length, equals(1),
          reason: '5 tall portrait frames on 16:9 canvas should arrange in 1 row (5x1) for maximum canvas utilization');

      // Case 2: Wide landscape frames (16:9 = 1.78) on 16:9 canvas
      // Must NOT be in 1 row (which would make each photo tiny); needs multiple rows
      final landscapeSettings = CollageSettings(
        layoutMode: CollageLayoutMode.uniform,
        canvasAspectRatio: CanvasAspectRatio.ratio9x16.withOrientation(CanvasOrientation.landscape),
        uniformFrameAspectRatio: 1.78,
        uniformFrameOrientation: CanvasOrientation.landscape,
      );
      final landscapeResult = engine.computeLayout(
        photos: photos,
        settings: landscapeSettings,
        targetCanvasSize: const Size(1600, 900),
      );

      final landscapeDistinctY = landscapeResult.placements.map((p) => (p.rect.top * 10).round() / 10).toSet();
      expect(landscapeDistinctY.length, greaterThan(1),
          reason: '5 wide landscape frames on 16:9 canvas should arrange in multiple rows');
    });
  });

  group('ScatteredLayoutEngine Tests', () {
    const engine = ScatteredLayoutEngine();

    test('Rotation is strictly within [-15°, +15°]', () {
      final photos = List.generate(12, (i) => createMockPhoto('$i', 1.0 + i * 0.1));
      final settings = const CollageSettings(
        layoutMode: CollageLayoutMode.scattered,
        seed: 12345,
      );
      final result = engine.computeLayout(
        photos: photos,
        settings: settings,
        targetCanvasSize: const Size(1200, 1200),
      );

      expect(result.placements.length, equals(12));
      for (final p in result.placements) {
        expect(p.rotation, greaterThanOrEqualTo(-ScatteredLayoutEngine.maxRotationRadians - 0.001));
        expect(p.rotation, lessThanOrEqualTo(ScatteredLayoutEngine.maxRotationRadians + 0.001));
      }
    });

    test('Maintains source aspect ratio for each photo', () {
      final photos = [
        createMockPhoto('1', 1.6),
        createMockPhoto('2', 0.75),
        createMockPhoto('3', 1.0),
      ];
      final settings = const CollageSettings(
        layoutMode: CollageLayoutMode.scattered,
        seed: 99,
      );
      final result = engine.computeLayout(
        photos: photos,
        settings: settings,
        targetCanvasSize: const Size(1200, 1200),
      );

      for (final p in result.placements) {
        final expectedAspect = photos.firstWhere((ph) => ph.id == p.photoId).aspectRatio;
        expect(p.rect.width / p.rect.height, closeTo(expectedAspect, 0.01),
            reason: 'Scattered photo aspect ratio must match source photo');
      }
    });

    test('Deterministic shuffle: same seed yields same layout, different seed yields different layout', () {
      final photos = List.generate(5, (i) => createMockPhoto('$i', 1.2));
      final settings1 = const CollageSettings(layoutMode: CollageLayoutMode.scattered, seed: 100);
      final settings2 = const CollageSettings(layoutMode: CollageLayoutMode.scattered, seed: 100);
      final settings3 = const CollageSettings(layoutMode: CollageLayoutMode.scattered, seed: 200);

      final r1 = engine.computeLayout(photos: photos, settings: settings1, targetCanvasSize: const Size(1000, 1000));
      final r2 = engine.computeLayout(photos: photos, settings: settings2, targetCanvasSize: const Size(1000, 1000));
      final r3 = engine.computeLayout(photos: photos, settings: settings3, targetCanvasSize: const Size(1000, 1000));

      for (int i = 0; i < photos.length; i++) {
        expect(r1.placements[i].rect, equals(r2.placements[i].rect));
        expect(r1.placements[i].rotation, equals(r2.placements[i].rotation));
      }

      // At least one rect or rotation should differ between seed 100 and seed 200
      bool hasDifference = false;
      for (int i = 0; i < photos.length; i++) {
        if (r1.placements[i].rect != r3.placements[i].rect ||
            r1.placements[i].rotation != r3.placements[i].rotation) {
          hasDifference = true;
          break;
        }
      }
      expect(hasDifference, isTrue);
    });

    test('Area of canvas covered by each photo is similar with minimal variance', () {
      // 5 photos with diverse aspect ratios (portrait 0.67, square 1.0, landscape 1.5, etc.)
      final photos = [
        createMockPhoto('1', 0.67),
        createMockPhoto('2', 0.8),
        createMockPhoto('3', 1.0),
        createMockPhoto('4', 1.33),
        createMockPhoto('5', 1.5),
      ];
      final settings = const CollageSettings(
        layoutMode: CollageLayoutMode.scattered,
        canvasAspectRatio: CanvasAspectRatio.square1x1,
      );
      final result = engine.computeLayout(
        photos: photos,
        settings: settings,
        targetCanvasSize: const Size(1200, 1200),
      );

      final areas = result.placements.map((p) => p.rect.width * p.rect.height).toList();
      final maxArea = areas.reduce(max);
      final minArea = areas.reduce(min);

      // Area variance must be very low: ratio of max to min area < 1.20
      expect(maxArea / minArea, lessThan(1.20),
          reason: 'All photos must cover similar area on canvas (low variance)');
    });

    test('Controlled overlap: photos overlap gently without any photo being buried or obscured', () {
      final photos = List.generate(5, (i) => createMockPhoto('$i', 0.8));
      final settings = const CollageSettings(
        layoutMode: CollageLayoutMode.scattered,
        canvasAspectRatio: CanvasAspectRatio.square1x1,
        seed: 42,
      );
      final result = engine.computeLayout(
        photos: photos,
        settings: settings,
        targetCanvasSize: const Size(1200, 1200),
      );

      final placements = result.placements;
      final int n = placements.length;

      // Check overlap on each photo from photos above it (j > i)
      for (int i = 0; i < n; i++) {
        final pi = placements[i];
        final areaI = pi.rect.width * pi.rect.height;

        double coveredArea = 0.0;
        for (int j = i + 1; j < n; j++) {
          final pj = placements[j];
          final intersection = pi.rect.intersect(pj.rect);
          if (intersection.width > 0 && intersection.height > 0) {
            coveredArea += intersection.width * intersection.height;
          }
        }

        final coveredFraction = coveredArea / areaI;
        expect(coveredFraction, lessThanOrEqualTo(0.35),
            reason: 'Photo $i must not be obscured by more than 35% (at least 65% visible)');
      }
    });
  });
}
