import 'package:flutter/material.dart';

/// Centralized Apple Photos design tokens, colors, materials, and typography.
class ApplePhotosTheme {
  // Backgrounds & Surfaces (Modern iOS 18 Translucency)
  static const Color obsidianBlack = Color(0xFF000000);
  static const Color darkCanvas = Color(0xFF0A0A0C);
  static const Color frostedGlassSurface = Color(0x6618181A); // ~40% opacity modern iOS glass
  static const Color frostedGlassSurfaceSubtle = Color(0x44141416); // ~27% opacity glass
  static const Color frostedGlassLight = Color(0x33FFFFFF);   // ~20% white glass
  static const Color cardSurface = Color(0xFF1C1C1E);
  static const Color secondarySurface = Color(0xFF2C2C2E);

  // Accents
  static const Color appleGold = Color(0xFFFFD60A); // Apple Photos edit gold
  static const Color appleBlue = Color(0xFF007AFF); // System blue
  static const Color appleRed = Color(0xFFFF453A);  // System red for delete/cancel
  static const Color appleGreen = Color(0xFF30D158);

  // Text / Labels
  static const Color labelPrimary = Color(0xFFFFFFFF);
  static const Color labelSecondary = Color(0xFF8E8E93);
  static const Color labelTertiary = Color(0xFF636366);
  static const Color labelQuaternary = Color(0xFF48484A);

  // Borders & Dividers
  static const Color hairline = Color(0x338E8E93);
  static const Color specularBorder = Color(0x2EFFFFFF); // 0.5px white highlight

  // Blur Sigma
  static const double blurSigma = 30.0;

  // Frosted Glass Decoration
  static BoxDecoration frostedDecoration({
    double borderRadius = 16.0,
    Color? color,
    Border? border,
    List<BoxShadow>? shadows,
  }) {
    return BoxDecoration(
      color: color ?? frostedGlassSurface,
      borderRadius: BorderRadius.circular(borderRadius),
      border: border ?? Border.all(color: specularBorder, width: 0.5),
      boxShadow: shadows,
    );
  }

  // Apple Photos Gold Pill Button Style
  static ButtonStyle goldPillStyle = ElevatedButton.styleFrom(
    backgroundColor: appleGold,
    foregroundColor: Colors.black,
    elevation: 0,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
    ),
    textStyle: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
    ),
  );

  // Apple Translucent Secondary Pill Button Style
  static ButtonStyle secondaryPillStyle = ElevatedButton.styleFrom(
    backgroundColor: Colors.white.withValues(alpha: 0.12),
    foregroundColor: Colors.white,
    elevation: 0,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: specularBorder, width: 0.5),
    ),
    textStyle: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
    ),
  );
}
