import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../theme/apple_photos_theme.dart';

/// Welcoming dark studio initial screen shown before photos are selected.
class EmptyStateView extends StatelessWidget {
  final VoidCallback onSelectPhotos;
  final VoidCallback? onSelectFiles;
  final VoidCallback? onTrySamplePhotos;
  final bool isLoading;

  const EmptyStateView({
    super.key,
    required this.onSelectPhotos,
    this.onSelectFiles,
    this.onTrySamplePhotos,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Apple Photos Collage Glyph
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: ApplePhotosTheme.appleGold.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: ApplePhotosTheme.appleGold.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  CupertinoIcons.square_grid_2x2_fill,
                  size: 40,
                  color: ApplePhotosTheme.appleGold,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Just Collage',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Select 2 or more photos to instantly arrange them into a balanced high-resolution collage.',
                style: TextStyle(
                  color: ApplePhotosTheme.labelSecondary,
                  fontSize: 14.5,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              if (isLoading)
                const CupertinoActivityIndicator(radius: 16, color: ApplePhotosTheme.appleGold)
              else
                Column(
                  children: [
                    // "Photo Library" Button
                    SizedBox(
                      width: 230,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: onSelectPhotos,
                        icon: const Icon(CupertinoIcons.photo_on_rectangle, size: 18, color: Colors.black),
                        label: const Text('Photo Library'),
                        style: ApplePhotosTheme.goldPillStyle.copyWith(
                          shape: WidgetStateProperty.all(
                            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // "Choose from Files" Button
                    if (onSelectFiles != null) ...[
                      SizedBox(
                        width: 230,
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: onSelectFiles,
                          icon: const Icon(CupertinoIcons.folder, size: 18, color: Colors.white70),
                          label: const Text(
                            'Choose from Files',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            backgroundColor: Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],

                    if (onTrySamplePhotos != null) ...[
                      CupertinoButton(
                        onPressed: onTrySamplePhotos,
                        child: const Text(
                          'Try Sample Collage',
                          style: TextStyle(
                            color: ApplePhotosTheme.appleGold,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

              const SizedBox(height: 40),

              // Local & Privacy Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: ApplePhotosTheme.specularBorder, width: 0.5),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.lock_shield_fill,
                      size: 13,
                      color: Colors.white60,
                    ),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '100% Private & Local',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
