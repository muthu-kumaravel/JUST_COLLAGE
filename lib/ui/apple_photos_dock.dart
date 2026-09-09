import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../theme/apple_photos_theme.dart';

/// Available tools in the Apple Photos Collage Studio dock.
enum ApplePhotosTool { layout, canvas, spacing, borders, background, photos }

/// The Apple Photos bottom tool dock with mode icons, gold active indicators, and prominent Shuffle action.
class ApplePhotosDock extends StatelessWidget {
  final ApplePhotosTool activeTool;
  final ValueChanged<ApplePhotosTool> onSelectTool;
  final VoidCallback onShuffle;

  const ApplePhotosDock({
    super.key,
    required this.activeTool,
    required this.onSelectTool,
    required this.onShuffle,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: ApplePhotosTheme.blurSigma, sigmaY: ApplePhotosTheme.blurSigma),
        child: Container(
          decoration: const BoxDecoration(
            color: ApplePhotosTheme.frostedGlassSurface,
            border: Border(
              top: BorderSide(color: ApplePhotosTheme.specularBorder, width: 0.5),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
          child: SafeArea(
            top: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 1. Layout
                _buildToolItem(
                  tool: ApplePhotosTool.layout,
                  label: 'Layout',
                  icon: CupertinoIcons.square_grid_2x2,
                ),
                // 2. Canvas Aspect
                _buildToolItem(
                  tool: ApplePhotosTool.canvas,
                  label: 'Canvas',
                  icon: Icons.aspect_ratio_rounded,
                ),
                // 3. Spacing
                _buildToolItem(
                  tool: ApplePhotosTool.spacing,
                  label: 'Spacing',
                  icon: CupertinoIcons.arrow_left_right,
                ),
                // 4. Borders
                _buildToolItem(
                  tool: ApplePhotosTool.borders,
                  label: 'Borders',
                  icon: CupertinoIcons.rectangle_split_3x1,
                ),
                // 5. Background
                _buildToolItem(
                  tool: ApplePhotosTool.background,
                  label: 'Background',
                  icon: CupertinoIcons.paintbrush_fill,
                ),
                // 6. Photos
                _buildToolItem(
                  tool: ApplePhotosTool.photos,
                  label: 'Photos',
                  icon: CupertinoIcons.photo_on_rectangle,
                ),

                const SizedBox(width: 4),

                // Apple Photos Shuffle Action Pill
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  color: ApplePhotosTheme.appleGold,
                  borderRadius: BorderRadius.circular(16),
                  onPressed: onShuffle,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.shuffle, size: 14, color: Colors.black),
                      SizedBox(width: 4),
                      Text(
                        'Shuffle',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolItem({
    required ApplePhotosTool tool,
    required String label,
    required IconData icon,
  }) {
    final isSelected = activeTool == tool;

    return GestureDetector(
      onTap: () => onSelectTool(tool),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? ApplePhotosTheme.appleGold : Colors.white60,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white54,
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                letterSpacing: -0.1,
              ),
            ),
            const SizedBox(height: 3),
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? ApplePhotosTheme.appleGold : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
