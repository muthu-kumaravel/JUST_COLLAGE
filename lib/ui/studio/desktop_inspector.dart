import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../models/canvas_aspect_ratio.dart';
import '../../models/collage_settings.dart';
import '../../models/layout_result.dart';
import '../../models/photo_asset.dart';
import '../../theme/apple_photos_theme.dart';
import '../widgets/apple_aspect_card.dart';
import '../widgets/apple_dial_scrubber.dart';

/// Right-hand Apple Inspector Sidebar for macOS and Web on screens >= 768px.
class DesktopInspector extends StatelessWidget {
  final CollageSettings settings;
  final LayoutResult? layoutResult;
  final List<PhotoAsset> photos;

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
  final VoidCallback onShuffle;

  static const List<Color> _borderColorPresets = [
    Colors.white,
    Colors.black,
    Color(0xFFFFD60A),
    Color(0xFFFAF6F0),
    Color(0xFF64748B),
    Color(0xFFF43F5E),
  ];

  static const List<Color> _bgColorPresets = [
    Colors.white,
    Color(0xFFF8F9FA),
    Color(0xFFFAF6F0),
    Color(0xFFE5E7EB),
    Color(0xFF1E293B),
    Colors.black,
  ];

  const DesktopInspector({
    super.key,
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
    required this.onShuffle,
  });

  @override
  Widget build(BuildContext context) {
    final curOrientation = settings.canvasAspectRatio.orientation;

    return Container(
      width: 320,
      decoration: const BoxDecoration(
        color: ApplePhotosTheme.frostedGlassSurface,
        border: Border(
          left: BorderSide(color: ApplePhotosTheme.specularBorder, width: 0.5),
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        children: [
          // Header & Quick Shuffle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Adjustments',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
              ),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                color: ApplePhotosTheme.appleGold,
                borderRadius: BorderRadius.circular(14),
                onPressed: onShuffle,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.shuffle, size: 13, color: Colors.black),
                    SizedBox(width: 4),
                    Text(
                      'Shuffle',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 1. Layout Section
          _buildSectionHeader('LAYOUT MODE'),
          const SizedBox(height: 6),
          CupertinoSlidingSegmentedControl<CollageLayoutMode>(
            backgroundColor: Colors.white.withValues(alpha: 0.12),
            thumbColor: ApplePhotosTheme.appleGold,
            groupValue: settings.layoutMode,
            children: {
              for (final mode in CollageLayoutMode.values)
                mode: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  child: Text(
                    mode.label,
                    style: TextStyle(
                      color: settings.layoutMode == mode ? Colors.black : Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
            },
            onValueChanged: (mode) {
              if (mode != null) onLayoutModeChanged(mode);
            },
          ),
          if (settings.layoutMode == CollageLayoutMode.uniform && layoutResult != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  onPressed: () => onUniformOrientationChanged(settings.uniformFrameOrientation.toggle()),
                  child: Text(
                    settings.uniformFrameOrientation.isPortrait ? 'Portrait' : 'Landscape',
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: const Text('Best Fit', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                          selected: settings.uniformFrameAspectRatio == null,
                          selectedColor: ApplePhotosTheme.appleGold,
                          onSelected: (_) => onUniformRatioChanged(null),
                        ),
                        ..._getStandardUniformPresets(settings.uniformFrameOrientation).map((p) {
                          final isSelected = settings.uniformFrameAspectRatio != null &&
                              (settings.uniformFrameAspectRatio! - p.ratio).abs() < 0.04;
                          return Padding(
                            padding: const EdgeInsets.only(left: 4.0),
                            child: ChoiceChip(
                              label: Text(p.label, style: const TextStyle(fontSize: 10.5)),
                              selected: isSelected,
                              selectedColor: ApplePhotosTheme.appleGold,
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
          ],
          const SizedBox(height: 18),

          // 2. Canvas Aspect Section
          _buildSectionHeader('CANVAS RATIO'),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Orientation', style: TextStyle(color: Colors.white70, fontSize: 12)),
              CupertinoSlidingSegmentedControl<CanvasOrientation>(
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                thumbColor: ApplePhotosTheme.appleGold,
                groupValue: curOrientation,
                children: {
                  CanvasOrientation.portrait: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
                    child: Text(
                      'Portrait',
                      style: TextStyle(
                        color: curOrientation.isPortrait ? Colors.black : Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  CanvasOrientation.landscape: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
                    child: Text(
                      'Landscape',
                      style: TextStyle(
                        color: curOrientation.isLandscape ? Colors.black : Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                },
                onValueChanged: (ori) {
                  if (ori != null) onCanvasOrientationChanged(ori);
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 72,
            child: Builder(
              builder: (context) {
                final presets = CanvasAspectRatio.presetsFor(curOrientation);
                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: presets.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
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
          const SizedBox(height: 18),

          // 3. Spacing Section
          _buildSectionHeader('SPACING'),
          AppleDialScrubber(
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
          const SizedBox(height: 14),

          // 4. Borders Section
          _buildSectionHeader('BORDERS'),
          AppleDialScrubber(
            label: 'Border Width',
            value: settings.borderWidth,
            min: 0,
            max: 24,
            unit: 'px',
            onChanged: onBorderWidthChanged,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ..._borderColorPresets.map((c) {
                final isSelected = settings.borderImage == null &&
                    c.toARGB32() == settings.borderColor.toARGB32();
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: GestureDetector(
                    onTap: () {
                      if (settings.borderImage != null) onRemoveBorderImage();
                      onBorderColorChanged(c);
                    },
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? ApplePhotosTheme.appleGold : Colors.white30,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(width: 8),
              if (settings.borderImage != null)
                GestureDetector(
                  onTap: onRemoveBorderImage,
                  child: Container(
                    width: 22,
                    height: 22,
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
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  onPressed: onPickBorderImage,
                  child: const Text('Texture', style: TextStyle(color: Colors.white, fontSize: 10.5)),
                ),
            ],
          ),
          const SizedBox(height: 18),

          // 5. Background Section
          _buildSectionHeader('BACKGROUND'),
          const SizedBox(height: 6),
          if (settings.backgroundImage != null) ...[
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.memory(settings.backgroundImage!.bytes, width: 24, height: 24, fit: BoxFit.cover),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: AppleDialScrubber(
                    label: 'Blur',
                    value: settings.backgroundBlur,
                    min: 0,
                    max: 25,
                    unit: '',
                    onChanged: onBackgroundBlurChanged,
                  ),
                ),
                IconButton(
                  onPressed: onRemoveBackgroundImage,
                  icon: const Icon(CupertinoIcons.trash, color: ApplePhotosTheme.appleRed, size: 16),
                ),
              ],
            ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _bgColorPresets.map((c) {
                final isSelected = settings.backgroundImage == null &&
                    c.toARGB32() == settings.backgroundColor.toARGB32();
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: GestureDetector(
                    onTap: () => onBackgroundColorChanged(c),
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? ApplePhotosTheme.appleGold : Colors.white30,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Center(
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                onPressed: onPickBackgroundImage,
                child: const Text('Photo Background', style: TextStyle(color: Colors.white, fontSize: 11)),
              ),
            ),
          ],
          const SizedBox(height: 18),

          // 6. Photos Filmstrip Section
          _buildSectionHeader('PHOTOS (${photos.length})'),
          const SizedBox(height: 8),
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                if (index == photos.length) {
                  return GestureDetector(
                    onTap: onAddPhotos,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: ApplePhotosTheme.specularBorder),
                      ),
                      child: const Icon(CupertinoIcons.plus, color: Colors.white, size: 18),
                    ),
                  );
                }
                final p = photos[index];
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.memory(p.bytes, fit: BoxFit.cover),
                    ),
                    if (photos.length > 2)
                      Positioned(
                        top: -3,
                        right: -3,
                        child: GestureDetector(
                          onTap: () => onRemovePhoto(p.id),
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: const BoxDecoration(
                              color: ApplePhotosTheme.appleRed,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(CupertinoIcons.clear, color: Colors.white, size: 10),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: ApplePhotosTheme.labelTertiary,
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    );
  }

  static List<_DesktopUniformPreset> _getStandardUniformPresets(CanvasOrientation orientation) {
    if (orientation.isPortrait) {
      return const [
        _DesktopUniformPreset('1:1', 1.0),
        _DesktopUniformPreset('4:5', 0.8),
        _DesktopUniformPreset('3:4', 0.75),
        _DesktopUniformPreset('2:3', 0.667),
        _DesktopUniformPreset('9:16', 0.5625),
      ];
    } else {
      return const [
        _DesktopUniformPreset('1:1', 1.0),
        _DesktopUniformPreset('5:4', 1.25),
        _DesktopUniformPreset('4:3', 1.333),
        _DesktopUniformPreset('3:2', 1.5),
        _DesktopUniformPreset('16:9', 1.778),
      ];
    }
  }
}

class _DesktopUniformPreset {
  final String label;
  final double ratio;
  const _DesktopUniformPreset(this.label, this.ratio);
}
