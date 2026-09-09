import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../models/collage_settings.dart';
import '../theme/apple_photos_theme.dart';

/// Clean Apple Photos top navigation bar directly inspired by the iOS Photo Editor.
/// Features Cancel, Undo, Redo, status pill, and Done pill.
class ApplePhotosTopBar extends StatelessWidget {
  final CollageSettings settings;
  final int photoCount;
  final bool canUndo;
  final bool canRedo;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onStartOver;
  final VoidCallback onExport;
  final VoidCallback onTogglePhotosTool;

  const ApplePhotosTopBar({
    super.key,
    required this.settings,
    required this.photoCount,
    required this.canUndo,
    required this.canRedo,
    required this.onUndo,
    required this.onRedo,
    required this.onStartOver,
    required this.onExport,
    required this.onTogglePhotosTool,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: ApplePhotosTheme.blurSigma, sigmaY: ApplePhotosTheme.blurSigma),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          decoration: const BoxDecoration(
            color: ApplePhotosTheme.frostedGlassSurface,
            border: Border(
              bottom: BorderSide(color: ApplePhotosTheme.specularBorder, width: 0.5),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
              // 1. Leading: Cancel + Undo + Redo
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      showCupertinoModalPopup(
                        context: context,
                        builder: (ctx) => CupertinoActionSheet(
                          title: const Text('Discard Collage?'),
                          message: const Text('Are you sure you want to discard your edits and start over?'),
                          actions: [
                            CupertinoActionSheetAction(
                              isDestructiveAction: true,
                              onPressed: () {
                                Navigator.of(ctx).pop();
                                onStartOver();
                              },
                              child: const Text('Discard Edits'),
                            ),
                          ],
                          cancelButton: CupertinoActionSheetAction(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('Keep Editing'),
                          ),
                        ),
                      );
                    },
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Undo Button
                  IconButton(
                    icon: const Icon(CupertinoIcons.arrow_uturn_left, size: 18),
                    color: canUndo ? Colors.white : Colors.white24,
                    onPressed: canUndo ? onUndo : null,
                    tooltip: 'Undo',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),

                  // Redo Button
                  IconButton(
                    icon: const Icon(CupertinoIcons.arrow_uturn_right, size: 18),
                    color: canRedo ? Colors.white : Colors.white24,
                    onPressed: canRedo ? onRedo : null,
                    tooltip: 'Redo',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),

              // 2. Center Status Indicator Pill
              GestureDetector(
                onTap: onTogglePhotosTool,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: ApplePhotosTheme.specularBorder, width: 0.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${settings.layoutMode.label} • $photoCount Photos',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(CupertinoIcons.chevron_down, size: 11, color: Colors.white70),
                    ],
                  ),
                ),
              ),

              // 3. Trailing Actions: More Menu (Start Over only) + Done Pill
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PopupMenuButton<String>(
                    icon: const Icon(CupertinoIcons.ellipsis_circle, color: Colors.white, size: 22),
                    color: const Color(0xFF252528),
                    elevation: 12,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    onSelected: (action) {
                      if (action == 'reset') {
                        onStartOver();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'reset',
                        child: Row(
                          children: [
                            Icon(CupertinoIcons.arrow_counterclockwise, color: ApplePhotosTheme.appleRed, size: 18),
                            SizedBox(width: 10),
                            Text('Start Over', style: TextStyle(color: ApplePhotosTheme.appleRed, fontSize: 14)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 4),

                  // Native Apple Photos Gold Done Pill
                  ElevatedButton(
                    onPressed: onExport,
                    style: ApplePhotosTheme.goldPillStyle,
                    child: const Text('Done'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
}
