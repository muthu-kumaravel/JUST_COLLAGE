import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_collage/main.dart';
import 'package:just_collage/models/canvas_aspect_ratio.dart';
import 'package:just_collage/models/collage_settings.dart';
import 'package:just_collage/models/crop_transform.dart';
import 'package:just_collage/models/photo_asset.dart';
import 'package:just_collage/theme/apple_photos_theme.dart';
import 'package:just_collage/ui/apple_photos_crop_viewfinder.dart';
import 'package:just_collage/ui/apple_photos_top_bar.dart';
import 'package:just_collage/ui/widgets/apple_aspect_card.dart';
import 'package:just_collage/ui/widgets/apple_dial_scrubber.dart';

void main() {
  testWidgets('JustCollageApp smoke test: loads empty state and UI elements', (WidgetTester tester) async {
    await tester.pumpWidget(const JustCollageApp());
    await tester.pumpAndSettle();

    // Verify app title and empty state welcome view
    expect(find.text('Just Collage'), findsWidgets);
    expect(find.text('Photo Library'), findsOneWidget);
    expect(find.text('Choose from Files'), findsOneWidget);
    expect(find.text('Try Sample Collage'), findsOneWidget);
    expect(find.textContaining('100% Private & Local'), findsOneWidget);
  });

  testWidgets('AppleDialScrubber test: renders label and updates value on drag', (WidgetTester tester) async {
    double currentValue = 12.0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppleDialScrubber(
            label: 'Gutter Spacing',
            value: currentValue,
            min: 0,
            max: 36,
            unit: 'px',
            onChanged: (val) {
              currentValue = val;
            },
          ),
        ),
      ),
    );

    expect(find.text('Gutter Spacing'), findsOneWidget);
    expect(find.text('12 px'), findsOneWidget);

    // Perform horizontal drag left (Apple Photos style) to increase value
    await tester.drag(find.byType(AppleDialScrubber), const Offset(-40, 0));
    await tester.pumpAndSettle();

    expect(currentValue, greaterThan(12.0));

    // Perform horizontal drag right to decrease value
    await tester.drag(find.byType(AppleDialScrubber), const Offset(60, 0));
    await tester.pumpAndSettle();

    expect(currentValue, lessThan(15.0));
  });

  testWidgets('AppleAspectCard test: renders aspect ratio and triggers tap', (WidgetTester tester) async {
    bool tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppleAspectCard(
            preset: CanvasAspectRatio.square1x1,
            isSelected: true,
            onTap: () {
              tapped = true;
            },
          ),
        ),
      ),
    );

    expect(find.text('Square'), findsOneWidget);
    await tester.tap(find.byType(AppleAspectCard));
    expect(tapped, isTrue);
  });

  test('Instagram aspect ratio identification test: portrait and landscape', () {
    // In portrait mode: 4:5 and 9:16 must be identified as Instagram formats
    expect(CanvasAspectRatio.ratio4x5.withOrientation(CanvasOrientation.portrait).isInstagram, isTrue);
    expect(CanvasAspectRatio.ratio9x16.withOrientation(CanvasOrientation.portrait).isInstagram, isTrue);
    expect(CanvasAspectRatio.ratio1080x566.withOrientation(CanvasOrientation.portrait).isInstagram, isFalse);
    expect(CanvasAspectRatio.square1x1.withOrientation(CanvasOrientation.portrait).isInstagram, isFalse);

    // In landscape mode: 1080x566 (1.91:1) must be identified as Instagram format
    expect(CanvasAspectRatio.ratio1080x566.withOrientation(CanvasOrientation.landscape).isInstagram, isTrue);
    expect(CanvasAspectRatio.ratio4x5.withOrientation(CanvasOrientation.landscape).isInstagram, isFalse);
    expect(CanvasAspectRatio.ratio9x16.withOrientation(CanvasOrientation.landscape).isInstagram, isFalse);
    expect(CanvasAspectRatio.square1x1.withOrientation(CanvasOrientation.landscape).isInstagram, isFalse);
  });

  testWidgets('AppleAspectCard Instagram highlighting test', (WidgetTester tester) async {
    // 4:5 in portrait: should show InstagramIcon and IG Post tag
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppleAspectCard(
            preset: CanvasAspectRatio.ratio4x5.withOrientation(CanvasOrientation.portrait),
            isSelected: false,
            onTap: () {},
          ),
        ),
      ),
    );
    expect(find.byType(InstagramIcon), findsOneWidget);
    expect(find.text('IG Post'), findsOneWidget);

    // 1080x566 in landscape: should show InstagramIcon and IG Post tag
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppleAspectCard(
            preset: CanvasAspectRatio.ratio1080x566.withOrientation(CanvasOrientation.landscape),
            isSelected: false,
            onTap: () {},
          ),
        ),
      ),
    );
    expect(find.byType(InstagramIcon), findsOneWidget);
    expect(find.text('1.91:1'), findsOneWidget);
    expect(find.text('IG Post'), findsOneWidget);

    // 4:5 in landscape: should NOT show InstagramIcon
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppleAspectCard(
            preset: CanvasAspectRatio.ratio4x5.withOrientation(CanvasOrientation.landscape),
            isSelected: false,
            onTap: () {},
          ),
        ),
      ),
    );
    expect(find.byType(InstagramIcon), findsNothing);
  });

  testWidgets('TopBar test: verifies Undo and Redo actions and buttons', (WidgetTester tester) async {
    bool undoCalled = false;
    bool redoCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ApplePhotosTopBar(
            settings: const CollageSettings(),
            photoCount: 4,
            canUndo: true,
            canRedo: true,
            onUndo: () => undoCalled = true,
            onRedo: () => redoCalled = true,
            onStartOver: () {},
            onExport: () {},
            onTogglePhotosTool: () {},
          ),
        ),
      ),
    );

    expect(find.byIcon(CupertinoIcons.arrow_uturn_left), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.arrow_uturn_right), findsOneWidget);

    await tester.tap(find.byIcon(CupertinoIcons.arrow_uturn_left));
    expect(undoCalled, isTrue);

    await tester.tap(find.byIcon(CupertinoIcons.arrow_uturn_right));
    expect(redoCalled, isTrue);
  });

  test('CropTransform model preserves rotation and flip in JSON serialization', () {
    const crop = CropTransform(
      scale: 2.5,
      offset: Offset(0.3, -0.4),
      rotationQuarterTurns: 3,
      flipHorizontal: true,
    );

    final json = crop.toJson();
    expect(json['scale'], equals(2.5));
    expect(json['dx'], equals(0.3));
    expect(json['dy'], equals(-0.4));
    expect(json['rot'], equals(3));
    expect(json['flip'], isTrue);

    final restored = CropTransform.fromJson(json);
    expect(restored.scale, equals(crop.scale));
    expect(restored.offset, equals(crop.offset));
    expect(restored.rotationQuarterTurns, equals(crop.rotationQuarterTurns));
    expect(restored.flipHorizontal, equals(crop.flipHorizontal));
    expect(restored, equals(crop));
  });

  testWidgets('ApplePhotosCropViewfinder test: rotate, flip, cliprect, and done actions', (WidgetTester tester) async {
    final photo = PhotoAsset(
      id: 'p1',
      name: 'test.jpg',
      width: 1200,
      height: 800,
      aspectRatio: 1.5,
      bytes: Uint8List(0),
    );

    CropTransform? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<CropTransform>(
                    MaterialPageRoute(
                      builder: (ctx) => ApplePhotosCropViewfinder(
                        photo: photo,
                        frameAspectRatio: 1.0,
                        initialCrop: CropTransform.identity,
                      ),
                    ),
                  );
                },
                child: const Text('Open Crop'),
              ),
            ),
          ),
        ),
      ),
    );

    // Open viewfinder
    await tester.tap(find.text('Open Crop'));
    await tester.pumpAndSettle();

    // Verify top bar buttons are rendered
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.rotate_right), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.arrow_right_arrow_left), findsOneWidget);

    // Verify ClipRect wrapping ensures no bleed outside viewport
    expect(find.byType(ClipRect), findsWidgets);

    // Tap Rotate 90° button
    await tester.tap(find.byIcon(CupertinoIcons.rotate_right));
    await tester.pumpAndSettle();

    // Reset button should now appear
    expect(find.text('Reset'), findsOneWidget);

    // Tap Flip Horizontal button
    await tester.tap(find.byIcon(CupertinoIcons.arrow_right_arrow_left));
    await tester.pumpAndSettle();

    // Tap Done button
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    // Verify returned CropTransform has rotation and flip
    expect(result, isNotNull);
    expect(result!.rotationQuarterTurns, equals(1));
    expect(result!.flipHorizontal, isTrue);
  });

  test('Square 1:1 orientation switching test', () {
    final square = CanvasAspectRatio.square1x1;
    expect(square.orientation, equals(CanvasOrientation.portrait));

    // Switching to landscape should update the orientation while keeping ratio 1.0
    final landscapeSquare = square.withOrientation(CanvasOrientation.landscape);
    expect(landscapeSquare.orientation, equals(CanvasOrientation.landscape));
    expect(landscapeSquare.ratio, equals(1.0));
    expect(landscapeSquare.displayLabel, equals('1:1 Square'));

    // Switching back to portrait
    final portraitSquare = landscapeSquare.withOrientation(CanvasOrientation.portrait);
    expect(portraitSquare.orientation, equals(CanvasOrientation.portrait));
    expect(portraitSquare.ratio, equals(1.0));

    // Toggle orientation
    final toggled = square.toggleOrientation();
    expect(toggled.orientation, equals(CanvasOrientation.landscape));
  });

  test('presetsFor filters out 1.91:1 in portrait but includes it in landscape', () {
    final portraitPresets = CanvasAspectRatio.presetsFor(CanvasOrientation.portrait);
    final landscapePresets = CanvasAspectRatio.presetsFor(CanvasOrientation.landscape);

    // 1.91:1 must NOT be in portrait presets
    expect(portraitPresets.any((p) => p.id == '1.91:1' || p.id == '1080:566'), isFalse);

    // 1.91:1 MUST be in landscape presets
    expect(landscapePresets.any((p) => p.id == '1.91:1' || p.id == '1080:566'), isTrue);

    // Instagram formats count
    final igPortrait = portraitPresets.where((p) => p.withOrientation(CanvasOrientation.portrait).isInstagram).toList();
    expect(igPortrait.length, equals(2)); // 4:5 and 9:16

    final igLandscape = landscapePresets.where((p) => p.withOrientation(CanvasOrientation.landscape).isInstagram).toList();
    expect(igLandscape.length, equals(1)); // 1.91:1
  });

  test('Modern iOS transparency tokens', () {
    // Frosted glass surface should be translucent (< 50% opacity, ~40%)
    expect(ApplePhotosTheme.frostedGlassSurface.a, lessThan(0.5));
    expect(ApplePhotosTheme.blurSigma, equals(30.0));
  });
}
