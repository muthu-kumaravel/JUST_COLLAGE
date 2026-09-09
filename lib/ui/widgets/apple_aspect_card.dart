import 'package:flutter/material.dart';
import '../../models/canvas_aspect_ratio.dart';
import '../../theme/apple_photos_theme.dart';

/// Visual card showing an aspect ratio with an illuminated miniature wireframe icon.
/// Highlights Instagram-compatible aspect ratios (4:5 and 9:16 in portrait, 1.91:1 in landscape)
/// with the Instagram camera badge and soft vibrant accent.
class AppleAspectCard extends StatelessWidget {
  final CanvasAspectRatio preset;
  final bool isSelected;
  final VoidCallback onTap;

  const AppleAspectCard({
    super.key,
    required this.preset,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate miniature box aspect ratio for visual wireframe (max 18px)
    final double r = preset.ratio.clamp(0.4, 2.5);
    double boxW = 16.0;
    double boxH = 16.0;
    if (r >= 1.0) {
      boxW = 18.0;
      boxH = (18.0 / r).clamp(8.0, 18.0);
    } else {
      boxH = 18.0;
      boxW = (18.0 * r).clamp(8.0, 18.0);
    }

    final bool isInstagram = preset.isInstagram;
    final String displayRatioLabel = preset.activeRatioLabel;
    final String subLabel = isInstagram
        ? (preset.instagramTag ?? 'IG')
        : (preset.id == '1:1'
            ? 'Square'
            : (preset.id == 'wallpaper'
                ? 'Wallpaper'
                : (preset.id == '1.91:1' ? '1080×566' : '')));

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 74,
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected
              ? ApplePhotosTheme.appleGold.withValues(alpha: 0.18)
              : (isInstagram
                  ? const Color(0xFFE1306C).withValues(alpha: 0.10)
                  : Colors.white.withValues(alpha: 0.07)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? ApplePhotosTheme.appleGold
                : (isInstagram
                    ? const Color(0xFFE1306C).withValues(alpha: 0.50)
                    : ApplePhotosTheme.specularBorder),
            width: isSelected ? 1.5 : (isInstagram ? 0.9 : 0.5),
          ),
          boxShadow: isInstagram && !isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFE1306C).withValues(alpha: 0.12),
                    blurRadius: 6,
                    spreadRadius: 0,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Instagram Badge at Top-Right
            if (isInstagram)
              const Positioned(
                top: 2,
                right: 2,
                child: InstagramIcon(size: 11.5),
              ),

            // Central Content
            Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Miniature Aspect Wireframe Icon
                    SizedBox(
                      height: 19,
                      child: Center(
                        child: Container(
                          width: boxW,
                          height: boxH,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2.5),
                            border: Border.all(
                              color: isSelected
                                  ? ApplePhotosTheme.appleGold
                                  : (isInstagram
                                      ? const Color(0xFFFD1D1D).withValues(alpha: 0.85)
                                      : Colors.white60),
                              width: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    // Title Label
                    Text(
                      displayRatioLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isSelected ? ApplePhotosTheme.appleGold : Colors.white,
                        fontSize: 10.5,
                        fontWeight: (isSelected || isInstagram) ? FontWeight.w700 : FontWeight.w500,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (subLabel.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(
                        subLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isSelected
                              ? ApplePhotosTheme.appleGold.withValues(alpha: 0.85)
                              : (isInstagram ? const Color(0xFFFF7A93) : Colors.white54),
                          fontSize: 8.5,
                          fontWeight: isInstagram ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A crisp, lightweight vector Instagram glyph rendered with the signature gradient.
class InstagramIcon extends StatelessWidget {
  final double size;

  const InstagramIcon({super.key, this.size = 12.0});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: const InstagramLogoPainter(),
    );
  }
}

class InstagramLogoPainter extends CustomPainter {
  const InstagramLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width;
    final rect = Rect.fromLTWH(0, 0, s, s);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(s * 0.28));

    // Signature Instagram Gradient
    const gradient = LinearGradient(
      begin: Alignment.bottomLeft,
      end: Alignment.topRight,
      colors: [
        Color(0xFF833AB4), // Purple
        Color(0xFFC13584), // Red-Violet
        Color(0xFFE1306C), // Pink
        Color(0xFFFD1D1D), // Red
        Color(0xFFF77737), // Orange
        Color(0xFFFCB045), // Yellow
      ],
    );

    final bgPaint = Paint()..shader = gradient.createShader(rect);
    canvas.drawRRect(rrect, bgPaint);

    // Camera body rounded outline
    final strokeW = s * 0.09;
    final glyphPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..isAntiAlias = true;

    final double inset = s * 0.20;
    final cameraRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(inset, inset, s - 2 * inset, s - 2 * inset),
      Radius.circular(s * 0.16),
    );
    canvas.drawRRect(cameraRect, glyphPaint);

    // Camera center lens
    canvas.drawCircle(Offset(s / 2.0, s / 2.0), s * 0.18, glyphPaint);

    // Camera flash dot
    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawCircle(Offset(s * 0.69, s * 0.31), s * 0.05, dotPaint);
  }

  @override
  bool shouldRepaint(covariant InstagramLogoPainter oldDelegate) => false;
}
