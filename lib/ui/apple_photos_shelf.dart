import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../models/canvas_aspect_ratio.dart';
import '../models/collage_settings.dart';
import '../models/layout_result.dart';
import '../models/photo_asset.dart';
import '../theme/apple_photos_theme.dart';
import 'apple_photos_dock.dart';
import 'widgets/apple_aspect_card.dart';
import 'widgets/apple_dial_scrubber.dart';

/// Dynamic interactive inspector shelf displayed above the bottom tool dock.
class ApplePhotosShelf extends StatelessWidget {
  final ApplePhotosTool activeTool;
  final CollageSettings settings;
  final LayoutResult? layoutResult;
  final List<PhotoAsset> photos;

  // Callbacks
  final ValueChanged<CollageLayoutMode> onLayoutModeChanged;
  final ValueChanged<CanvasAspectRatio> onCanvasRatioChanged;
  final ValueChanged<CanvasOrientation> onCanvasOrientationChanged;
  final ValueChanged<double?> onUniformRatioChanged;
  final ValueChanged<CanvasOrientation> onUniformOrientationChanged;
  final ValueChanged<double> onSpacingChanged;
  final ValueChanged<double> onMarginChanged;
  final ValueChanged<double> onBorderWidthChanged;
  final ValueChanged<Color> onBorderColorChanged;
  final VoidCallback onPickBorderImage;
  final VoidCallback onRemoveBorderImage;
  final ValueChanged<Color> onBackgroundColorChanged;
  final VoidCallback onPickBackgroundImage;
  final VoidCallback onRemoveBackgroundImage;
  final ValueChanged<double> onBackgroundBlurChanged;
  final VoidCallback onAddPhotos;
  final ValueChanged<String> onRemovePhoto;

  static const List<Color> _borderColorPresets = [
    Colors.white,
    Colors.black,
    Color(0xFFFFD60A), // Gold
    Color(0xFFFAF6F0), // Cream
    Color(0xFF64748B), // Slate
    Color(0xFFF43F5E), // Rose
  ];

  static const List<Color> _bgColorPresets = [
    Colors.white,
    Color(0xFFF8F9FA), // Off-white
    Color(0xFFFAF6F0), // Cream
    Color(0xFFE5E7EB), // Gray
    Color(0xFF1E293B), // Slate
    Colors.black,
  ];

  const ApplePhotosShelf({
    super.key,
    required this.activeTool,
    required this.settings,
    required this.layoutResult,
    required this.photos,
    required this.onLayoutModeChanged,
    required this.onCanvasRatioChanged,
    required this.onCanvasOrientationChanged,
    required this.onUniformRatioChanged,
    required this.onUniformOrientationChanged,
    required this.onSpacingChanged,
    required this.onMarginChanged,
    required this.onBorderWidthChanged,
    required this.onBorderColorChanged,
    required this.onPickBorderImage,
    required this.onRemoveBorderImage,
    required this.onBackgroundColorChanged,
    required this.onPickBackgroundImage,
    required this.onRemoveBackgroundImage,
    required this.onBackgroundBlurChanged,
    required this.onAddPhotos,
    required this.onRemovePhoto,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: ApplePhotosTheme.blurSigma,
          sigmaY: ApplePhotosTheme.blurSigma,
        ),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 155),
          decoration: const BoxDecoration(
            color: ApplePhotosTheme.frostedGlassSurface,
            border: Border(
              top: BorderSide(color: ApplePhotosTheme.specularBorder, width: 0.5),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: _buildToolContent(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolContent() {
    switch (activeTool) {
      case ApplePhotosTool.layout:
        return _buildLayoutShelf();
      case ApplePhotosTool.canvas:
        return _buildCanvasShelf();
      case ApplePhotosTool.spacing:
        return _buildSpacingShelf();
      case ApplePhotosTool.borders:
        return _buildBordersShelf();
      case ApplePhotosTool.background:
        return _buildBackgroundShelf();
      case ApplePhotosTool.photos:
        return _buildPhotosShelf();
    }
  }

  // 1. Layout Shelf
  Widget _buildLayoutShelf() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Mode Selector (Natural, Uniform, Scattered)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: CupertinoSlidingSegmentedControl<CollageLayoutMode>(
            backgroundColor: Colors.white.withValues(alpha: 0.12),
            thumbColor: ApplePhotosTheme.appleGold,
            groupValue: settings.layoutMode,
            children: {
              for (final mode in CollageLayoutMode.values)
                mode: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
                  child: Text(
                    mode.label,
                    style: TextStyle(
                      color: settings.layoutMode == mode ? Colors.black : Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
            },
            onValueChanged: (mode) {
              if (mode != null) onLayoutModeChanged(mode);
            },
          ),
        ),

        // Uniform Mode Frame Controls (if uniform mode is active)
        if (settings.layoutMode == CollageLayoutMode.uniform && layoutResult != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                // Frame Orientation Toggle
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  onPressed: () {
                    onUniformOrientationChanged(settings.uniformFrameOrientation.toggle());
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        settings.uniformFrameOrientation.isPortrait
                            ? CupertinoIcons.rectangle
                            : CupertinoIcons.rectangle_fill,
                        size: 13,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        settings.uniformFrameOrientation.isPortrait ? 'Portrait' : 'Landscape',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 32,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        // "Best Fit" chip
                        Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: ChoiceChip(
                            avatar: Icon(
                              CupertinoIcons.sparkles,
                              size: 12,
                              color: settings.uniformFrameAspectRatio == null
                                  ? Colors.black
                                  : ApplePhotosTheme.appleGold,
                            ),
                            label: const Text('Best Fit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            selected: settings.uniformFrameAspectRatio == null,
                            selectedColor: ApplePhotosTheme.appleGold,
                            labelStyle: TextStyle(
                              color: settings.uniformFrameAspectRatio == null ? Colors.black : Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            visualDensity: VisualDensity.compact,
                            onSelected: (_) => onUniformRatioChanged(null),
                          ),
                        ),
                        // Standard aspect ratios only (1:1, 4:5, 3:4, 2:3, 9:16)
                        ..._getStandardUniformPresets(settings.uniformFrameOrientation).map((p) {
                          final isSelected = settings.uniformFrameAspectRatio != null &&
                              (settings.uniformFrameAspectRatio! - p.ratio).abs() < 0.04;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6.0),
                            child: ChoiceChip(
                              label: Text(p.label, style: const TextStyle(fontSize: 11)),
                              selected: isSelected,
                              selectedColor: ApplePhotosTheme.appleGold,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.black : Colors.white70,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                              visualDensity: VisualDensity.compact,
                              onSelected: (_) => onUniformRatioChanged(p.ratio),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // 2. Canvas Shelf (Aspect Ratios + Orientation)
  Widget _buildCanvasShelf() {
    final curOrientation = settings.canvasAspectRatio.orientation;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Orientation toggle
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CupertinoSlidingSegmentedControl<CanvasOrientation>(
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                thumbColor: ApplePhotosTheme.appleGold,
                groupValue: curOrientation,
                children: {
                  CanvasOrientation.portrait: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.device_phone_portrait,
                          size: 13,
                          color: curOrientation.isPortrait ? Colors.black : Colors.white70,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Portrait',
                          style: TextStyle(
                            color: curOrientation.isPortrait ? Colors.black : Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  CanvasOrientation.landscape: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.device_phone_landscape,
                          size: 13,
                          color: curOrientation.isLandscape ? Colors.black : Colors.white70,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Landscape',
                          style: TextStyle(
                            color: curOrientation.isLandscape ? Colors.black : Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                },
                onValueChanged: (ori) {
                  if (ori != null) onCanvasOrientationChanged(ori);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // Horizontal Aspect Cards
        SizedBox(
          height: 72,
          child: Builder(
            builder: (context) {
              final presets = CanvasAspectRatio.presetsFor(curOrientation);
              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                scrollDirection: Axis.horizontal,
                itemCount: presets.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final preset = presets[index].withOrientation(curOrientation);
                  final isSelected = preset.id == settings.canvasAspectRatio.id;

                  return AppleAspectCard(
                    preset: preset,
                    isSelected: isSelected,
                    onTap: () => onCanvasRatioChanged(preset),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // 3. Spacing Shelf
  Widget _buildSpacingShelf() {
    return Center(
      child: AppleDialScrubber(
        label: 'Gutter Spacing',
        value: settings.spacing,
        min: 0,
        max: 36,
        unit: 'px',
        onChanged: (val) {
          onSpacingChanged(val);
          onMarginChanged(val);
        },
      ),
    );
  }

  // 4. Borders Shelf (Dial + Color Swatches + Texture Upload)
  Widget _buildBordersShelf() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppleDialScrubber(
          label: 'Border Width',
          value: settings.borderWidth,
          min: 0,
          max: 24,
          unit: 'px',
          onChanged: onBorderWidthChanged,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ..._borderColorPresets.map((c) {
                final isSelected = settings.borderImage == null &&
                    c.toARGB32() == settings.borderColor.toARGB32();
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5.0),
                  child: GestureDetector(
                    onTap: () {
                      if (settings.borderImage != null) {
                        onRemoveBorderImage();
                      }
                      onBorderColorChanged(c);
                    },
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? ApplePhotosTheme.appleGold : Colors.white30,
                          width: isSelected ? 2.5 : 1.0,
                        ),
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(width: 8),
              // Texture Upload Tile
              if (settings.borderImage != null)
                GestureDetector(
                  onTap: onRemoveBorderImage,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: ApplePhotosTheme.appleGold, width: 2),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.memory(settings.borderImage!.bytes, fit: BoxFit.cover),
                  ),
                )
              else
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  onPressed: onPickBorderImage,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.photo, size: 12, color: Colors.white),
                      SizedBox(width: 4),
                      Text('Texture', style: TextStyle(color: Colors.white, fontSize: 11)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // 5. Background Shelf (Color Swatches + Custom Photo & Blur)
  Widget _buildBackgroundShelf() {
    if (settings.backgroundImage != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.memory(
                    settings.backgroundImage!.bytes,
                    width: 28,
                    height: 28,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppleDialScrubber(
                    label: 'Background Blur',
                    value: settings.backgroundBlur,
                    min: 0,
                    max: 25,
                    unit: 'blur',
                    onChanged: onBackgroundBlurChanged,
                  ),
                ),
                IconButton(
                  onPressed: onRemoveBackgroundImage,
                  tooltip: 'Remove Background Photo',
                  icon: const Icon(CupertinoIcons.trash, color: ApplePhotosTheme.appleRed, size: 18),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Solid Color Swatches
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _bgColorPresets.map((c) {
              final isSelected = settings.backgroundImage == null &&
                  c.toARGB32() == settings.backgroundColor.toARGB32();
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6.0),
                child: GestureDetector(
                  onTap: () {
                    if (settings.backgroundImage != null) {
                      onRemoveBackgroundImage();
                    }
                    onBackgroundColorChanged(c);
                  },
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? ApplePhotosTheme.appleGold : Colors.white30,
                        width: isSelected ? 2.5 : 1.0,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 6),
        // Add Photo Background Button
        CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          onPressed: onPickBackgroundImage,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.photo, size: 14, color: Colors.white),
              SizedBox(width: 6),
              Text('Use Photo Background', style: TextStyle(color: Colors.white, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  // 6. Photos Tray (Instagram / Apple Camera Roll Style)
  Widget _buildPhotosShelf() {
    return SizedBox(
      height: 64,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        scrollDirection: Axis.horizontal,
        itemCount: photos.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == photos.length) {
            // Add Photos tile
            return GestureDetector(
              onTap: onAddPhotos,
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ApplePhotosTheme.specularBorder, width: 0.8),
                ),
                child: const Icon(CupertinoIcons.plus, color: Colors.white, size: 22),
              ),
            );
          }

          final photo = photos[index];
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white30, width: 0.8),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.memory(photo.bytes, fit: BoxFit.cover),
              ),
              // Index Badge (1, 2, 3...)
              Positioned(
                bottom: 2,
                left: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              // Delete badge if > 2 photos
              if (photos.length > 2)
                Positioned(
                  top: -4,
                  right: -4,
                  child: GestureDetector(
                    onTap: () => onRemovePhoto(photo.id),
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        color: ApplePhotosTheme.appleRed,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(CupertinoIcons.clear, color: Colors.white, size: 12),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  static List<_UniformFramePreset> _getStandardUniformPresets(CanvasOrientation orientation) {
    if (orientation.isPortrait) {
      return const [
        _UniformFramePreset('1:1', 1.0),
        _UniformFramePreset('4:5', 0.8),
        _UniformFramePreset('3:4', 0.75),
        _UniformFramePreset('2:3', 0.667),
        _UniformFramePreset('9:16', 0.5625),
      ];
    } else {
      return const [
        _UniformFramePreset('1:1', 1.0),
        _UniformFramePreset('5:4', 1.25),
        _UniformFramePreset('4:3', 1.333),
        _UniformFramePreset('3:2', 1.5),
        _UniformFramePreset('16:9', 1.778),
      ];
    }
  }
}

class _UniformFramePreset {
  final String label;
  final double ratio;
  const _UniformFramePreset(this.label, this.ratio);
}

