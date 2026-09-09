import 'dart:math';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/crop_transform.dart';
import '../models/photo_asset.dart';
import '../theme/apple_photos_theme.dart';

/// Full-screen Apple Photos crop & adjust viewfinder inspired directly by the iOS Photo Editor.
///
/// Highlights:
/// - 100% full image brightness (no dimming or dark mask inside the crop frame).
/// - Touch-activated rule-of-thirds grid (illuminates during pan/pinch, fades out when released).
/// - iOS Crop top bar with Rotate 90°, Flip Horizontal, Cancel, and Done.
/// - Fluid gesture pan and pinch-to-zoom with mouse wheel and trackpad support.
/// - Apple-style thick corner brackets hugging the crop frame.
class ApplePhotosCropViewfinder extends StatefulWidget {
  final PhotoAsset photo;
  final double frameAspectRatio;
  final CropTransform initialCrop;

  const ApplePhotosCropViewfinder({
    super.key,
    required this.photo,
    required this.frameAspectRatio,
    required this.initialCrop,
  });

  @override
  State<ApplePhotosCropViewfinder> createState() => _ApplePhotosCropViewfinderState();
}

class _ApplePhotosCropViewfinderState extends State<ApplePhotosCropViewfinder> with SingleTickerProviderStateMixin {
  late double _scale;
  late Offset _offset;
  late int _rotationQuarterTurns;
  late bool _isFlippedHorizontal;

  Offset _dragStartFocalPoint = Offset.zero;
  Offset _dragStartOffset = Offset.zero;
  double _dragStartScale = 1.0;
  bool _isInteracting = false;

  late AnimationController _gridAnimController;
  late Animation<double> _gridOpacityAnim;

  @override
  void initState() {
    super.initState();
    _scale = widget.initialCrop.scale.clamp(1.0, 4.0);
    _offset = widget.initialCrop.offset;
    _rotationQuarterTurns = widget.initialCrop.rotationQuarterTurns;
    _isFlippedHorizontal = widget.initialCrop.flipHorizontal;

    _gridAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _gridOpacityAnim = CurvedAnimation(
      parent: _gridAnimController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _gridAnimController.dispose();
    super.dispose();
  }

  void _onInteractionStart() {
    setState(() => _isInteracting = true);
    _gridAnimController.forward();
    HapticFeedback.selectionClick();
  }

  void _onInteractionEnd() {
    setState(() => _isInteracting = false);
    _gridAnimController.reverse();
  }

  void _reset() {
    setState(() {
      _scale = 1.0;
      _offset = Offset.zero;
      _rotationQuarterTurns = 0;
      _isFlippedHorizontal = false;
    });
    HapticFeedback.mediumImpact();
  }

  void _rotate90() {
    setState(() {
      if (_isFlippedHorizontal) {
        _rotationQuarterTurns = (_rotationQuarterTurns + 3) % 4;
      } else {
        _rotationQuarterTurns = (_rotationQuarterTurns + 1) % 4;
      }
      _offset = Offset(-_offset.dy, _offset.dx);
    });
    HapticFeedback.selectionClick();
  }

  void _flipHorizontal() {
    setState(() {
      _isFlippedHorizontal = !_isFlippedHorizontal;
      _offset = Offset(-_offset.dx, _offset.dy);
    });
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final bool isModified = _scale > 1.01 ||
        _offset.dx.abs() > 0.02 ||
        _offset.dy.abs() > 0.02 ||
        _rotationQuarterTurns != 0 ||
        _isFlippedHorizontal;

    return Scaffold(
      backgroundColor: ApplePhotosTheme.obsidianBlack,
      body: SafeArea(
        child: Column(
          children: [
            // 1. iOS Photo Editor Crop Top Bar
            ClipRect(
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Cancel
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                      ),

                      // Center Tools: Rotate 90° & Flip
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(CupertinoIcons.rotate_right, color: Colors.white, size: 20),
                            tooltip: 'Rotate 90°',
                            onPressed: _rotate90,
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(
                              CupertinoIcons.arrow_right_arrow_left,
                              color: _isFlippedHorizontal ? ApplePhotosTheme.appleGold : Colors.white,
                              size: 20,
                            ),
                            tooltip: 'Flip Horizontal',
                            onPressed: _flipHorizontal,
                          ),
                        ],
                      ),

                      // Done (Apple Gold Pill)
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop(CropTransform(
                            scale: _scale,
                            offset: _offset,
                            rotationQuarterTurns: _rotationQuarterTurns,
                            flipHorizontal: _isFlippedHorizontal,
                          ));
                        },
                        style: ApplePhotosTheme.goldPillStyle,
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 2. Main Viewfinder Canvas (Full Brightness with Touch Grid)
            Expanded(
              child: ClipRect(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final double availW = constraints.maxWidth;
                    final double availH = constraints.maxHeight;

                    if (availW <= 10 || availH <= 10) return const SizedBox.shrink();

                    // Calculate centered crop frame fitting within bounds with comfortable padding
                    const double pad = 24.0;
                    final double maxFrameW = availW - 2 * pad;
                    final double maxFrameH = availH - 2 * pad;

                    double frameW = maxFrameW;
                    double frameH = frameW / widget.frameAspectRatio;

                    if (frameH > maxFrameH) {
                      frameH = maxFrameH;
                      frameW = frameH * widget.frameAspectRatio;
                    }

                    final double frameLeft = (availW - frameW) / 2.0;
                    final double frameTop = (availH - frameH) / 2.0;
                    final frameRect = Rect.fromLTWH(frameLeft, frameTop, frameW, frameH);

                    final image = widget.photo.previewImage;
                    final double srcW = (image?.width ?? 100).toDouble();
                    final double srcH = (image?.height ?? 100).toDouble();

                    return Listener(
                      onPointerSignal: (pointerSignal) {
                        if (pointerSignal is PointerScrollEvent) {
                          setState(() {
                            final double zoomDelta = -pointerSignal.scrollDelta.dy * 0.002;
                            _scale = (_scale + zoomDelta).clamp(1.0, 4.0);
                          });
                        }
                      },
                      child: MouseRegion(
                        cursor: _isInteracting ? SystemMouseCursors.grabbing : SystemMouseCursors.grab,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onScaleStart: (details) {
                            _dragStartScale = _scale;
                            _dragStartOffset = _offset;
                            _dragStartFocalPoint = details.localFocalPoint;
                            _onInteractionStart();
                          },
                          onScaleUpdate: (details) {
                            setState(() {
                              if (details.scale != 1.0) {
                                _scale = (_dragStartScale * details.scale).clamp(1.0, 4.0);
                              }

                              final bool isRotatedSideways = _rotationQuarterTurns % 2 != 0;
                              final double effectiveSrcW = isRotatedSideways ? srcH : srcW;
                              final double effectiveSrcH = isRotatedSideways ? srcW : srcH;

                              final double baseScale = max(
                                frameW / (effectiveSrcW > 0 ? effectiveSrcW : 1),
                                frameH / (effectiveSrcH > 0 ? effectiveSrcH : 1),
                              );
                              final double totalScale = baseScale * _scale;
                              final double scaledW = effectiveSrcW * totalScale;
                              final double scaledH = effectiveSrcH * totalScale;
                              final double maxOffsetX = max(0.0, (scaledW - frameW) / 2.0);
                              final double maxOffsetY = max(0.0, (scaledH - frameH) / 2.0);

                              final double deltaX = details.localFocalPoint.dx - _dragStartFocalPoint.dx;
                              final double deltaY = details.localFocalPoint.dy - _dragStartFocalPoint.dy;

                              final double newDx = maxOffsetX > 1.0
                                  ? (_dragStartOffset.dx + deltaX / maxOffsetX).clamp(-1.0, 1.0)
                                  : 0.0;
                              final double newDy = maxOffsetY > 1.0
                                  ? (_dragStartOffset.dy + deltaY / maxOffsetY).clamp(-1.0, 1.0)
                                  : 0.0;

                              _offset = Offset(newDx, newDy);
                            });
                          },
                          onScaleEnd: (_) => _onInteractionEnd(),
                          child: AnimatedBuilder(
                            animation: _gridOpacityAnim,
                            builder: (context, _) {
                              return CustomPaint(
                                size: Size(availW, availH),
                                painter: _ApplePhotosViewfinderPainter(
                                  photo: widget.photo,
                                  frameRect: frameRect,
                                  crop: CropTransform(
                                    scale: _scale,
                                    offset: _offset,
                                    rotationQuarterTurns: _rotationQuarterTurns,
                                    flipHorizontal: _isFlippedHorizontal,
                                  ),
                                  gridOpacity: _gridOpacityAnim.value,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // 3. Bottom Adjustment Strip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              decoration: const BoxDecoration(
                color: ApplePhotosTheme.frostedGlassSurface,
                border: Border(
                  top: BorderSide(color: ApplePhotosTheme.specularBorder, width: 0.5),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Reset Button (Visible if adjusted)
                  if (isModified)
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _reset,
                      child: const Text(
                        'Reset',
                        style: TextStyle(
                          color: ApplePhotosTheme.appleGold,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 48),

                  // Zoom Indicator Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_scale.toStringAsFixed(1)}x',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),

                  const SizedBox(width: 48),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for the Apple Photos Viewfinder.
/// Guarantees 100% full brightness inside the active frame, and renders touch-activated grid.
class _ApplePhotosViewfinderPainter extends CustomPainter {
  final PhotoAsset photo;
  final Rect frameRect;
  final CropTransform crop;
  final double gridOpacity;

  _ApplePhotosViewfinderPainter({
    required this.photo,
    required this.frameRect,
    required this.crop,
    required this.gridOpacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final image = photo.previewImage;
    if (image == null) return;

    // Strictly clip drawing to viewfinder bounds so zooming never bleeds over top or bottom bars
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final double srcW = image.width.toDouble();
    final double srcH = image.height.toDouble();

    final bool isRotatedSideways = crop.rotationQuarterTurns % 2 != 0;
    final double effectiveSrcW = isRotatedSideways ? srcH : srcW;
    final double effectiveSrcH = isRotatedSideways ? srcW : srcH;

    final double baseScale = max(frameRect.width / effectiveSrcW, frameRect.height / effectiveSrcH);
    final double totalScale = baseScale * crop.scale;
    final double effectiveScaledW = effectiveSrcW * totalScale;
    final double effectiveScaledH = effectiveSrcH * totalScale;

    final double maxOffsetX = max(0.0, (effectiveScaledW - frameRect.width) / 2.0);
    final double maxOffsetY = max(0.0, (effectiveScaledH - frameRect.height) / 2.0);

    final double panX = (crop.offset.dx * maxOffsetX).clamp(-maxOffsetX, maxOffsetX);
    final double panY = (crop.offset.dy * maxOffsetY).clamp(-maxOffsetY, maxOffsetY);

    final double centerX = frameRect.center.dx + panX;
    final double centerY = frameRect.center.dy + panY;

    // 1. Draw image un-dimmed with rotation and flip
    canvas.save();
    canvas.translate(centerX, centerY);
    if (crop.flipHorizontal) {
      canvas.scale(-1.0, 1.0);
    }
    if (crop.rotationQuarterTurns != 0) {
      canvas.rotate(crop.rotationQuarterTurns * (pi / 2.0));
    }
    final srcRect = Rect.fromLTWH(0, 0, srcW, srcH);
    final drawRect = Rect.fromCenter(
      center: Offset.zero,
      width: srcW * totalScale,
      height: srcH * totalScale,
    );

    canvas.drawImageRect(
      image,
      srcRect,
      drawRect,
      Paint()..filterQuality = FilterQuality.medium,
    );
    canvas.restore();

    // 2. Draw soft dark shroud ONLY OUTSIDE the frameRect (50% opacity, never over the image inside frame)
    final fullScreenPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final framePath = Path()..addRect(frameRect);
    final shroudPath = Path.combine(PathOperation.difference, fullScreenPath, framePath);

    canvas.drawPath(
      shroudPath,
      Paint()..color = const Color(0x99000000), // Soft shroud outside
    );

    // 3. Draw Touch-Activated Rule-of-Thirds Grid (Smoothly appears on touch, vanishes at rest)
    if (gridOpacity > 0.01) {
      final gridPaint = Paint()
        ..color = Colors.white.withValues(alpha: gridOpacity * 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8;

      final double wThird = frameRect.width / 3.0;
      final double hThird = frameRect.height / 3.0;

      // Vertical lines
      canvas.drawLine(Offset(frameRect.left + wThird, frameRect.top), Offset(frameRect.left + wThird, frameRect.bottom), gridPaint);
      canvas.drawLine(Offset(frameRect.left + 2 * wThird, frameRect.top), Offset(frameRect.left + 2 * wThird, frameRect.bottom), gridPaint);

      // Horizontal lines
      canvas.drawLine(Offset(frameRect.left, frameRect.top + hThird), Offset(frameRect.right, frameRect.top + hThird), gridPaint);
      canvas.drawLine(Offset(frameRect.left, frameRect.top + 2 * hThird), Offset(frameRect.right, frameRect.top + 2 * hThird), gridPaint);
    }

    // 4. White Frame Border (Thin 1px)
    canvas.drawRect(
      frameRect,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // 5. Apple Photos Corner Brackets (Thick crisp corners)
    final cornerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.square;

    const double cornerLen = 18.0;

    // Top-Left
    canvas.drawLine(Offset(frameRect.left, frameRect.top), Offset(frameRect.left + cornerLen, frameRect.top), cornerPaint);
    canvas.drawLine(Offset(frameRect.left, frameRect.top), Offset(frameRect.left, frameRect.top + cornerLen), cornerPaint);

    // Top-Right
    canvas.drawLine(Offset(frameRect.right, frameRect.top), Offset(frameRect.right - cornerLen, frameRect.top), cornerPaint);
    canvas.drawLine(Offset(frameRect.right, frameRect.top), Offset(frameRect.right, frameRect.top + cornerLen), cornerPaint);

    // Bottom-Left
    canvas.drawLine(Offset(frameRect.left, frameRect.bottom), Offset(frameRect.left + cornerLen, frameRect.bottom), cornerPaint);
    canvas.drawLine(Offset(frameRect.left, frameRect.bottom), Offset(frameRect.left, frameRect.bottom - cornerLen), cornerPaint);

    // Bottom-Right
    canvas.drawLine(Offset(frameRect.right, frameRect.bottom), Offset(frameRect.right - cornerLen, frameRect.bottom), cornerPaint);
    canvas.drawLine(Offset(frameRect.right, frameRect.bottom), Offset(frameRect.right, frameRect.bottom - cornerLen), cornerPaint);

    canvas.restore(); // Restore outer canvas.clipRect
  }

  @override
  bool shouldRepaint(covariant _ApplePhotosViewfinderPainter oldDelegate) {
    return oldDelegate.crop != crop ||
        oldDelegate.gridOpacity != gridOpacity ||
        oldDelegate.frameRect != frameRect;
  }
}
